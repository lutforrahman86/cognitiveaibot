/**
 * Long-running media generations (roadmap A1, F4): video today.
 *
 * Starting a job holds its full price (seconds × price per second) and asks
 * the provider to begin. A runner polls the provider for every unfinished
 * job; when one completes it downloads the result, charges the job and
 * keeps the file until it expires. A failed or timed-out job costs nothing.
 *
 * The queue is the media_jobs table: runners claim due jobs with
 * FOR UPDATE SKIP LOCKED, so several server processes share it without
 * polling the same job twice, and jobs survive restarts.
 */
const fs = require('fs');
const path = require('path');
const { pipeline } = require('stream/promises');
const { Readable } = require('stream');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const metering = require('./metering');
const openaiMedia = require('./openaiMedia');
const { getProvider } = require('./providers');

const POLL_SECONDS = 10;
const JOB_TIMEOUT_MINUTES = 120;
const RUNNER_INTERVAL_MS = 5000;

const storageDir = () => process.env.MEDIA_STORAGE_DIR || path.join(__dirname, '..', '..', 'storage', 'media');
const retentionDays = () => Number(process.env.MEDIA_RETENTION_DAYS) || 7;

/** Holds the video's price, starts it at the provider and queues it. */
async function startVideo({ userId, apiKeyId, model, prepared, prompt, seconds, size }) {
  const price = metering.unitPrice(model, seconds);
  const meter = await metering.startFixed({
    userId,
    model,
    route: prepared.route.provider.name,
    upstreamModel: prepared.route.upstreamModel,
    holdMicros: price.priceMicros,
    source: 'api',
    apiKeyId,
  });
  let started;
  try {
    started = await openaiMedia.createVideo({
      provider: prepared.route.provider,
      model: prepared.route.upstreamModel,
      prompt,
      seconds,
      size,
    });
  } catch (err) {
    await meter.finish({ status: 'failed', errorCode: err.code || 'INTERNAL_ERROR' });
    throw err;
  }
  const [job] = await sequelize.query(
    `INSERT INTO media_jobs (user_id, api_key_id, request_id, model_id, kind, provider_job_id, status, progress, params, next_poll_at)
     VALUES (:userId, :apiKeyId, :requestId, :modelId, 'video', :providerJobId, :status, :progress, CAST(:params AS jsonb),
             now() + (:poll * interval '1 second'))
     RETURNING *`,
    {
      replacements: {
        userId,
        apiKeyId,
        requestId: meter.requestId,
        modelId: model.id,
        providerJobId: started.id,
        status: started.status === 'in_progress' ? 'in_progress' : 'queued',
        progress: started.progress || 0,
        params: JSON.stringify({ seconds, size, prompt_chars: prompt.length }),
        poll: POLL_SECONDS,
      },
      type: QueryTypes.SELECT,
    }
  );
  return job;
}

async function getJob(id, userId) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id))) return null;
  const [job] = await sequelize.query('SELECT * FROM media_jobs WHERE id = :id AND user_id = :userId', {
    replacements: { id, userId },
    type: QueryTypes.SELECT,
  });
  return job || null;
}

/** A job as the API shows it (OpenAI's video object shape, with our id). */
function toApi(job, modelSlug) {
  return {
    id: job.id,
    object: 'video',
    model: modelSlug,
    status: job.status,
    progress: job.status === 'completed' ? 100 : job.progress,
    seconds: String(job.params?.seconds ?? ''),
    size: job.params?.size,
    created_at: Math.floor(new Date(job.created_at).getTime() / 1000),
    completed_at: job.completed_at ? Math.floor(new Date(job.completed_at).getTime() / 1000) : null,
    expires_at: job.expires_at ? Math.floor(new Date(job.expires_at).getTime() / 1000) : null,
    error: job.error_code ? { code: job.error_code.toLowerCase() } : null,
  };
}

