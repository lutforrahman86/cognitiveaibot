const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { resetDatabase, startApp, api, registerUser, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let metering;
let mediaJobs;
let rateLimit;
let OpenAI;
let toFile;

const lastLog = async (userId) =>
  (await sequelize.query('SELECT * FROM request_logs WHERE user_id = :userId ORDER BY created_at DESC LIMIT 1', { replacements: { userId } }))[0][0];
const balance = async (userId) => metering.getBalance(userId);

async function developer(name, credits = 100) {
  const u = await registerUser(server.baseUrl, name);
  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, status, started_at, expires_at)
     SELECT :userId, id, 'admin', 'active', now(), now() + interval '30 days' FROM plans WHERE slug = 'media-api'`,
    { replacements: { userId: u.user.id } }
  );
  if (credits) await metering.addCredits(u.user.id, credits, { reason: 'test' });
  const key = (await api(server.baseUrl, 'POST', '/api/developer/keys', { token: u.token, body: { name: 'k' } })).body.key.key;
  return { ...u, key, client: new OpenAI({ apiKey: key, baseURL: `${server.baseUrl}/v1`, maxRetries: 0 }) };
}

before(async () => {
  process.env.MEDIA_STORAGE_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'cog-media-'));
  sequelize = await resetDatabase();
  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  metering = require('../src/gateway/metering');
  mediaJobs = require('../src/gateway/mediaJobs');
  rateLimit = require('../src/gateway/rateLimit');
  ({ default: OpenAI, toFile } = require('openai'));
  server = await startApp();
  await sequelize.query(
    `INSERT INTO plans (slug, name, kind, billing_interval, price_cents, credits, includes_api)
     VALUES ('media-api', 'Media API', 'subscription', 'month', 2500, 2250, true)`
  );
});

beforeEach(async () => {
  mock.reply = {};
  mock.requests = [];
  process.env.OPENAI_API_KEY = 'test-openai-key';
  await rateLimit.resetLimits();
});

after(async () => {
  await server.close();
  await mock.close();
  await sequelize.close();
  fs.rmSync(process.env.MEDIA_STORAGE_DIR, { recursive: true, force: true });
});

test('chat surfaces list only chat models; the API lists every kind with its unit price', async () => {
  const chatList = (await api(server.baseUrl, 'GET', '/api/models')).body.models;
  assert.ok(chatList.length > 0 && chatList.every((m) => m.api_kind === 'chat'));
  const images = (await api(server.baseUrl, 'GET', '/api/models?kind=image')).body.models;
  assert.deepEqual(images.map((m) => m.slug).sort(), ['gpt-image-1', 'gpt-image-1-mini']);

  const dev = await developer('Lister');
  const listed = (await dev.client.models.list()).data;
  const byId = Object.fromEntries(listed.map((m) => [m.id, m]));
  assert.equal(byId['sora-2'].type, 'video');
  assert.deepEqual(byId['sora-2'].pricing, { credits_per_second: 13 });
  assert.deepEqual(byId['tts-1'].pricing, { credits_per_million_characters: 1950 });
  assert.equal(byId['text-embedding-3-small'].type, 'embedding');
});

test('every media model charges provider cost + 30%, per its unit', async () => {
  const [rows] = await sequelize.query(
    "SELECT slug, pricing_unit, unit_cost_usd, unit_credits, input_cost_per_mtok, input_credits_per_mtok FROM ai_models WHERE api_kind <> 'chat'"
  );
  assert.equal(rows.length, 9);
  for (const m of rows) {
    if (m.pricing_unit === 'second') assert.equal(Number(m.unit_credits), Math.round(Number(m.unit_cost_usd) * 130 * 1e6) / 1e6, m.slug);
    else assert.equal(Number(m.input_credits_per_mtok), Math.round(Number(m.input_cost_per_mtok) * 130 * 1e4) / 1e4, m.slug);
  }
});

test('embeddings through the OpenAI SDK, billed by the tokens OpenAI reports', async () => {
  const dev = await developer('Embedder');
  mock.reply = { embeddingTokens: 8 };
  const res = await dev.client.embeddings.create({ model: 'text-embedding-3-small', input: ['hello', 'world'] });
  assert.equal(res.data.length, 2);
  assert.deepEqual(res.data[1].embedding, [0.1, 0.2, 0.3]);
  assert.equal(res.usage.prompt_tokens, 8);
  assert.deepEqual(mock.requests[0].body.input, ['hello', 'world']);
  const log = await lastLog(dev.user.id);
  assert.equal(Number(log.charged_micros), Math.ceil(8 * 2.6));
  assert.equal(log.source, 'api');
});

test('image generation, billed by text and image tokens; the hold covers the worst case first', async () => {
  const dev = await developer('Painter');
  const img = await dev.client.images.generate({ model: 'gpt-image-1', prompt: 'A lighthouse at dusk', size: '1024x1024', quality: 'low' });
  assert.equal(Buffer.from(img.data[0].b64_json, 'base64').toString(), 'fake-png');
  assert.deepEqual(mock.requests[0].body, { model: 'gpt-image-1', prompt: 'A lighthouse at dusk', n: 1, size: '1024x1024', quality: 'low' });
  const log = await lastLog(dev.user.id);
  assert.equal(Number(log.charged_micros), 10 * 650 + 272 * 5200);
  assert.ok(Number(log.held_micros) >= Number(log.charged_micros));

  // A high-quality image is held at its 4,160 image tokens (~21.6 credits): too much for 5 credits.
  const poor = await developer('Poor painter', 5);
  await assert.rejects(
    poor.client.images.generate({ model: 'gpt-image-1', prompt: 'x', size: '1024x1024', quality: 'high' }),
    (err) => err.status === 402 && err.code === 'insufficient_credits'
  );
  assert.equal(mock.requests.length, 1, 'refused before reaching the provider');
});

test('speech is billed per character; transcription per second of audio', async () => {
  const dev = await developer('Speaker');
  const audio = await dev.client.audio.speech.create({ model: 'tts-1', voice: 'alloy', input: 'Hello there' });
  assert.equal(Buffer.from(await audio.arrayBuffer()).toString(), 'fake-mp3-audio');
  let log = await lastLog(dev.user.id);
  assert.equal(log.unit, 'character');
  assert.equal(Number(log.units), 11);
  assert.equal(Number(log.charged_micros), 11 * 1950);

  mock.reply = { duration: 3.2 };
  const text = await dev.client.audio.transcriptions.create({
    model: 'whisper-1',
    file: await toFile(Buffer.from('fake audio bytes'), 'note.mp3', { type: 'audio/mpeg' }),
  });
  assert.equal(text.text, 'hello world');
  const upstream = mock.requests.at(-1);
  assert.equal(upstream.fields.model, 'whisper-1');
  assert.equal(upstream.fields.response_format, 'verbose_json');
  assert.equal(upstream.fields.file.filename, 'note.mp3');
  log = await lastLog(dev.user.id);
  assert.equal(log.unit, 'second');
  assert.equal(Number(log.units), 4, '3.2 s is billed as 4 whole seconds');
  assert.equal(Number(log.charged_micros), 4 * 13000);
});

test('each endpoint only takes its own kind of model, and media calls are validated before any charge', async () => {
  const dev = await developer('Mixer');
  const v1 = (p, body) => fetch(`${server.baseUrl}/v1${p}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${dev.key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then(async (r) => ({ status: r.status, body: await r.json().catch(() => null) }));
  const cases = [
    ['/embeddings', { model: 'gpt-4o', input: 'x' }, 'wrong_model_type'],
    ['/chat/completions', { model: 'gpt-image-1', messages: [{ role: 'user', content: 'x' }] }, 'wrong_model_type'],
    ['/images/generations', { model: 'gpt-image-1', prompt: 'x', n: 9 }, 'invalid_request'],
    ['/images/generations', { model: 'gpt-image-1', prompt: 'x', size: '64x64' }, 'invalid_request'],
    ['/audio/speech', { model: 'tts-1', input: 'x', voice: 'robot' }, 'invalid_request'],
    ['/audio/speech', { model: 'tts-1', input: 'x'.repeat(4097), voice: 'alloy' }, 'invalid_request'],
    ['/videos', { model: 'sora-2', prompt: 'x', seconds: 5 }, 'invalid_request'],
    ['/videos', { model: 'sora-2', prompt: 'x', size: '1920x1080' }, 'invalid_request'],
    ['/embeddings', { model: 'text-embedding-3-small', input: [] }, 'invalid_request'],
  ];
  for (const [p, body, code] of cases) {
    const res = await v1(p, body);
    assert.equal(res.status, 400, `${p} ${JSON.stringify(body).slice(0, 80)}`);
    assert.equal(res.body.error.code, code, p);
  }
  assert.equal(mock.requests.length, 0);
  assert.equal((await balance(dev.user.id)).balance, 100);
});

