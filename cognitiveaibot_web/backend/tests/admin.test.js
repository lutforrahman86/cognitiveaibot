const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser, streamPost, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let metering;
let admin;
let models;

const bySlug = (slug) => models.find((m) => m.slug === slug);
const refreshModels = async () => {
  models = (await api(server.baseUrl, 'GET', '/api/admin/models', { token: admin.token })).body.models;
};
const newChat = async (token) => (await api(server.baseUrl, 'POST', '/api/chats', { token, body: {} })).body.chat;
const send = async (user, slug, content = 'Hello') =>
  streamPost(server.baseUrl, `/api/chats/${(await newChat(user.token)).id}/completions`, {
    token: user.token,
    body: { content, model_id: bySlug(slug).id },
  });
const editModel = (slug, body, token = admin.token) =>
  api(server.baseUrl, 'PATCH', `/api/admin/models/${bySlug(slug).id}`, { token, body });
const audit = async (action) =>
  (await api(server.baseUrl, 'GET', '/api/admin/audit', { token: admin.token })).body.actions.filter((a) => a.action === action);

before(async () => {
  sequelize = await resetDatabase();
  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  metering = require('../src/gateway/metering');
  server = await startApp();
  admin = await registerUser(server.baseUrl, 'Admin');
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: admin.user.id } });
});

beforeEach(async () => {
  mock.reply = {};
  mock.requests = [];
  process.env.OPENAI_API_KEY = 'test-openai-key';
  await refreshModels();
});

after(async () => {
  await server.close();
  await mock.close();
  await sequelize.close();
});

test('admins edit a model’s price, status, capabilities and switch it off; each change is audit-logged', async () => {
  const user = await registerUser(server.baseUrl, 'Plain user');
  assert.equal((await editModel('gpt-4o-mini', { tier: 1 }, user.token)).status, 403);
  for (const body of [{ tier: 10 }, { status: 'retired' }, { input_credits_per_mtok: -1 }, { slug: 'x' }, { input_modalities: ['smell'] }]) {
    assert.equal((await editModel('gpt-4o-mini', body)).status, 400, JSON.stringify(body));
  }

  const res = await editModel('gpt-4o-mini', {
    input_credits_per_mtok: 25,
    output_credits_per_mtok: 100,
    status: 'beta',
    supports_vision: true,
    input_modalities: ['text', 'image'],
  });
  assert.equal(res.status, 200);
  assert.deepEqual(res.body.changed.sort(), ['input_credits_per_mtok', 'input_modalities', 'output_credits_per_mtok', 'status', 'supports_vision']);
  assert.equal(Number(res.body.model.input_credits_per_mtok), 25);

  // The new price is what the next reply is charged.
  const ivy = await registerUser(server.baseUrl, 'Ivy');
  await metering.addCredits(ivy.user.id, 5, { reason: 'test' });
  await send(ivy, 'gpt-4o-mini');
  const [[log]] = await sequelize.query('SELECT charged_micros FROM request_logs WHERE user_id = :id', { replacements: { id: ivy.user.id } });
  assert.equal(Number(log.charged_micros), 12 * 25 + 3 * 100);

  // Switched off: no longer callable or listed.
  await editModel('gpt-4o-mini', { is_active: false });
  const publicList = (await api(server.baseUrl, 'GET', '/api/models')).body.models;
  assert.equal(publicList.find((m) => m.slug === 'gpt-4o-mini'), undefined);

  const [entry] = await audit('model.update');
  assert.equal(entry.admin_email, admin.email);
  assert.equal(entry.details.slug, 'gpt-4o-mini');
  assert.deepEqual(entry.details.after, { is_active: false });
  assert.deepEqual(entry.details.before, { is_active: true });
  // An edit that changes nothing isn't logged.
  const count = (await audit('model.update')).length;
  await editModel('gpt-4o-mini', { is_active: false });
  assert.equal((await audit('model.update')).length, count);
  await editModel('gpt-4o-mini', { is_active: true, input_credits_per_mtok: 19.5, output_credits_per_mtok: 78 });
});

