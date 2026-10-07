const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser, streamPost, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let models;
let metering;

const bySlug = (slug) => models.find((m) => m.slug === slug);
const refreshModels = async () => {
  models = (await api(server.baseUrl, 'GET', '/api/models')).body.models;
};
const newChat = async (token) => (await api(server.baseUrl, 'POST', '/api/chats', { token, body: {} })).body.chat;
const send = (user, chatId, content, modelSlug = 'gpt-4o', onEvent) =>
  streamPost(server.baseUrl, `/api/chats/${chatId}/completions`, {
    token: user.token,
    body: { content, model_id: bySlug(modelSlug).id },
    onEvent,
  });
const account = async (userId) => {
  const [[row]] = await sequelize.query(
    'SELECT balance_micros, held_micros FROM credit_accounts WHERE user_id = :userId',
    { replacements: { userId } }
  );
  return { balance: Number(row.balance_micros), held: Number(row.held_micros) };
};
const lastLog = async (userId) => {
  const [[row]] = await sequelize.query(
    'SELECT * FROM request_logs WHERE user_id = :userId ORDER BY created_at DESC LIMIT 1',
    { replacements: { userId } }
  );
  return row;
};
const userWith = async (credits, name = 'User') => {
  const u = await registerUser(server.baseUrl, name);
  if (credits) await metering.addCredits(u.user.id, credits, { reason: 'test' });
  return u;
};
const waitFor = async (check) => {
  for (let i = 0; i < 40; i++) {
    if (await check()) return;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('timed out waiting');
};

before(async () => {
  sequelize = await resetDatabase();
  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  // The Anthropic SDK adds /v1/messages itself.
  process.env.ANTHROPIC_BASE_URL = mock.baseUrl.replace(/\/v1$/, '');
  metering = require('../src/gateway/metering');
  server = await startApp();
});

beforeEach(async () => {
  mock.reply = {};
  mock.requests = [];
  process.env.OPENAI_API_KEY = 'test-openai-key';
  delete process.env.ANTHROPIC_API_KEY;
  delete process.env.SIGNUP_TRIAL_CREDITS;
  await refreshModels();
});

after(async () => {
  await server.close();
  await mock.close();
  await sequelize.close();
});

test('a user without enough credits is refused before any provider call, and nothing is saved', async () => {
  const carol = await userWith(0, 'Carol');
  const chat = await newChat(carol.token);

  const res = await send(carol, chat.id, 'Hello');

  assert.equal(res.status, 402);
  assert.equal(res.body.code, 'INSUFFICIENT_CREDITS');
  assert.match(res.body.error, /GPT-4o/);
  assert.equal(mock.requests.length, 0);
  const messages = (await api(server.baseUrl, 'GET', `/api/chats/${chat.id}/messages`, { token: carol.token })).body.messages;
  assert.deepEqual(messages, []);
});

test('the charge is the exact token cost, recorded in the ledger and the request log', async () => {
  const dan = await userWith(10, 'Dan');
  const chat = await newChat(dan.token);
  mock.reply = { chunks: ['Hi!'], usage: { prompt_tokens: 21, completion_tokens: 5 } };

  const { events } = await send(dan, chat.id, 'Hello');
  const done = events.at(-1);

  // GPT-4o costs $2.50 / $10 per 1M tokens; at 1 credit = $0.01 that is 250 / 1000 credits.
  const expected = 21 * 325 + 5 * 1300; // micro-credits: GPT-4o at cost + 30%
  assert.equal(done.credits.charged, expected / 1e6);
  assert.equal(done.credits.balance, (10e6 - expected) / 1e6);
  assert.deepEqual(await account(dan.user.id), { balance: 10e6 - expected, held: 0 });

  const log = await lastLog(dan.user.id);
  assert.equal(log.status, 'succeeded');
  assert.equal(log.route, 'OpenAI');
  assert.equal(log.upstream_model, 'gpt-4o');
  assert.deepEqual([log.input_tokens, log.output_tokens, log.usage_estimated], [21, 5, false]);
  assert.equal(Number(log.charged_micros), expected);
  assert.equal(Number(log.unbilled_micros), 0);
  assert.equal(Number(log.cost_usd_micros), Math.ceil(21 * 2.5 + 5 * 10)); // micro-dollars

  const credits = (await api(server.baseUrl, 'GET', '/api/credits', { token: dan.token })).body;
  assert.equal(credits.balance, (10e6 - expected) / 1e6);
  assert.deepEqual(credits.transactions.map((t) => [t.type, t.amount]), [
    ['charge', -expected / 1e6],
    ['grant', 10],
  ]);
});

test('a low balance shortens the reply to what it can pay for, instead of overspending', async () => {
  const erin = await userWith(2, 'Erin');
  const chat = await newChat(erin.token);
  mock.reply = { chunks: ['Short.'], usage: { prompt_tokens: 20, completion_tokens: 2 } };

  await send(erin, chat.id, 'Hello');

  const cap = mock.requests[0].body.max_completion_tokens;
  // 2 credits at 1000 credits per 1M output tokens buys ~2000 tokens, not the usual 8192.
  assert.ok(cap >= 1024 && cap < 2000, `max_completion_tokens was ${cap}`);
});

test('the charge never exceeds the hold; any shortfall is recorded as unbilled', async () => {
  const fay = await userWith(3, 'Fay');
  const chat = await newChat(fay.token);
  // The provider claims far more output than the hold could pay for.
  mock.reply = { chunks: ['…'], usage: { prompt_tokens: 20, completion_tokens: 50_000 } };

  const { events } = await send(fay, chat.id, 'Hello');

  const log = await lastLog(fay.user.id);
  assert.equal(Number(log.charged_micros), Number(log.held_micros));
  assert.equal(Number(log.unbilled_micros), 20 * 325 + 50_000 * 1300 - Number(log.held_micros));
  const acct = await account(fay.user.id);
  assert.equal(acct.held, 0);
  assert.ok(acct.balance >= 0);
  assert.equal(events.at(-1).credits.balance, acct.balance / 1e6);
});

test('a provider failure releases the hold and charges nothing', async () => {
  const gus = await userWith(10, 'Gus');
  const chat = await newChat(gus.token);
  mock.reply = { status: 500 };

  const res = await send(gus, chat.id, 'Hello');

  assert.equal(res.status, 502);
  assert.equal(res.body.code, 'PROVIDER_ERROR');
  assert.deepEqual(await account(gus.user.id), { balance: 10e6, held: 0 });
  const log = await lastLog(gus.user.id);
  assert.deepEqual([log.status, log.error_code, Number(log.charged_micros)], ['failed', 'PROVIDER_ERROR', 0]);
});

test('a stopped reply is charged only for what was produced, estimated when the provider sent no usage', async () => {
  const hal = await userWith(10, 'Hal');
  const chat = await newChat(hal.token);
  // Usage would only arrive at the very end, after the user stops.
  mock.reply = { chunks: ['One', ' two', ' three', ' four'], delayMs: 120, usage: { prompt_tokens: 20, completion_tokens: 4 } };

  let deltas = 0;
  await send(hal, chat.id, 'Count', 'gpt-4o', (e) => (e.type === 'delta' && ++deltas === 2 ? 'abort' : undefined));

  await waitFor(async () => (await lastLog(hal.user.id)).status !== 'in_progress');
  const log = await lastLog(hal.user.id);
  assert.equal(log.status, 'cancelled');
  assert.equal(log.usage_estimated, true);
  assert.ok(Number(log.charged_micros) > 0);
  assert.equal((await account(hal.user.id)).held, 0);
});

test('parallel holds can never commit more credits than the balance', async () => {
  const ivy = await userWith(3, 'Ivy');
  const model = (await sequelize.query("SELECT * FROM ai_models WHERE slug = 'gpt-4o'", { type: 'SELECT' }))[0];

  const attempts = await Promise.allSettled(
    Array.from({ length: 5 }, () =>
      metering.start({
        userId: ivy.user.id,
        chatId: null,
        model,
        route: 'OpenAI',
        upstreamModel: 'gpt-4o',
        messages: [{ role: 'user', content: 'hi' }],
        maxOutputTokens: 8192,
      })
    )
  );

  const started = attempts.filter((a) => a.status === 'fulfilled').map((a) => a.value);
  const refused = attempts.filter((a) => a.status === 'rejected');
  assert.equal(started.length, 1, 'the first hold takes everything available');
  assert.ok(refused.every((r) => r.reason.code === 'INSUFFICIENT_CREDITS'));
  const acct = await account(ivy.user.id);
  assert.ok(acct.held <= acct.balance);

  await started[0].finish({ status: 'succeeded', inputTokens: 5, outputTokens: 5 });
  assert.equal((await account(ivy.user.id)).held, 0);
});

test('holds left by a crashed process are released, without charging', async () => {
  const jo = await userWith(10, 'Jo');
  const model = (await sequelize.query("SELECT * FROM ai_models WHERE slug = 'gpt-4o'", { type: 'SELECT' }))[0];
  const meter = await metering.start({
    userId: jo.user.id, chatId: null, model, route: 'OpenAI', upstreamModel: 'gpt-4o',
    messages: [{ role: 'user', content: 'hi' }], maxOutputTokens: 8192,
  });
  assert.ok((await account(jo.user.id)).held > 0);
  await sequelize.query("UPDATE request_logs SET created_at = now() - interval '20 minutes' WHERE id = :id", {
    replacements: { id: meter.requestId },
  });

  assert.equal(await metering.releaseStaleHolds(), 1);

  assert.deepEqual(await account(jo.user.id), { balance: 10e6, held: 0 });
  const log = await lastLog(jo.user.id);
  assert.deepEqual([log.status, log.error_code], ['failed', 'STALE_HOLD_RELEASED']);
});

test('Anthropic: streams the reply and bills the token counts from its stream', async () => {
  process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
  await refreshModels();
  assert.equal(bySlug('claude-sonnet-5-5').available, true);
  const kim = await userWith(10, 'Kim');
  const chat = await newChat(kim.token);
  mock.reply = { chunks: ['Bonjour', ' !'], usage: { prompt_tokens: 30, completion_tokens: 7 } };

  const { events } = await send(kim, chat.id, 'Say hi in French', 'claude-sonnet-5-5');

  assert.deepEqual(events.filter((e) => e.type === 'delta').map((e) => e.text), ['Bonjour', ' !']);
  const done = events.at(-1);
  assert.equal(done.type, 'done');
  assert.deepEqual(done.usage, { input_tokens: 30, output_tokens: 7, estimated: false });
  // Sonnet 5.5: $2 / $10 per 1M tokens, + 30% = 260 / 1300 credits.
  assert.equal(done.credits.charged, (30 * 260 + 7 * 1300) / 1e6);

  const [upstream] = mock.requests;
  assert.equal(upstream.url, '/v1/messages');
  assert.equal(upstream.headers['x-api-key'], 'test-anthropic-key');
  assert.equal(upstream.body.model, 'claude-sonnet-5-5');
  assert.equal(upstream.body.stream, true);
  assert.deepEqual(upstream.body.messages, [{ role: 'user', content: 'Say hi in French' }]);
  assert.equal((await lastLog(kim.user.id)).route, 'Anthropic');
});

test('Anthropic: a rejected key is a clear error, and a refusal keeps the partial text', async () => {
  process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
  await refreshModels();
  const lee = await userWith(10, 'Lee');

  mock.reply = { status: 401 };
  const rejected = await send(lee, (await newChat(lee.token)).id, 'Hello', 'claude-haiku-4-5');
  assert.equal(rejected.status, 502);
  assert.equal(rejected.body.code, 'PROVIDER_AUTH_FAILED');

  mock.reply = { chunks: ['I can'], stopReason: 'refusal', usage: { prompt_tokens: 10, completion_tokens: 3 } };
  const refused = await send(lee, (await newChat(lee.token)).id, 'Something it declines', 'claude-haiku-4-5');
  const last = refused.events.at(-1);
  assert.equal(last.type, 'error');
  assert.equal(last.code, 'PROVIDER_REFUSED');
  assert.equal(last.message.content, 'I can');
  assert.equal((await account(lee.user.id)).held, 0);
});

test('every model is called directly at its own provider, and only once that provider’s key is set', async () => {
  // Without an Anthropic key, Claude can't be called, whatever other keys are set.
  assert.equal(bySlug('claude-sonnet-5-5').available, false);
  // No direct integration yet: never callable.
  assert.equal(bySlug('deepseek-v4-pro').available, false);

  process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
  await refreshModels();
  const max = await userWith(10, 'Max');
  await send(max, (await newChat(max.token)).id, 'Hello', 'claude-sonnet-5-5');
  assert.equal(mock.requests[0].url, '/v1/messages');
  assert.equal(mock.requests[0].headers['x-api-key'], 'test-anthropic-key');
  assert.equal(mock.requests[0].body.model, 'claude-sonnet-5-5');
  assert.equal((await lastLog(max.user.id)).route, 'Anthropic');

  const ded = await userWith(10, 'Ded');
  const res = await send(ded, (await newChat(ded.token)).id, 'Hello', 'deepseek-v4-pro');
  assert.equal(res.body.code, 'MODEL_UNAVAILABLE');
  assert.equal(mock.requests.length, 1, 'nothing else was called');
});

test('every priced model charges provider cost + 30% (1 credit = US$0.01)', async () => {
  const [rows] = await sequelize.query(
    `SELECT slug, input_cost_per_mtok, output_cost_per_mtok, input_credits_per_mtok, output_credits_per_mtok
       FROM ai_models WHERE is_active AND input_cost_per_mtok IS NOT NULL`
  );
  assert.ok(rows.length >= 40);
  for (const m of rows) {
    for (const side of ['input', 'output']) {
      const expected = Math.round(Number(m[`${side}_cost_per_mtok`]) * 130 * 1e4) / 1e4;
      assert.equal(Number(m[`${side}_credits_per_mtok`]), expected, `${m.slug} ${side}`);
    }
  }
});

test('a model without prices is never callable', async () => {
  await sequelize.query("UPDATE ai_models SET input_credits_per_mtok = NULL WHERE slug = 'gpt-4o-mini'");
  // Edited behind the admin API's back, so the model list cache is cleared by hand.
  await require('../src/services/cache').invalidate('models');
  await refreshModels();
  assert.equal(bySlug('gpt-4o-mini').available, false);
  const ned = await userWith(10, 'Ned');
  const res = await send(ned, (await newChat(ned.token)).id, 'Hello', 'gpt-4o-mini');
  assert.equal(res.body.code, 'MODEL_UNAVAILABLE');
  await sequelize.query("UPDATE ai_models SET input_credits_per_mtok = 19.5 WHERE slug = 'gpt-4o-mini'");
  await require('../src/services/cache').invalidate('models');
});

test('admins can grant or remove credits with a reason; other users cannot', async () => {
  const admin = await registerUser(server.baseUrl, 'Admin');
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: admin.user.id } });
  const ola = await userWith(0, 'Ola');
  const grant = (token, body) => api(server.baseUrl, 'POST', `/api/admin/users/${ola.user.id}/credits`, { token, body });

  assert.equal((await grant(ola.token, { credits: 50, reason: 'self-service?' })).status, 403);
  assert.equal((await grant(admin.token, { credits: 50 })).body.code, 'REASON_REQUIRED');

  const granted = await grant(admin.token, { credits: 50, reason: 'Support goodwill' });
  assert.equal(granted.status, 200);
  assert.equal(granted.body.credits, 50);
  const removed = await grant(admin.token, { credits: -20, reason: 'Correction' });
  assert.equal(removed.body.credits, 30);
  assert.equal((await grant(admin.token, { credits: -100, reason: 'Too much' })).status, 400);

  const [rows] = await sequelize.query(
    'SELECT type, amount_micros, reason, created_by FROM credit_transactions WHERE user_id = :id ORDER BY created_at',
    { replacements: { id: ola.user.id } }
  );
  assert.deepEqual(rows.map((r) => [r.type, Number(r.amount_micros) / 1e6, r.reason, r.created_by]), [
    ['grant', 50, 'Support goodwill', admin.user.id],
    ['adjustment', -20, 'Correction', admin.user.id],
  ]);

  const users = (await api(server.baseUrl, 'GET', '/api/admin/users', { token: admin.token })).body.users;
  assert.equal(users.find((u) => u.id === ola.user.id).credits, 30);
});

