const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser, streamPost, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let metering;
let admin;
let models;
let email;

const bySlug = (slug) => models.find((m) => m.slug === slug);
const chatSend = async (user, content) => {
  const chat = (await api(server.baseUrl, 'POST', '/api/chats', { token: user.token, body: {} })).body.chat;
  const res = await streamPost(server.baseUrl, `/api/chats/${chat.id}/completions`, {
    token: user.token,
    body: { content, model_id: bySlug('gpt-4o').id },
  });
  return { ...res, chat };
};
const providerCalls = () => mock.requests.filter((r) => !r.url.endsWith('/moderations'));
const alertsOf = async (kind) => (await api(server.baseUrl, 'GET', '/api/admin/alerts', { token: admin.token })).body.alerts.filter((a) => a.kind === kind);

async function apiDeveloper(name) {
  const u = await registerUser(server.baseUrl, name);
  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, status, started_at, expires_at)
     SELECT :userId, id, 'admin', 'active', now(), now() + interval '30 days' FROM plans WHERE slug = 'safety-api'`,
    { replacements: { userId: u.user.id } }
  );
  await metering.addCredits(u.user.id, 100, { reason: 'test' });
  const key = (await api(server.baseUrl, 'POST', '/api/developer/keys', { token: u.token, body: { name: 'k' } })).body.key.key;
  const v1 = (path, body) => fetch(`${server.baseUrl}/v1${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then(async (r) => ({ status: r.status, body: await r.json().catch(() => null) }));
  return { ...u, v1 };
}

before(async () => {
  sequelize = await resetDatabase();
  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  process.env.OPENAI_API_KEY = 'test-openai-key';
  metering = require('../src/gateway/metering');
  email = require('../src/services/email');
  server = await startApp();
  models = (await api(server.baseUrl, 'GET', '/api/models')).body.models;
  admin = await registerUser(server.baseUrl, 'Admin');
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: admin.user.id } });
  await sequelize.query(
    "INSERT INTO plans (slug, name, kind, billing_interval, price_cents, credits, includes_api) VALUES ('safety-api', 'API', 'subscription', 'month', 2500, 2000, true)"
  );
});

beforeEach(async () => {
  mock.reply = {};
  mock.requests = [];
  mock.moderation = [];
  process.env.MODERATION = 'on';
  email.outbox.length = 0;
  await require('../src/gateway/rateLimit').resetLimits();
});

after(async () => {
  process.env.MODERATION = 'off';
  await server.close();
  await mock.close();
  await sequelize.close();
});

test('chat: only sexual content involving minors is blocked, before any model call, and admins are alerted', async () => {
  const kim = await registerUser(server.baseUrl, 'Kim');
  await metering.addCredits(kim.user.id, 10, { reason: 'test' });

  mock.moderation = ['violence'];
  assert.equal((await chatSend(kim, 'A war story')).status, 200, 'other categories are left to the model');
  assert.equal(mock.requests[0].body.model, 'omni-moderation-latest');
  assert.equal(mock.requests[0].body.input, 'A war story');

  mock.requests = [];
  mock.moderation = ['sexual', 'sexual/minors'];
  const blocked = await chatSend(kim, 'something unacceptable');
  assert.equal(blocked.status, 400);
  assert.equal(blocked.body.code, 'CONTENT_BLOCKED');
  assert.equal(providerCalls().length, 0, 'no model was called');
  const messages = (await api(server.baseUrl, 'GET', `/api/chats/${blocked.chat.id}/messages`, { token: kim.token })).body.messages;
  assert.equal(messages.length, 0, 'nothing was saved');
  const [alert] = await alertsOf('moderation_minors');
  assert.equal(alert.email, kim.email);
});