test('model tiers: every model starts open; a premium model needs a plan that unlocks its tier', async () => {
  assert.ok(models.every((m) => m.tier === 0), 'all models start at tier 0, open to everyone');
  await editModel('gpt-4o', { tier: 1 });
  const [[plan]] = await sequelize.query(
    `INSERT INTO plans (slug, name, kind, billing_interval, price_cents, credits, includes_api, model_tier)
     VALUES ('premium', 'Premium', 'subscription', 'month', 5000, 4000, true, 1) RETURNING id`
  );

  const free = await registerUser(server.baseUrl, 'Free');
  await metering.addCredits(free.user.id, 5, { reason: 'test' });
  const refused = await send(free, 'gpt-4o');
  assert.equal(refused.status, 403);
  assert.equal(refused.body.code, 'MODEL_REQUIRES_PLAN');
  assert.equal(mock.requests.length, 0);
  assert.equal((await send(free, 'gpt-5-4-nano')).status, 200, 'tier-0 models stay open');

  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, status, started_at, expires_at)
     VALUES (:userId, :planId, 'admin', 'active', now(), now() + interval '30 days')`,
    { replacements: { userId: free.user.id, planId: plan.id } }
  );
  assert.equal((await send(free, 'gpt-4o')).status, 200);

  // The same rule on the developer API, where a lower plan doesn't even list the model.
  const key = (await api(server.baseUrl, 'POST', '/api/developer/keys', { token: free.token, body: { name: 'k' } })).body.key.key;
  const v1 = (path, init) => fetch(`${server.baseUrl}/v1${path}`, { ...init, headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' } }).then(async (r) => ({ status: r.status, body: await r.json() }));
  assert.ok((await v1('/models')).body.data.some((m) => m.id === 'gpt-4o'));
  await sequelize.query("UPDATE plans SET model_tier = 0 WHERE slug = 'premium'");
  assert.ok(!(await v1('/models')).body.data.some((m) => m.id === 'gpt-4o'));
  const apiRefused = await v1('/chat/completions', { method: 'POST', body: JSON.stringify({ model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] }) });
  assert.equal(apiRefused.status, 403);
  assert.equal(apiRefused.body.error.code, 'model_requires_plan');
  await editModel('gpt-4o', { tier: 0 });
});

test('a suspended user can’t sign in, chat or use API keys; unsuspending restores everything', async () => {
  const sam = await registerUser(server.baseUrl, 'Sam');
  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, status, started_at, expires_at)
     SELECT :userId, id, 'admin', 'active', now(), now() + interval '30 days' FROM plans WHERE slug = 'premium'`,
    { replacements: { userId: sam.user.id } }
  );
  const key = (await api(server.baseUrl, 'POST', '/api/developer/keys', { token: sam.token, body: { name: 'k' } })).body.key.key;
  const listModels = () => fetch(`${server.baseUrl}/v1/models`, { headers: { Authorization: `Bearer ${key}` } }).then(async (r) => ({ status: r.status, body: await r.json() }));
  assert.equal((await listModels()).status, 200);
  const suspend = (body, token = admin.token) => api(server.baseUrl, 'POST', `/api/admin/users/${sam.user.id}/suspend`, { token, body });
  assert.equal((await suspend({ reason: 'x' }, sam.token)).status, 403);
  assert.equal((await suspend({})).body.code, 'REASON_REQUIRED');
  assert.equal((await api(server.baseUrl, 'POST', `/api/admin/users/${admin.user.id}/suspend`, { token: admin.token, body: { reason: 'oops' } })).body.code, 'CANNOT_SUSPEND_SELF');
  assert.equal((await suspend({ reason: 'Card fraud' })).status, 200);

  const me = await api(server.baseUrl, 'GET', '/api/auth/me', { token: sam.token });
  assert.equal(me.status, 403);
  assert.equal(me.body.code, 'ACCOUNT_SUSPENDED');
  const login = await api(server.baseUrl, 'POST', '/api/auth/login', { body: { email: sam.email, password: 'password123' } });
  assert.equal(login.status, 401);
  assert.match(login.body.error, /suspended/);
  const viaKey = await listModels();
  assert.equal(viaKey.status, 403);
  assert.equal(viaKey.body.error.code, 'account_suspended');
  const users = (await api(server.baseUrl, 'GET', '/api/admin/users', { token: admin.token })).body.users;
  assert.equal(users.find((u) => u.id === sam.user.id).suspended_reason, 'Card fraud');

  assert.equal((await api(server.baseUrl, 'POST', `/api/admin/users/${sam.user.id}/unsuspend`, { token: admin.token })).status, 200);
  assert.equal((await api(server.baseUrl, 'GET', '/api/auth/me', { token: sam.token })).status, 200);
  assert.equal((await listModels()).status, 200);
  assert.deepEqual((await audit('user.suspend')).map((a) => a.details.reason), ['Card fraud']);
  assert.equal((await audit('user.unsuspend')).length, 1);
});

test('admins refund one request’s charge, once, with a reason', async () => {
  const una = await registerUser(server.baseUrl, 'Una');
  await metering.addCredits(una.user.id, 5, { reason: 'test' });
  await send(una, 'gpt-4o');
  const [[log]] = await sequelize.query('SELECT id, charged_micros FROM request_logs WHERE user_id = :id', { replacements: { id: una.user.id } });
  const charged = Number(log.charged_micros);
  const refund = (body) => api(server.baseUrl, 'POST', `/api/admin/requests/${log.id}/refund`, { token: admin.token, body });

  assert.equal((await refund({})).body.code, 'REASON_REQUIRED');
  const res = await refund({ reason: 'Garbled reply' });
  assert.equal(res.status, 200);
  assert.equal(res.body.refunded, charged / 1e6);
  assert.equal((await metering.getBalance(una.user.id)).balance, 5);
  assert.equal((await refund({ reason: 'again' })).body.code, 'ALREADY_REFUNDED');
  assert.equal((await api(server.baseUrl, 'POST', '/api/admin/requests/00000000-0000-0000-0000-000000000000/refund', { token: admin.token, body: { reason: 'x' } })).status, 404);
  const [entry] = await audit('request.refund');
  assert.equal(entry.target_id, log.id);
  assert.equal(entry.details.reason, 'Garbled reply');
});

test('credit adjustments and plan edits are audit-logged too', async () => {
  const vic = await registerUser(server.baseUrl, 'Vic');
  await api(server.baseUrl, 'POST', `/api/admin/users/${vic.user.id}/credits`, { token: admin.token, body: { credits: 7, reason: 'Goodwill' } });
  const created = (await api(server.baseUrl, 'POST', '/api/admin/plans', {
    token: admin.token,
    body: { slug: 'audit-plan', name: 'Audit', kind: 'topup', price_cents: 500, credits: 400 },
  })).body.plan;
  await api(server.baseUrl, 'PATCH', `/api/admin/plans/${created.id}`, { token: admin.token, body: { active: false } });
  assert.equal((await audit('credits.adjust')).find((a) => a.target_id === vic.user.id).details.reason, 'Goodwill');
  assert.equal((await audit('plan.create')).length, 1);
  assert.deepEqual((await audit('plan.update'))[0].details, { active: false });
});
