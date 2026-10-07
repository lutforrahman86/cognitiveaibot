/**
 * The developer API's non-chat endpoints (roadmap A1, C6), OpenAI-compatible:
 *
 *   POST /v1/embeddings
 *   POST /v1/images/generations
 *   POST /v1/audio/speech
 *   POST /v1/audio/transcriptions      (multipart upload)
 *   POST /v1/videos                    starts an async job
 *   GET  /v1/videos/:id                its status
 *   GET  /v1/videos/:id/content        the MP4, once completed
 *
 * Each call is admitted like chat (plan, tier, rate limit), holds its
 * worst-case cost, calls the provider directly, and is charged what the
 * provider reports: tokens for embeddings and images, characters for speech,
 * seconds of audio for transcription, seconds of video for video. Inputs and
 * outputs aren't stored, except a generated video, kept until it expires
 * (MEDIA_RETENTION_DAYS) so it can be downloaded.
 */
const fs = require('fs');
const express = require('express');
const multer = require('multer');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const gateway = require('../gateway');
const rateLimit = require('../gateway/rateLimit');
const openaiMedia = require('../gateway/openaiMedia');
const mediaJobs = require('../gateway/mediaJobs');
const { estimateTokens } = require('../gateway/metering');
const { ApiError, sendError, invalid, admit, moderate } = require('./v1Common');

const router = express.Router();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 25 * 1024 * 1024, files: 1 } });

/** Runs a fixed-hold media call: hold, call, settle at the provider-reported price. */
async function metered(req, admitted, holdMicros, run) {
  const { model, prepared, userId } = admitted;
  const meter = await gateway.metering.startFixed({
    userId,
    model,
    route: prepared.route.provider.name,
    upstreamModel: prepared.route.upstreamModel,
    holdMicros,
    source: 'api',
    apiKeyId: req.apiKey.id,
  });
  let outcome;
  try {
    outcome = await run(prepared.route.provider, prepared.route.upstreamModel);
  } catch (err) {
    await meter.finish({ status: 'failed', errorCode: err.code || 'INTERNAL_ERROR' });
    throw err;
  }
  const settled = await meter.finish({ status: 'succeeded', ...outcome.billing });
  await gateway.recordUsage({
    userId,
    modelId: model.id,
    inputTokens: outcome.billing.inputTokens || 0,
    outputTokens: outcome.billing.outputTokens || 0,
    chargedCredits: settled?.charged || 0,
  });
  const tokens = (outcome.billing.inputTokens || 0) + (outcome.billing.outputTokens || 0);
  if (tokens) await rateLimit.addTokens(userId, tokens);
  return outcome;
}

const route = (handler) => async (req, res) => {
  try {
    await handler(req, res);
  } catch (err) {
    if (!res.headersSent) sendError(res, err);
    else res.end();
  }
};

// --- Embeddings ------------------------------------------------------------

router.post('/embeddings', route(async (req, res) => {
  const body = req.body || {};
  const inputs = typeof body.input === 'string' ? [body.input] : body.input;
  if (!Array.isArray(inputs) || !inputs.length || inputs.length > 2048 || inputs.some((t) => typeof t !== 'string' || !t)) {
    throw invalid('input', '`input` must be a non-empty string or a list of up to 2,048 non-empty strings.');
  }
  if (body.dimensions != null && (!Number.isInteger(body.dimensions) || body.dimensions < 1)) {
    throw invalid('dimensions', '`dimensions` must be a positive whole number.');
  }
  const admitted = await admit(req, res, body.model, 'embedding');
  // Short inputs can use more tokens than their length suggests (a word can
  // be several tokens), so each input is held with room to spare.
  const estimate = inputs.reduce((sum, t) => sum + estimateTokens(t) + 8, 0);
  const hold = gateway.metering.tokenPrice(admitted.model, estimate, 0).priceMicros;

  const { result } = await metered(req, admitted, hold, async (provider, upstream) => {
    const r = await openaiMedia.embed({ provider, model: upstream, input: inputs, dimensions: body.dimensions });
    return { result: r, billing: { inputTokens: r.inputTokens, outputTokens: 0, ...gateway.metering.tokenPrice(admitted.model, r.inputTokens, 0) } };
  });
  res.json({
    object: 'list',
    data: result.vectors.map((embedding, index) => ({ object: 'embedding', index, embedding })),
    model: admitted.model.slug,
    usage: { prompt_tokens: result.inputTokens, total_tokens: result.inputTokens },
  });
}));

