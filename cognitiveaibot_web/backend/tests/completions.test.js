const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser, streamPost, startMockProvider } = require('./helpers');

let sequelize;
let server;
let mock;
let alice;
let bob;
let models;

const bySlug = (slug) => models.find((m) => m.slug === slug);
const newChat = async (token = alice.token) =>
  (await api(server.baseUrl, 'POST', '/api/chats', { token, body: {} })).body.chat;
const messagesIn = async (chatId) =>
  (await api(server.baseUrl, 'GET', `/api/chats/${chatId}/messages`, { token: alice.token })).body.messages;
const send = (chatId, content, modelSlug = 'gpt-4o', opts = {}) =>
  streamPost(server.baseUrl, `/api/chats/${chatId}/completions`, {
    token: opts.token || alice.token,
    body: { content, model_id: bySlug(modelSlug).id },
    onEvent: opts.onEvent,
  });

before(async () => {
  sequelize = await resetDatabase();
  await require('../src/db/seeds/01-ai-models').seed();

  mock = await startMockProvider();
  process.env.OPENAI_BASE_URL = mock.baseUrl;
  process.env.OPENAI_API_KEY = 'test-openai-key';

  server = await startApp();
  alice = await registerUser(server.baseUrl, 'Alice');
  bob = await registerUser(server.baseUrl, 'Bob');
  const { addCredits } = require('../src/gateway/metering');
  await addCredits(alice.user.id, 100, { reason: 'test' });
  await addCredits(bob.user.id, 100, { reason: 'test' });
  models = (await api(server.baseUrl, 'GET', '/api/models')).body.models;
});

beforeEach(() => {
  mock.reply = {};
  mock.requests = [];
});

after(async () => {
  await server.close();
  await mock.close();
  await sequelize.close();
});

test('the model list says which models can actually be called', () => {
  assert.equal(models.length, 46, 'the 2026-10 catalog');
  assert.equal(bySlug('gpt-4o').available, true);
  assert.equal(bySlug('gpt-5-6-terra').available, true);
  // Direct-only through Google, and no Google or OpenRouter key in the tests.
  assert.equal(bySlug('gemini-3-8-flash').available, false);
  assert.equal(bySlug('claude-sonnet-4').available, false);
  // Only reachable through OpenRouter, which has no key here.
  assert.equal(bySlug('deepseek-v4-pro').available, false);
  // Retired by its provider: no longer listed at all.
  assert.equal(bySlug('gemini-2-flash'), undefined);
  assert.ok(!('unavailable_reason' in bySlug('claude-sonnet-4')), 'reasons stay admin-only');
});

test('a message streams a real reply, and both sides are saved with usage', async () => {
  const chat = await newChat();
  mock.reply = { chunks: ['Paris', ' is the', ' capital.'], usage: { prompt_tokens: 21, completion_tokens: 5 } };

  const { status, events } = await send(chat.id, 'What is the capital of France?');

  assert.equal(status, 200);
  assert.deepEqual(
    events.map((e) => e.type),
    ['start', 'delta', 'delta', 'delta', 'done']
  );
  assert.equal(events[0].user_message.content, 'What is the capital of France?');
  assert.equal(events[0].chat.title, 'What is the capital of France?');
  assert.equal(events.filter((e) => e.type === 'delta').map((e) => e.text).join(''), 'Paris is the capital.');
  const done = events.at(-1);
  assert.equal(done.message.content, 'Paris is the capital.');
  assert.deepEqual(done.usage, { input_tokens: 21, output_tokens: 5, estimated: false });
  // GPT-4o: 250 credits per 1M input tokens, 1000 per 1M output tokens.
  assert.equal(done.credits.charged, (21 * 250 + 5 * 1000) / 1e6);

  // What reached the provider.
  const [upstream] = mock.requests;
  assert.equal(upstream.url, '/v1/chat/completions');
  assert.equal(upstream.headers.authorization, 'Bearer test-openai-key');
  assert.equal(upstream.body.model, 'gpt-4o');
  assert.equal(upstream.body.stream, true);
  assert.deepEqual(upstream.body.stream_options, { include_usage: true });
  assert.equal(upstream.body.max_completion_tokens, 8192);
  assert.deepEqual(upstream.body.messages, [{ role: 'user', content: 'What is the capital of France?' }]);

  // What was saved.
  const saved = await messagesIn(chat.id);
  assert.deepEqual(
    saved.map((m) => [m.role, m.content, m.tokens_input, m.tokens_output]),
    [
      ['user', 'What is the capital of France?', 0, 0],
      ['assistant', 'Paris is the capital.', 21, 5],
    ]
  );
  const [[usage]] = await sequelize.query(
    'SELECT tokens_input, tokens_output FROM usage_records WHERE user_id = :userId AND model_id = :modelId',
    { replacements: { userId: alice.user.id, modelId: bySlug('gpt-4o').id } }
  );
  assert.deepEqual([Number(usage.tokens_input), Number(usage.tokens_output)], [21, 5]);
});