async function finishJob(job, model, { status, errorCode = null, outputPath = null, outputBytes = null }) {
  const seconds = Number(job.params?.seconds || 0);
  const price = status === 'completed' ? metering.unitPrice(model, seconds) : { priceMicros: 0, costUsdMicros: 0 };
  await metering.settleRequest(job.request_id, {
    status: status === 'completed' ? 'succeeded' : 'failed',
    errorCode,
    units: status === 'completed' ? seconds : 0,
    ...price,
    durationMs: Date.now() - new Date(job.created_at).getTime(),
  });
  await sequelize.query(
    `UPDATE media_jobs SET status = :status, error_code = :errorCode, output_path = :outputPath, output_bytes = :outputBytes,
            progress = CASE WHEN :status = 'completed' THEN 100 ELSE progress END,
            completed_at = now(), updated_at = now(),
            expires_at = CASE WHEN :status = 'completed' THEN now() + (:days * interval '1 day') ELSE NULL END
      WHERE id = :id`,
    { replacements: { id: job.id, status, errorCode, outputPath, outputBytes, days: retentionDays() } }
  );
}

/** Checks one job at the provider and moves it forward. */
async function advance(job) {
  const [model] = await sequelize.query('SELECT * FROM ai_models WHERE id = :id', {
    replacements: { id: job.model_id },
    type: QueryTypes.SELECT,
  });
  const provider = model && getProvider(model.provider);
  if (!provider?.apiKey) return; // try again once the key is back
  const upstream = model.provider_model_id;

  if (Date.now() - new Date(job.created_at).getTime() > JOB_TIMEOUT_MINUTES * 60_000) {
    await finishJob(job, model, { status: 'failed', errorCode: 'TIMED_OUT' });
    return;
  }

  const state = await openaiMedia.getVideo({ provider, model: upstream, id: job.provider_job_id });
  if (state.status === 'failed') {
    console.warn(`[media] job ${job.id} failed at the provider: ${JSON.stringify(state.error).slice(0, 300)}`);
    await finishJob(job, model, { status: 'failed', errorCode: 'GENERATION_FAILED' });
  } else if (state.status === 'completed') {
    const dir = storageDir();
    fs.mkdirSync(dir, { recursive: true });
    const file = path.join(dir, `${job.id}.mp4`);
    const content = await openaiMedia.downloadVideo({ provider, model: upstream, id: job.provider_job_id });
    await pipeline(Readable.fromWeb(content.body), fs.createWriteStream(file));
    await finishJob(job, model, { status: 'completed', outputPath: file, outputBytes: fs.statSync(file).size });
  } else {
    await sequelize.query(
      "UPDATE media_jobs SET status = 'in_progress', progress = :progress, updated_at = now() WHERE id = :id",
      { replacements: { id: job.id, progress: Math.max(0, Math.min(99, Math.round(state.progress || 0))) } }
    );
  }
}

/**
 * Claims the jobs due for a check and advances each. Returns how many were
 * checked. A provider error leaves the job for its next poll.
 */
async function runOnce({ limit = 5 } = {}) {
  const due = await sequelize.query(
    `UPDATE media_jobs SET next_poll_at = now() + (:poll * interval '1 second'), attempts = attempts + 1
      WHERE id IN (
        SELECT id FROM media_jobs
         WHERE status IN ('queued', 'in_progress') AND next_poll_at <= now()
         ORDER BY next_poll_at LIMIT :limit
         FOR UPDATE SKIP LOCKED)
      RETURNING *`,
    { replacements: { limit, poll: POLL_SECONDS }, type: QueryTypes.SELECT }
  );
  for (const job of due) {
    try {
      await advance(job);
    } catch (err) {
      console.error(`[media] job ${job.id}: ${err.message}`);
    }
  }
  return due.length;
}

/** Deletes the files of completed jobs past their retention period. */
async function deleteExpired() {
  const expired = await sequelize.query(
    'SELECT id, output_path FROM media_jobs WHERE output_path IS NOT NULL AND expires_at <= now()',
    { type: QueryTypes.SELECT }
  );
  for (const job of expired) {
    fs.rmSync(job.output_path, { force: true });
    await sequelize.query('UPDATE media_jobs SET output_path = NULL, updated_at = now() WHERE id = :id', {
      replacements: { id: job.id },
    });
  }
  return expired.length;
}

let timer = null;
function startRunner() {
  if (timer) return;
  timer = setInterval(() => {
    runOnce().catch((err) => console.error('[media] runner:', err.message));
  }, RUNNER_INTERVAL_MS);
  timer.unref();
}

module.exports = { startVideo, getJob, toApi, runOnce, deleteExpired, startRunner };