// --- Images ----------------------------------------------------------------

// Image tokens a gpt-image model can produce per image, by quality and size:
// the worst case each image is held at. 'auto' is held as 'high'.
const IMAGE_TOKENS = {
  low: { '1024x1024': 272, '1024x1536': 408, '1536x1024': 400 },
  medium: { '1024x1024': 1056, '1024x1536': 1584, '1536x1024': 1568 },
  high: { '1024x1024': 4160, '1024x1536': 6240, '1536x1024': 6208 },
};
const IMAGE_SIZES = ['1024x1024', '1024x1536', '1536x1024', 'auto'];

router.post('/images/generations', route(async (req, res) => {
  const body = req.body || {};
  if (typeof body.prompt !== 'string' || !body.prompt.trim()) throw invalid('prompt', '`prompt` is required.');
  if (body.prompt.length > 32000) throw invalid('prompt', '`prompt` is limited to 32,000 characters.');
  const n = body.n ?? 1;
  if (!Number.isInteger(n) || n < 1 || n > 4) throw invalid('n', '`n` must be 1 to 4.');
  const size = body.size ?? 'auto';
  if (!IMAGE_SIZES.includes(size)) throw invalid('size', `\`size\` must be one of: ${IMAGE_SIZES.join(', ')}.`);
  const quality = body.quality ?? 'auto';
  if (!['low', 'medium', 'high', 'auto'].includes(quality)) throw invalid('quality', '`quality` must be low, medium, high or auto.');
  if (body.response_format && body.response_format !== 'b64_json') {
    throw invalid('response_format', 'Images are returned as b64_json.', 'unsupported_parameter');
  }
  const admitted = await admit(req, res, body.model, 'image');
  await moderate(req, body.prompt, 'media');

  const perImage = IMAGE_TOKENS[quality === 'auto' ? 'high' : quality][size === 'auto' ? '1024x1536' : size];
  const hold = gateway.metering.tokenPrice(admitted.model, estimateTokens(body.prompt) + 50, perImage * n).priceMicros;
  const { result } = await metered(req, admitted, hold, async (provider, upstream) => {
    const r = await openaiMedia.generateImage({ provider, model: upstream, prompt: body.prompt, n, size, quality });
    return {
      result: r,
      billing: { inputTokens: r.inputTokens, outputTokens: r.outputTokens, ...gateway.metering.tokenPrice(admitted.model, r.inputTokens || 0, r.outputTokens || 0) },
    };
  });
  res.json({
    created: Math.floor(Date.now() / 1000),
    data: result.images.map((b64) => ({ b64_json: b64 })),
    usage: { input_tokens: result.inputTokens, output_tokens: result.outputTokens, total_tokens: (result.inputTokens || 0) + (result.outputTokens || 0) },
  });
}));

// --- Speech ----------------------------------------------------------------

const VOICES = ['alloy', 'ash', 'coral', 'echo', 'fable', 'onyx', 'nova', 'sage', 'shimmer'];
const AUDIO_FORMATS = { mp3: 'audio/mpeg', opus: 'audio/opus', aac: 'audio/aac', flac: 'audio/flac', wav: 'audio/wav', pcm: 'audio/pcm' };

router.post('/audio/speech', route(async (req, res) => {
  const body = req.body || {};
  if (typeof body.input !== 'string' || !body.input) throw invalid('input', '`input` is required.');
  if (body.input.length > 4096) throw invalid('input', '`input` is limited to 4,096 characters.');
  if (!VOICES.includes(body.voice)) throw invalid('voice', `\`voice\` must be one of: ${VOICES.join(', ')}.`);
  const format = body.response_format ?? 'mp3';
  if (!AUDIO_FORMATS[format]) throw invalid('response_format', `\`response_format\` must be one of: ${Object.keys(AUDIO_FORMATS).join(', ')}.`);
  if (body.speed != null && (typeof body.speed !== 'number' || body.speed < 0.25 || body.speed > 4)) {
    throw invalid('speed', '`speed` must be a number from 0.25 to 4.');
  }
  const admitted = await admit(req, res, body.model, 'speech');
  await moderate(req, body.input, 'chat');
  // Billed per character of input, known up front: the hold is the charge.
  const characters = [...body.input].length;
  const price = gateway.metering.unitPrice(admitted.model, characters);
  const { result } = await metered(req, admitted, price.priceMicros, async (provider, upstream) => {
    const r = await openaiMedia.speech({ provider, model: upstream, input: body.input, voice: body.voice, format, speed: body.speed });
    return { result: r, billing: { units: characters, ...price } };
  });
  res.set('Content-Type', AUDIO_FORMATS[format]).send(result.audio);
}));