test('video: a job holds its price, runs in the background, is charged when it completes, and can be downloaded', async () => {
  const dev = await developer('Director');
  const v1 = (method, p, body) => fetch(`${server.baseUrl}/v1${p}`, {
    method,
    headers: { Authorization: `Bearer ${dev.key}`, 'Content-Type': 'application/json' },
    body: body && JSON.stringify(body),
  });
  const created = await v1('POST', '/videos', { model: 'sora-2', prompt: 'A paper boat on a river', seconds: 4, size: '1280x720' });
  assert.equal(created.status, 201);
  const job = await created.json();
  assert.equal(job.status, 'queued');
  assert.equal(job.model, 'sora-2');
  assert.deepEqual(mock.requests[0].fields, { model: 'sora-2', prompt: 'A paper boat on a river', seconds: '4', size: '1280x720' });
  // 4 s × 13 credits are held, not yet charged.
  assert.deepEqual(await balance(dev.user.id), { balance: 100, held: 52, available: 48, expiring: null });

  // Not due yet: the runner leaves it alone.
  assert.equal(await mediaJobs.runOnce(), 0);
  await sequelize.query("UPDATE media_jobs SET next_poll_at = now() WHERE id = :id", { replacements: { id: job.id } });
  mock.videos.video_mock_1 = { status: 'in_progress', progress: 40 };
  assert.equal(await mediaJobs.runOnce(), 1);
  let status = await (await v1('GET', `/videos/${job.id}`)).json();
  assert.deepEqual([status.status, status.progress], ['in_progress', 40]);
  assert.equal((await v1('GET', `/videos/${job.id}/content`)).status, 409);

  // A stale-hold sweep doesn't release a running job's hold.
  await sequelize.query("UPDATE request_logs SET created_at = now() - interval '1 hour' WHERE user_id = :id", { replacements: { id: dev.user.id } });
  await metering.releaseStaleHolds();
  assert.equal((await balance(dev.user.id)).held, 52);

  mock.videos.video_mock_1 = { status: 'completed', progress: 100 };
  await sequelize.query("UPDATE media_jobs SET next_poll_at = now() WHERE id = :id", { replacements: { id: job.id } });
  await mediaJobs.runOnce();
  status = await (await v1('GET', `/videos/${job.id}`)).json();
  assert.equal(status.status, 'completed');
  assert.ok(status.expires_at > status.completed_at);
  assert.deepEqual(await balance(dev.user.id), { balance: 48, held: 0, available: 48, expiring: null });
  const log = await lastLog(dev.user.id);
  assert.deepEqual([log.status, log.unit, Number(log.units), Number(log.charged_micros)], ['succeeded', 'second', 4, 52e6]);

  const video = await v1('GET', `/videos/${job.id}/content`);
  assert.equal(video.headers.get('content-type'), 'video/mp4');
  assert.equal(Buffer.from(await video.arrayBuffer()).toString(), 'fake-mp4-video-bytes');

  // Another account can't see it.
  const other = await developer('Other');
  const peek = await fetch(`${server.baseUrl}/v1/videos/${job.id}`, { headers: { Authorization: `Bearer ${other.key}` } });
  assert.equal(peek.status, 404);

  // After its retention period the file is deleted.
  await sequelize.query("UPDATE media_jobs SET expires_at = now() - interval '1 minute' WHERE id = :id", { replacements: { id: job.id } });
  assert.equal(await mediaJobs.deleteExpired(), 1);
  assert.equal((await v1('GET', `/videos/${job.id}/content`)).status, 404);
  assert.equal(fs.readdirSync(process.env.MEDIA_STORAGE_DIR).length, 0);
});

test('a video that fails at the provider costs nothing', async () => {
  const dev = await developer('Unlucky director', 500);
  const res = await fetch(`${server.baseUrl}/v1/videos`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${dev.key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'sora-2-pro', prompt: 'x', seconds: 8 }),
  });
  const job = await res.json();
  assert.equal((await balance(dev.user.id)).held, 8 * 39);
  const providerId = Object.keys(mock.videos).at(-1);
  mock.videos[providerId] = { status: 'failed', progress: 0, error: { code: 'moderation_blocked' } };
  await sequelize.query("UPDATE media_jobs SET next_poll_at = now() WHERE id = :id", { replacements: { id: job.id } });
  await mediaJobs.runOnce();
  const status = await (await fetch(`${server.baseUrl}/v1/videos/${job.id}`, { headers: { Authorization: `Bearer ${dev.key}` } })).json();
  assert.equal(status.status, 'failed');
  assert.deepEqual(status.error, { code: 'generation_failed' });
  assert.deepEqual(await balance(dev.user.id), { balance: 500, held: 0, available: 500, expiring: null });
});