test('API image and video prompts follow the stricter media policy; chat through the API the chat one', async () => {
  const dev = await apiDeveloper('Maker');
  mock.moderation = ['violence/graphic'];
  const image = await dev.v1('/images/generations', { model: 'gpt-image-1', prompt: 'gore', size: '1024x1024', quality: 'low' });
  assert.equal(image.status, 400);
  assert.equal(image.body.error.code, 'content_blocked');
  const video = await dev.v1('/videos', { model: 'sora-2', prompt: 'gore' });
  assert.equal(video.body.error.code, 'content_blocked');
  const chat = await dev.v1('/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'describe a battle' }] });
  assert.equal(chat.status, 200);
  assert.equal(providerCalls().length, 1, 'only the chat reached a model');
  assert.equal((await metering.getBalance(dev.user.id)).held, 0);
});

test('if moderation is down, chat goes ahead but image and video requests are refused', async () => {
  const dev = await apiDeveloper('Unlucky');
  mock.moderation = { status: 500 };
  assert.equal((await dev.v1('/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] })).status, 200);
  const image = await dev.v1('/images/generations', { model: 'gpt-image-1', prompt: 'a cat', size: '1024x1024', quality: 'low' });
  assert.equal(image.status, 503);
  assert.equal(image.body.error.code, 'moderation_unavailable');
});

test('app users are limited to a number of messages per minute', async () => {
  process.env.APP_MESSAGES_PER_MINUTE = '2';
  try {
    const lee = await registerUser(server.baseUrl, 'Lee');
    await metering.addCredits(lee.user.id, 10, { reason: 'test' });
    assert.equal((await chatSend(lee, 'one')).status, 200);
    assert.equal((await chatSend(lee, 'two')).status, 200);
    const third = await chatSend(lee, 'three');
    assert.equal(third.status, 429);
    assert.equal(third.body.code, 'TOO_MANY_MESSAGES');
  } finally {
    process.env.APP_MESSAGES_PER_MINUTE = '100000';
  }
});

test('a spending spike raises one admin alert per hour, emailed, which admins resolve', async () => {
  process.env.SPEND_ALERT_CREDITS_PER_HOUR = '50';
  process.env.ADMIN_ALERT_EMAIL = 'ops@example.test';
  try {
    const max = await registerUser(server.baseUrl, 'Max');
    await sequelize.query(
      `INSERT INTO request_logs (id, user_id, route, upstream_model, status, charged_micros)
       VALUES (gen_random_uuid(), :id, 'OpenAI', 'gpt-4o', 'succeeded', 60000000)`,
      { replacements: { id: max.user.id } }
    );
    const { checkSpendSpikes } = require('../src/admin/alerts');
    await checkSpendSpikes();
    await checkSpendSpikes();
    const spikes = (await alertsOf('spend_spike')).filter((a) => a.email === max.email);
    assert.equal(spikes.length, 1, 'one alert per incident');
    assert.deepEqual(spikes[0].details, { credits: 60, threshold: 50 });
    const mail = email.outbox.find((m) => m.to === 'ops@example.test');
    assert.match(mail.subject, /spend spike/);

    const user = await registerUser(server.baseUrl, 'Nosy');
    assert.equal((await api(server.baseUrl, 'GET', '/api/admin/alerts', { token: user.token })).status, 403);
    assert.equal((await api(server.baseUrl, 'POST', `/api/admin/alerts/${spikes[0].id}/resolve`, { token: admin.token })).status, 200);
    assert.equal((await alertsOf('spend_spike')).some((a) => a.id === spikes[0].id), false);
  } finally {
    delete process.env.SPEND_ALERT_CREDITS_PER_HOUR;
    delete process.env.ADMIN_ALERT_EMAIL;
  }
});

test('users report a reply from their own chats; admins review it', async () => {
  const ola = await registerUser(server.baseUrl, 'Ola');
  await metering.addCredits(ola.user.id, 10, { reason: 'test' });
  mock.reply = { chunks: ['A questionable answer'] };
  const sent = await chatSend(ola, 'hi');
  const reply = sent.events.at(-1).message;

  const report = (user, body) => api(server.baseUrl, 'POST', '/api/reports', { token: user.token, body });
  assert.equal((await report(ola, { message_id: reply.id, reason: 'rude' })).body.code, 'INVALID_REPORT');
  const stranger = await registerUser(server.baseUrl, 'Stranger');
  assert.equal((await report(stranger, { message_id: reply.id, reason: 'harmful' })).status, 404);
  const created = await report(ola, { message_id: reply.id, reason: 'harmful', details: 'Gave dangerous advice' });
  assert.equal(created.status, 201);

  const open = (await api(server.baseUrl, 'GET', '/api/admin/reports', { token: admin.token })).body.reports;
  const mine = open.find((r) => r.id === created.body.report.id);
  assert.equal(mine.content_excerpt, 'A questionable answer');
  assert.equal(mine.reporter_email, ola.email);
  assert.equal(mine.model_name, bySlug('gpt-4o').name);
  const done = await api(server.baseUrl, 'PATCH', `/api/admin/reports/${mine.id}`, { token: admin.token, body: { status: 'actioned' } });
  assert.equal(done.body.report.status, 'actioned');
  const audit = (await api(server.baseUrl, 'GET', '/api/admin/audit', { token: admin.token })).body.actions;
  assert.ok(audit.some((a) => a.action === 'report.review' && a.target_id === mine.id));
});