// --- Transcription ---------------------------------------------------------

router.post('/audio/transcriptions', (req, res, next) =>
  upload.single('file')(req, res, (err) => {
    if (err?.code === 'LIMIT_FILE_SIZE') return sendError(res, new ApiError(413, 'file_too_large', 'Audio files are limited to 25 MB.', 'file'));
    if (err) return sendError(res, invalid('file', 'Send the audio as multipart/form-data in a `file` field.'));
    next();
  }),
route(async (req, res) => {
  const body = req.body || {};
  if (!req.file?.buffer?.length) throw invalid('file', 'Attach the audio as a `file` field (multipart/form-data).');
  const format = body.response_format ?? 'json';
  if (!['json', 'text', 'verbose_json'].includes(format)) throw invalid('response_format', '`response_format` must be json, text or verbose_json.');
  const admitted = await admit(req, res, body.model, 'transcription');

  // The duration is only known afterwards: hold for the longest the file
  // could be (at 16 kbit/s, lower than any normal speech recording), at least a minute.
  const maxSeconds = Math.max(60, Math.ceil((req.file.size * 8) / 16000));
  const hold = gateway.metering.unitPrice(admitted.model, maxSeconds).priceMicros;
  const { result } = await metered(req, admitted, hold, async (provider, upstream) => {
    const r = await openaiMedia.transcribe({
      provider,
      model: upstream,
      file: req.file.buffer,
      filename: req.file.originalname,
      mimetype: req.file.mimetype,
      language: body.language,
      prompt: body.prompt,
    });
    const seconds = Math.max(1, Math.ceil(r.duration || 0));
    return { result: r, billing: { units: seconds, ...gateway.metering.unitPrice(admitted.model, seconds) } };
  });
  if (format === 'text') return res.type('text/plain').send(result.text);
  if (format === 'json') return res.json({ text: result.text });
  res.json({ task: 'transcribe', language: result.language, duration: result.duration, text: result.text, segments: result.segments });
}));

// --- Video -----------------------------------------------------------------

const VIDEO_SECONDS = [4, 8, 12];
const VIDEO_SIZES = ['720x1280', '1280x720'];

router.post('/videos', route(async (req, res) => {
  const body = req.body || {};
  if (typeof body.prompt !== 'string' || !body.prompt.trim()) throw invalid('prompt', '`prompt` is required.');
  const seconds = Number(body.seconds ?? 4);
  if (!VIDEO_SECONDS.includes(seconds)) throw invalid('seconds', '`seconds` must be 4, 8 or 12.');
  const size = body.size ?? '720x1280';
  if (!VIDEO_SIZES.includes(size)) throw invalid('size', `\`size\` must be one of: ${VIDEO_SIZES.join(', ')}.`);
  const admitted = await admit(req, res, body.model, 'video');
  await moderate(req, body.prompt, 'media');
  const job = await mediaJobs.startVideo({
    userId: admitted.userId,
    apiKeyId: req.apiKey.id,
    model: admitted.model,
    prepared: admitted.prepared,
    prompt: body.prompt,
    seconds,
    size,
  });
  res.status(201).json(mediaJobs.toApi(job, admitted.model.slug));
}));

async function ownJob(req) {
  const job = await mediaJobs.getJob(req.params.id, req.apiKey.user_id);
  if (!job) throw new ApiError(404, 'not_found', 'No such video.', 'id');
  return job;
}

router.get('/videos/:id', route(async (req, res) => {
  const job = await ownJob(req);
  const [model] = await sequelize.query('SELECT slug FROM ai_models WHERE id = :id', {
    replacements: { id: job.model_id },
    type: QueryTypes.SELECT,
  });
  res.json(mediaJobs.toApi(job, model?.slug));
}));

router.get('/videos/:id/content', route(async (req, res) => {
  const job = await ownJob(req);
  if (job.status !== 'completed') throw new ApiError(409, 'video_not_ready', `The video is ${job.status.replace('_', ' ')}.`);
  if (!job.output_path || !fs.existsSync(job.output_path)) throw new ApiError(404, 'video_expired', 'This video has expired and was deleted.');
  res.set({ 'Content-Type': 'video/mp4', 'Content-Length': String(job.output_bytes) });
  fs.createReadStream(job.output_path).pipe(res);
}));

module.exports = router;