test('the admin usage view shows provider cost against what was charged', async () => {
  const admin = await registerUser(server.baseUrl, 'Admin 2');
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: admin.user.id } });

  const usage = (await api(server.baseUrl, 'GET', '/api/admin/usage', { token: admin.token })).body;
  const m = usage.margin;
  assert.ok(m.requests >= 5);
  assert.ok(m.provider_cost_usd > 0);
  // Credits are priced at cost + 30%; requests charged at their hold leave
  // an unbilled amount instead.
  assert.ok(m.charged_usd > 0);
  assert.ok(m.unbilled_credits > 0, 'the over-the-hold test above left an unbilled amount');
  assert.ok(m.by_model.some((r) => r.route === 'Anthropic'));

  const requests = (await api(server.baseUrl, 'GET', '/api/admin/requests', { token: admin.token })).body.requests;
  assert.ok(requests.length >= 5);
  assert.ok('charged_credits' in requests[0] && !('charged_micros' in requests[0]));
});

test('trial credits are granted once, when an account is first used', async () => {
  process.env.SIGNUP_TRIAL_CREDITS = '5';
  const pat = await registerUser(server.baseUrl, 'Pat');

  const first = (await api(server.baseUrl, 'GET', '/api/credits', { token: pat.token })).body;
  const second = (await api(server.baseUrl, 'GET', '/api/credits', { token: pat.token })).body;

  assert.equal(first.balance, 5);
  assert.equal(second.balance, 5);
  assert.deepEqual(second.transactions.map((t) => [t.type, t.amount, t.reason]), [['grant', 5, 'Trial credits']]);
});
