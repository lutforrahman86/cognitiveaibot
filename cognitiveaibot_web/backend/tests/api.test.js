const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let metering;
let rateLimit;
let OpenAI;
let apiPlan;

const sdk = (apiKey) => new OpenAI({ apiKey, baseURL: `${server.baseUrl}/v1`, maxRetries: 0 });
const v1 = (key, method, path, body) => fetch(`${server.baseUrl}/v1${path}`, {
  method,
  headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) },
  body: body === undefined ? undefined : JSON.stringify(body),
}).then(async (res) => ({ status: res.status, headers: res.headers, body: await res.json().catch(() => null) }));

async function planWith(slug, { includesApi = true, rpm = 60, tpm = 200000 } = {}) {
  const [[plan]] = await sequelize.query(
    `INSERT INTO plans (slug, name, kind, billing_interval, price_cents, credits, includes_api,
                        api_requests_per_minute, api_tokens_per_minute)
     VALUES (:slug, :slug, 'subscription', 'month', 2500, 2250, :includesApi, :rpm, :tpm) RETURNING *`,
    { replacements: { slug, includesApi, rpm, tpm } }
  );
  return plan;
}
async function subscribe(userId, plan, status = 'active') {
  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, status, started_at, expires_at)
     VALUES (:userId, :planId, 'admin', :status, now(), now() + interval '30 days')`,
    { replacements: { userId, planId: plan.id, status } }
  );
}
/** A signed-up developer on an API plan, with credits and a key. */
async function developer(name, { credits = 10, plan = apiPlan } = {}) {
  const u = await registerUser(server.baseUrl, name);
  await subscribe(u.user.id, plan);
  if (credits) await metering.addCredits(u.user.id, credits, { reason: 'test' });
  const created = await api(server.baseUrl, 'POST', '/api/developer/keys', { token: u.token, body: { name: 'test key' } });
  assert.equal(created.status, 201, created.text);
  return { ...u, key: created.body.key.key, keyId: created.body.key.id };
}
const lastLog = async (userId) =>
  (await sequelize.query('SELECT * FROM request_logs WHERE user_id = :userId ORDER BY created_at DESC LIMIT 1', { replacements: { userId } }))[0][0];

before(async () => {
  sequelize = await resetDatabase();
  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  process.env.ANTHROPIC_BASE_URL = mock.baseUrl.replace(/\/v1$/, '');
  metering = require('../src/gateway/metering');
  rateLimit = require('../src/gateway/rateLimit');
  OpenAI = require('openai').default;
  server = await startApp();
  apiPlan = await planWith('api-pro');
});

beforeEach(async () => {
  mock.reply = {};
  mock.requests = [];
  process.env.OPENAI_API_KEY = 'test-openai-key';
  delete process.env.ANTHROPIC_API_KEY;
  await rateLimit.resetLimits();
});

after(async () => {
  await server.close();
  await mock.close();
  await sequelize.close();
});

test('only API plans can create keys; a key is shown once, stored hashed, and can be revoked', async () => {
  const free = await registerUser(server.baseUrl, 'Free user');
  const refused = await api(server.baseUrl, 'POST', '/api/developer/keys', { token: free.token, body: { name: 'x' } });
  assert.equal(refused.status, 403);
  assert.equal(refused.body.code, 'API_ACCESS_REQUIRED');
  const noApi = await planWith('chat-only', { includesApi: false });
  await subscribe(free.user.id, noApi);
  assert.equal((await api(server.baseUrl, 'POST', '/api/developer/keys', { token: free.token, body: { name: 'x' } })).status, 403);

  const dev = await developer('Dev');
  assert.match(dev.key, /^sk-cog-[A-Za-z0-9_-]{43}$/);
  const dash = (await api(server.baseUrl, 'GET', '/api/developer', { token: dev.token })).body;
  assert.equal(dash.access.requests_per_minute, 60);
  assert.match(dash.base_url, /\/v1$/);
  assert.equal(dash.keys.length, 1);
  assert.equal(dash.keys[0].prefix, dev.key.slice(0, 11));
  assert.ok(!JSON.stringify(dash).includes(dev.key), 'the full key is never shown again');
  const [[row]] = await sequelize.query('SELECT key_hash FROM api_keys WHERE id = :id', { replacements: { id: dev.keyId } });
  assert.equal(row.key_hash, require('crypto').createHash('sha256').update(dev.key).digest('hex'));

  assert.equal((await v1(dev.key, 'GET', '/models')).status, 200);
  const other = await registerUser(server.baseUrl, 'Other');
  assert.equal((await api(server.baseUrl, 'DELETE', `/api/developer/keys/${dev.keyId}`, { token: other.token })).status, 404);
  assert.equal((await api(server.baseUrl, 'DELETE', `/api/developer/keys/${dev.keyId}`, { token: dev.token })).status, 200);
  const revoked = await v1(dev.key, 'GET', '/models');
  assert.equal(revoked.status, 401);
  assert.equal(revoked.body.error.code, 'invalid_api_key');
});

test('calls without a valid key, or after the plan lapses, are refused in OpenAI’s error format', async () => {
  const missing = await v1(null, 'GET', '/models');
  assert.equal(missing.status, 401);
  assert.deepEqual(Object.keys(missing.body.error).sort(), ['code', 'message', 'param', 'type']);
  assert.equal(missing.body.error.code, 'missing_api_key');
  assert.equal((await v1('sk-cog-not-a-real-key', 'GET', '/models')).body.error.code, 'invalid_api_key');

  const dev = await developer('Lapsed');
  await sequelize.query("UPDATE subscriptions SET status = 'canceled' WHERE user_id = :id", { replacements: { id: dev.user.id } });
  const res = await v1(dev.key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] });
  assert.equal(res.status, 403);
  assert.equal(res.body.error.code, 'api_access_required');
  assert.equal(mock.requests.length, 0);
});

test('the stock OpenAI SDK lists models and gets a reply, billed exactly, with nothing stored', async () => {
  const dev = await developer('Sdk');
  const client = sdk(dev.key);

  const models = await client.models.list();
  const ids = models.data.map((m) => m.id);
  assert.ok(ids.includes('gpt-4o'));
  assert.ok(!ids.includes('deepseek-v4-pro'), 'models without a direct integration aren’t listed');
  assert.ok(!ids.includes('claude-sonnet-5-5'), 'nor are models whose provider key isn’t set');
  assert.equal((await client.models.retrieve('gpt-4o')).owned_by, 'OpenAI');

  const completion = await client.chat.completions.create({
    model: 'gpt-4o',
    messages: [
      { role: 'developer', content: 'Be brief.' },
      { role: 'user', content: [{ type: 'text', text: 'Say hello' }] },
    ],
    temperature: 0.2,
    max_tokens: 50,
  });
  assert.equal(completion.object, 'chat.completion');
  assert.match(completion.id, /^chatcmpl-/);
  assert.equal(completion.model, 'gpt-4o');
  assert.equal(completion.choices[0].message.content, 'Hello there!');
  assert.equal(completion.choices[0].finish_reason, 'stop');
  assert.deepEqual(completion.usage, { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 });

  const [upstream] = mock.requests;
  assert.equal(upstream.body.model, 'gpt-4o');
  assert.equal(upstream.body.temperature, 0.2);
  assert.equal(upstream.body.max_completion_tokens, 50);
  assert.deepEqual(upstream.body.messages, [
    { role: 'system', content: 'Be brief.' },
    { role: 'user', content: 'Say hello' },
  ]);

  // GPT-4o at cost + 30%: 325 / 1300 credits per 1M tokens.
  const log = await lastLog(dev.user.id);
  assert.equal(Number(log.charged_micros), 12 * 325 + 3 * 1300);
  assert.equal(log.source, 'api');
  assert.equal(log.api_key_id, dev.keyId);
  assert.equal(log.chat_id, null);
  const [[{ chats }]] = await sequelize.query('SELECT count(*)::int AS chats FROM chats WHERE user_id = :id', { replacements: { id: dev.user.id } });
  const [[{ messages }]] = await sequelize.query(
    "SELECT count(*)::int AS messages FROM messages WHERE content LIKE '%Say hello%' OR content = 'Hello there!'"
  );
  assert.equal(chats + messages, 0, 'no prompt or reply is stored');
});

test('streaming through the SDK sends chunks, the finish reason and usage', async () => {
  const dev = await developer('Streamer');
  const stream = await sdk(dev.key).chat.completions.create({
    model: 'gpt-4o',
    messages: [{ role: 'user', content: 'Hi' }],
    stream: true,
    stream_options: { include_usage: true },
  });
  let text = '';
  let finish = null;
  let usage = null;
  for await (const chunk of stream) {
    if (chunk.choices[0]?.delta?.content) text += chunk.choices[0].delta.content;
    if (chunk.choices[0]?.finish_reason) finish = chunk.choices[0].finish_reason;
    if (chunk.usage) usage = chunk.usage;
  }
  assert.equal(text, 'Hello there!');
  assert.equal(finish, 'stop');
  assert.deepEqual(usage, { prompt_tokens: 12, completion_tokens: 3, total_tokens: 15 });
});

test('Anthropic models get system messages in their own field, and a cut-off reply reports "length"', async () => {
  process.env.ANTHROPIC_API_KEY = 'test-anthropic-key';
  const dev = await developer('Claude user');
  mock.reply = { chunks: ['Once upon'], stopReason: 'max_tokens', usage: { prompt_tokens: 20, completion_tokens: 2 } };
  const completion = await sdk(dev.key).chat.completions.create({
    model: 'claude-haiku-4-5',
    messages: [
      { role: 'system', content: 'You tell stories.' },
      { role: 'user', content: 'Tell me one' },
    ],
    max_tokens: 2,
    stop: 'THE END',
  });
  assert.equal(completion.choices[0].finish_reason, 'length');
  const [upstream] = mock.requests;
  assert.equal(upstream.url, '/v1/messages');
  assert.equal(upstream.body.system, 'You tell stories.');
  assert.deepEqual(upstream.body.messages, [{ role: 'user', content: 'Tell me one' }]);
  assert.deepEqual(upstream.body.stop_sequences, ['THE END']);
  assert.equal(upstream.body.max_tokens, 2);
});

test('bad requests are refused before any provider call or charge', async () => {
  const dev = await developer('Careless');
  const hi = [{ role: 'user', content: 'hi' }];
  const cases = [
    [{ messages: hi }, 400, 'invalid_request'],
    [{ model: 'no-such-model', messages: hi }, 404, 'model_not_found'],
    [{ model: 'deepseek-v4-pro', messages: hi }, 404, 'model_not_found'],
    [{ model: 'gpt-4o', messages: [] }, 400, 'invalid_request'],
    [{ model: 'gpt-4o', messages: [{ role: 'tool', content: 'x' }] }, 400, 'invalid_request'],
    [{ model: 'gpt-4o', messages: [{ role: 'user', content: [{ type: 'image_url', image_url: { url: 'x' } }] }] }, 400, 'invalid_request'],
    [{ model: 'gpt-4o', messages: hi, tools: [{ type: 'function' }] }, 400, 'unsupported_parameter'],
    [{ model: 'gpt-4o', messages: hi, n: 2 }, 400, 'unsupported_parameter'],
    [{ model: 'gpt-4o', messages: hi, temperature: 3 }, 400, 'invalid_request'],
    [{ model: 'gpt-4o', messages: hi, max_tokens: 0 }, 400, 'invalid_request'],
  ];
  for (const [body, status, code] of cases) {
    const res = await v1(dev.key, 'POST', '/chat/completions', body);
    assert.equal(res.status, status, JSON.stringify(body));
    assert.equal(res.body.error.code, code, JSON.stringify(body));
  }
  const broke = await developer('Broke', { credits: 0 });
  const poor = await v1(broke.key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: hi });
  assert.equal(poor.status, 402);
  assert.equal(poor.body.error.code, 'insufficient_credits');
  assert.equal(poor.body.error.type, 'insufficient_quota');

  assert.equal(mock.requests.length, 0);
  const [[{ logs }]] = await sequelize.query(
    'SELECT count(*)::int AS logs FROM request_logs WHERE user_id IN (:ids)',
    { replacements: { ids: [dev.user.id, broke.user.id] } }
  );
  assert.equal(logs, 0);
  assert.equal((await v1(dev.key, 'GET', '/nope')).body.error.code, 'not_found');
});

test('rate limits: requests and tokens per minute per account, with OpenAI-style headers', async () => {
  const tight = await planWith('tight', { rpm: 2, tpm: 1_000_000 });
  const dev = await developer('Busy', { plan: tight });
  const call = () => v1(dev.key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] });
  const first = await call();
  assert.equal(first.status, 200);
  assert.equal(first.headers.get('x-ratelimit-limit-requests'), '2');
  assert.equal(first.headers.get('x-ratelimit-remaining-requests'), '1');
  assert.equal((await call()).status, 200);
  const third = await call();
  assert.equal(third.status, 429);
  assert.equal(third.body.error.code, 'rate_limit_exceeded');
  assert.equal(third.body.error.type, 'rate_limit_error');
  assert.ok(Number(third.headers.get('retry-after')) >= 1);
  assert.equal(mock.requests.length, 2);

  // Tokens: each reply uses 15 (12 in, 3 out). With 20 allowed, the second
  // call still runs (15 < 20) and the third is refused.
  const tokenPlan = await planWith('few-tokens', { rpm: 100, tpm: 20 });
  const wordy = await developer('Wordy', { plan: tokenPlan });
  const talk = () => v1(wordy.key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] });
  assert.equal((await talk()).status, 200);
  assert.equal((await talk()).status, 200);
  const refused = await talk();
  assert.equal(refused.status, 429);
  assert.match(refused.body.error.message, /20 tokens per minute/);
});

test('a non-streamed reply that fails part-way costs nothing', async () => {
  const dev = await developer('Unlucky');
  mock.reply = { chunks: ['Partial', ' text', ' more'], failAfter: 1 };
  const res = await v1(dev.key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] });
  assert.equal(res.status, 502);
  assert.equal(res.body.error.code, 'provider_error');
  const log = await lastLog(dev.user.id);
  assert.equal(log.status, 'failed');
  assert.equal(Number(log.charged_micros), 0);
  assert.equal((await metering.getBalance(dev.user.id)).balance, 10);
});

test('the developer dashboard shows API usage by day, model and key', async () => {
  const dev = await developer('Tracker');
  const second = (await api(server.baseUrl, 'POST', '/api/developer/keys', { token: dev.token, body: { name: 'second' } })).body.key;
  const ask = (key) => v1(key, 'POST', '/chat/completions', { model: 'gpt-4o', messages: [{ role: 'user', content: 'hi' }] });
  await ask(dev.key);
  await ask(dev.key);
  await ask(second.key);

  const usage = (await api(server.baseUrl, 'GET', '/api/developer/usage', { token: dev.token })).body;
  assert.equal(usage.totals.requests, 3);
  assert.equal(usage.totals.input_tokens, 36);
  assert.equal(usage.totals.credits, (3 * (12 * 325 + 3 * 1300)) / 1e6);
  assert.equal(usage.by_day.length, 1);
  assert.deepEqual(usage.by_model.map((m) => [m.model, m.requests]), [['gpt-4o', 3]]);
  assert.deepEqual(usage.by_key.map((k) => [k.name, k.requests]).sort(), [['second', 1], ['test key', 2]]);
});

test('with Redis, rate-limit counters are shared through it', async (t) => {
  const url = process.env.TEST_REDIS_URL || 'redis://127.0.0.1:6379/15';
  const { createClient } = require('redis');
  const probe = createClient({ url, socket: { reconnectStrategy: false, connectTimeout: 500 } });
  probe.on('error', () => {});
  try {
    await probe.connect();
  } catch {
    t.skip(`no Redis at ${url}`);
    return;
  }
  await probe.flushDb();
  process.env.REDIS_URL = url;
  try {
    const limits = { requestsPerMinute: 2, tokensPerMinute: 100 };
    assert.equal((await rateLimit.checkRequest('redis-user', limits)).allowed, true);
    assert.equal((await rateLimit.checkRequest('redis-user', limits)).allowed, true);
    assert.equal((await rateLimit.checkRequest('redis-user', limits)).allowed, false);
    const keys = await probe.keys('rl:redis-user:*');
    assert.equal(keys.length, 1, 'the counter lives in Redis');
    assert.ok((await probe.pTTL(keys[0])) > 0, 'and expires');
  } finally {
    await rateLimit.resetLimits();
    delete process.env.REDIS_URL;
    await rateLimit.resetLimits();
    await probe.quit();
  }
});