test('earlier turns are sent as context with the next message', async () => {
  const chat = await newChat();
  mock.reply = { chunks: ['Hi Sam.'] };
  await send(chat.id, 'My name is Sam.');
  mock.reply = { chunks: ['Your name is Sam.'] };
  mock.requests = [];

  await send(chat.id, 'What is my name?');

  assert.deepEqual(mock.requests[0].body.messages, [
    { role: 'user', content: 'My name is Sam.' },
    { role: 'assistant', content: 'Hi Sam.' },
    { role: 'user', content: 'What is my name?' },
  ]);
});

test('a provider refusal is a clear error and saves nothing', async () => {
  const chat = await newChat();
  mock.reply = { status: 401 };

  const res = await send(chat.id, 'Hello?');

  assert.equal(res.status, 502);
  assert.equal(res.body.code, 'PROVIDER_AUTH_FAILED');
  assert.doesNotMatch(res.body.error, /test-openai-key|mock upstream/, 'provider details are not leaked');
  assert.deepEqual(await messagesIn(chat.id), []);
});

test('provider rate limits are reported as retryable', async () => {
  const chat = await newChat();
  mock.reply = { status: 429 };
  const res = await send(chat.id, 'Hello?');
  assert.equal(res.status, 503);
  assert.equal(res.body.code, 'PROVIDER_RATE_LIMITED');
});

test('models that are not connected are refused before any provider call', async () => {
  const chat = await newChat();
  const res = await send(chat.id, 'Hello?', 'claude-sonnet-4');
  assert.equal(res.status, 400);
  assert.equal(res.body.code, 'MODEL_UNAVAILABLE');
  assert.equal(mock.requests.length, 0);
});

test('input is validated and chats are private', async () => {
  const chat = await newChat();
  const empty = await send(chat.id, '   ');
  assert.equal(empty.status, 400);
  assert.equal(empty.body.code, 'EMPTY_MESSAGE');

  const tooLong = await send(chat.id, 'x'.repeat(32001));
  assert.equal(tooLong.body.code, 'MESSAGE_TOO_LONG');

  const someoneElses = await send(chat.id, 'Hello', 'gpt-4o', { token: bob.token });
  assert.equal(someoneElses.status, 404);
  assert.equal(mock.requests.length, 0);
});

test('a reply that fails part-way keeps what arrived and reports the error', async () => {
  const chat = await newChat();
  mock.reply = { chunks: ['Partial', ' answer', ' never finished'], failAfter: 2 };

  const { events } = await send(chat.id, 'Tell me something');

  const last = events.at(-1);
  assert.equal(last.type, 'error');
  assert.equal(last.code, 'PROVIDER_ERROR');
  assert.equal(last.message.content, 'Partial answer');
  const saved = await messagesIn(chat.id);
  assert.deepEqual(saved.map((m) => m.content), ['Tell me something', 'Partial answer']);
});

test('stopping a reply cancels the provider call and keeps the partial text', async () => {
  const chat = await newChat();
  mock.reply = { chunks: ['One', ' two', ' three', ' four', ' five'], delayMs: 150 };

  let deltas = 0;
  const stopResult = await send(chat.id, 'Count to five', 'gpt-4o', {
    onEvent: (e) => (e.type === 'delta' && ++deltas === 2 ? 'abort' : undefined),
  });
  assert.equal(stopResult.aborted, true);

  // Give the server a moment to notice the disconnect and save.
  let saved = [];
  for (let i = 0; i < 40 && saved.length < 2; i++) {
    await new Promise((r) => setTimeout(r, 50));
    saved = await messagesIn(chat.id);
  }
  assert.equal(saved.length, 2);
  assert.match(saved[1].content, /^One two/);
  assert.ok(!saved[1].content.includes('five'));
  assert.equal(mock.aborted, 1, 'the upstream request was cancelled, not left running');

  // The user can send again straight away.
  mock.reply = { chunks: ['Ready.'] };
  const next = await send(chat.id, 'Again');
  assert.equal(next.events.at(-1).type, 'done');
});

test('one reply at a time per user', async () => {
  const chat = await newChat();
  mock.reply = { chunks: ['slow', ' reply'], delayMs: 200 };

  const first = send(chat.id, 'First');
  await new Promise((r) => setTimeout(r, 100));
  const second = await send(chat.id, 'Second');

  assert.equal(second.status, 429);
  assert.equal(second.body.code, 'REPLY_IN_PROGRESS');
  assert.equal((await first).events.at(-1).type, 'done');
});

test(
  'a reply survives garbage collection before it is read (regression: Node fetch cancelled the unread body)',
  { skip: typeof global.gc !== 'function' && 'needs node --expose-gc' },
  async () => {
    const { openChatStream } = require('../src/gateway/openaiCompatible');
    const { getProvider } = require('../src/gateway/providers');
    mock.reply = { chunks: ['still', ' here'] };

    for (let i = 0; i < 5; i++) {
      const stream = await openChatStream({ provider: getProvider('OpenAI'), model: 'gpt-4o', messages: [], maxTokens: 10 });
      // The controller saves the user's message before reading; GC can run then.
      for (let k = 0; k < 3; k++) {
        global.gc();
        await new Promise((r) => setTimeout(r, 5));
      }
      const texts = [];
      for await (const e of stream.events) texts.push(e.text);
      assert.deepEqual(texts, ['still', ' here']);
    }
  }
);
