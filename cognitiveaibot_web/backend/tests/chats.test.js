const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser } = require('./helpers');

let sequelize;
let server;
let alice;
let bob;

before(async () => {
  sequelize = await resetDatabase();
  server = await startApp();
  alice = await registerUser(server.baseUrl, 'Alice');
  bob = await registerUser(server.baseUrl, 'Bob');
});

after(async () => {
  await server.close();
  await sequelize.close();
});

test('register, then log in with the same password', async () => {
  const login = await api(server.baseUrl, 'POST', '/api/auth/login', {
    body: { email: alice.email, password: 'password123' },
  });
  assert.equal(login.status, 200);
  const me = await api(server.baseUrl, 'GET', '/api/auth/me', { token: login.body.token });
  assert.equal(me.status, 200);
  assert.equal(me.body.user.email, alice.email);

  const wrong = await api(server.baseUrl, 'POST', '/api/auth/login', {
    body: { email: alice.email, password: 'not-the-password' },
  });
  assert.equal(wrong.status, 401);
});

test('a chat can be renamed (regression: Chat.update called itself and crashed)', async () => {
  const created = await api(server.baseUrl, 'POST', '/api/chats', { token: alice.token, body: {} });
  assert.equal(created.status, 201);

  const renamed = await api(server.baseUrl, 'PATCH', `/api/chats/${created.body.chat.id}`, {
    token: alice.token,
    body: { title: 'Trip planning' },
  });
  assert.equal(renamed.status, 200);
  assert.equal(renamed.body.chat.title, 'Trip planning');
});

test("another user can't read, rename or delete someone's chat", async () => {
  const created = await api(server.baseUrl, 'POST', '/api/chats', { token: alice.token, body: {} });
  const id = created.body.chat.id;

  assert.equal((await api(server.baseUrl, 'GET', `/api/chats/${id}`, { token: bob.token })).status, 404);
  assert.equal(
    (await api(server.baseUrl, 'PATCH', `/api/chats/${id}`, { token: bob.token, body: { title: 'x' } })).status,
    404
  );
  assert.equal((await api(server.baseUrl, 'DELETE', `/api/chats/${id}`, { token: bob.token })).status, 404);
  assert.equal((await api(server.baseUrl, 'GET', `/api/chats/${id}`, { token: alice.token })).status, 200);
});

test('a single model can be fetched by id and by slug (regression: AIModel.findAll override)', async () => {
  const AIModel = require('../src/models/AIModel');
  const a = await AIModel.create({ provider: 'OpenAI', name: 'Model A', slug: 'model-a' });
  await AIModel.create({ provider: 'OpenAI', name: 'Model B', slug: 'model-b' });

  const byId = await api(server.baseUrl, 'GET', `/api/models/${a.id}`);
  assert.equal(byId.status, 200);
  assert.equal(byId.body.model.slug, 'model-a');

  const bySlug = await api(server.baseUrl, 'GET', '/api/models/by-slug/model-b');
  assert.equal(bySlug.status, 200);
  assert.equal(bySlug.body.model.slug, 'model-b');

  const missing = await api(server.baseUrl, 'GET', '/api/models/by-slug/nope');
  assert.equal(missing.status, 404);
});

test("clients can't write assistant messages or token counts directly", async () => {
  const created = await api(server.baseUrl, 'POST', '/api/chats', { token: alice.token, body: {} });
  const id = created.body.chat.id;

  const forged = await api(server.baseUrl, 'POST', `/api/chats/${id}/messages`, {
    token: alice.token,
    body: { role: 'assistant', content: 'I am the AI', tokens_output: 999999 },
  });
  assert.equal(forged.status, 400);
  assert.equal(forged.body.code, 'INVALID_ROLE');

  const user = await api(server.baseUrl, 'POST', `/api/chats/${id}/messages`, {
    token: alice.token,
    body: { content: 'hello', tokens_input: 999999 },
  });
  assert.equal(user.status, 201);
  assert.equal(user.body.message.role, 'user');
  assert.equal(user.body.message.tokens_input, 0);
});
