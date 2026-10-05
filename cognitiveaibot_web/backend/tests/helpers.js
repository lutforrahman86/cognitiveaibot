/**
 * Shared test setup. Require this before anything from src/: the database
 * connection is created from the environment at require time.
 *
 * Tests run against a separate database (TEST_DATABASE_URL, or the .env
 * DATABASE_URL with "_test" appended to the name) that is wiped before every
 * test file. They refuse to run against a database not ending in "_test".
 *
 * AI providers are replaced by a local mock speaking the OpenAI streaming
 * format, so no real provider is ever called and no key is needed.
 */
const fs = require('fs');
const path = require('path');

function testDatabaseUrl() {
  if (process.env.TEST_DATABASE_URL) return process.env.TEST_DATABASE_URL;
  const envFile = path.join(__dirname, '..', '.env');
  const env = fs.existsSync(envFile) ? require('dotenv').parse(fs.readFileSync(envFile)) : {};
  if (!env.DATABASE_URL) {
    throw new Error('Set TEST_DATABASE_URL, or DATABASE_URL in backend/.env, to run the tests.');
  }
  const url = new URL(env.DATABASE_URL);
  url.pathname = `${url.pathname.replace(/^\//, '')}_test`;
  return url.toString();
}

const databaseUrl = testDatabaseUrl();
if (!new URL(databaseUrl).pathname.endsWith('_test')) {
  throw new Error(`Refusing to run tests against ${new URL(databaseUrl).pathname}: the name must end in _test.`);
}

// Only what the app needs. The developer's real .env (and its provider keys)
// is deliberately not loaded.
for (const key of Object.keys(process.env)) {
  if (/_API_KEY$|_BASE_URL$/.test(key)) delete process.env[key];
}
process.env.DATABASE_URL = databaseUrl;
process.env.JWT_SECRET = 'test-jwt-secret';
// Every test signs up from 127.0.0.1; the per-IP limits get their own test.
process.env.SIGNUPS_PER_IP_PER_HOUR = '100000';
process.env.RESETS_PER_IP_PER_HOUR = '100000';
process.env.APP_MESSAGES_PER_MINUTE = '100000';
// Moderation is switched on by the tests that cover it.
process.env.MODERATION = 'off';
process.env.NODE_ENV = 'test';

async function ensureDatabaseExists() {
  const { Client } = require('pg');
  const url = new URL(databaseUrl);
  const name = url.pathname.replace(/^\//, '');
  url.pathname = '/postgres';
  const client = new Client({ connectionString: url.toString() });
  await client.connect();
  try {
    const { rowCount } = await client.query('SELECT 1 FROM pg_database WHERE datname = $1', [name]);
    if (!rowCount) await client.query(`CREATE DATABASE "${name.replace(/"/g, '')}"`);
  } finally {
    await client.end();
  }
}

/** Drops everything and rebuilds the schema from migrations, as a fresh install would. */
async function resetDatabase() {
  await ensureDatabaseExists();
  const { sequelize } = require('../src/config/database');
  await sequelize.query('DROP SCHEMA public CASCADE; CREATE SCHEMA public;');
  require('../src/models');
  const { createMigrator } = require('../src/db/migrator');
  await createMigrator({ logger: undefined }).up();
  return sequelize;
}

/** Starts the app on a random port. */
async function startApp() {
  const { app } = require('../src/app');
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const baseUrl = `http://127.0.0.1:${server.address().port}`;
  return { baseUrl, close: () => new Promise((r) => server.close(r)) };
}

async function api(baseUrl, method, urlPath, { token, body } = {}) {
  const res = await fetch(`${baseUrl}${urlPath}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = null;
  }
  return { status: res.status, body: json, text };
}

let userCounter = 0;
/**
 * Signs up a user through the API. Their email counts as confirmed unless
 * `verified: false` (most features need it confirmed).
 */
async function registerUser(baseUrl, name = 'Test User', { verified = true } = {}) {
  userCounter += 1;
  const email = `user${userCounter}-${Date.now()}@example.test`;
  const res = await api(baseUrl, 'POST', '/api/auth/register', {
    body: { email, password: 'password123', name },
  });
  if (res.status !== 201) throw new Error(`register failed: ${res.status} ${res.text}`);
  if (verified) {
    const { sequelize } = require('../src/config/database');
    await sequelize.query('UPDATE users SET email_verified_at = now() WHERE id = :id', { replacements: { id: res.body.user.id } });
  }
  return { token: res.body.token, user: res.body.user, email, password: 'password123' };
}

/**
 * POSTs and collects a Server-Sent Events reply. `onEvent` may return 'abort'
 * to disconnect mid-stream, the way a browser does when the user hits Stop.
 */
async function streamPost(baseUrl, urlPath, { token, body, onEvent } = {}) {
  const controller = new AbortController();
  const res = await fetch(`${baseUrl}${urlPath}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
    signal: controller.signal,
  });
  if (!(res.headers.get('content-type') || '').startsWith('text/event-stream')) {
    return { status: res.status, body: await res.json(), events: [] };
  }
  const events = [];
  const decoder = new TextDecoder();
  let buffer = '';
  let aborted = false;
  try {
    for await (const chunk of res.body) {
      buffer += decoder.decode(chunk, { stream: true });
      const parts = buffer.split('\n\n');
      buffer = parts.pop();
      for (const part of parts) {
        if (!part.startsWith('data: ')) continue;
        const event = JSON.parse(part.slice(6));
        events.push(event);
        if (onEvent && onEvent(event) === 'abort') {
          aborted = true;
          controller.abort();
          return { status: res.status, events, aborted };
        }
      }
    }
  } catch (err) {
    if (err.name !== 'AbortError') throw err;
  }
  return { status: res.status, events, aborted };
}

const { startMockProvider } = require('./mockProvider');

module.exports = { resetDatabase, startApp, api, registerUser, streamPost, startMockProvider };
