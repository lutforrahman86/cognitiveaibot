const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser } = require('./helpers');
const { startMockStripe } = require('./mockStripe');

let sequelize;
let server;
let stripeMock;
let email;
let metering;

const linkToken = (mail) => mail.text.match(/token=([A-Za-z0-9_-]+)/)[1];
const mailTo = (address) => email.outbox.filter((m) => m.to === address);
// Sign-up sends its confirmation email in the background: wait for it.
async function waitForMail(address, count = 1) {
  for (let i = 0; i < 40 && mailTo(address).length < count; i++) await new Promise((r) => setTimeout(r, 25));
  return mailTo(address);
}
const me = (token) => api(server.baseUrl, 'GET', '/api/auth/me', { token });
const login = (address, password) => api(server.baseUrl, 'POST', '/api/auth/login', { body: { email: address, password } });

before(async () => {
  sequelize = await resetDatabase();
  stripeMock = await startMockStripe();
  email = require('../src/services/email');
  metering = require('../src/gateway/metering');
  server = await startApp();
});

beforeEach(() => {
  email.outbox.length = 0;
  process.env.SIGNUP_TRIAL_CREDITS = '5';
  process.env.STRIPE_SECRET_KEY = 'sk_test_mock';
  process.env.STRIPE_API_BASE = stripeMock.baseUrl;
});

after(async () => {
  await server.close();
  await stripeMock.close();
  await sequelize.close();
});

test('sign-up sends a confirmation link; confirming grants the trial credits once', async () => {
  const ann = await registerUser(server.baseUrl, 'Ann', { verified: false });
  assert.equal(ann.user.email_verified, false);
  assert.equal((await metering.getBalance(ann.user.id)).balance, 0, 'no trial credits before confirming');

  // Unconfirmed accounts can't buy or create API keys.
  const [[plan]] = await sequelize.query(
    "INSERT INTO plans (slug, name, kind, price_cents, credits) VALUES ('t', 'T', 'topup', 500, 400) RETURNING id"
  );
  const checkout = await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: ann.token, body: { plan_id: plan.id } });
  assert.equal(checkout.status, 403);
  assert.equal(checkout.body.code, 'EMAIL_NOT_VERIFIED');

  const [mail] = await waitForMail(ann.email);
  assert.match(mail.subject, /Confirm your email/);
  assert.match(mail.text, /\/verify-email\?token=/);
  const token = linkToken(mail);
  assert.equal((await api(server.baseUrl, 'POST', '/api/auth/verify-email', { body: { token } })).status, 200);
  assert.equal((await me(ann.token)).body.user.email_verified, true);
  assert.equal((await metering.getBalance(ann.user.id)).balance, 5);

  // The link works once; the trial can't be granted twice.
  const reused = await api(server.baseUrl, 'POST', '/api/auth/verify-email', { body: { token } });
  assert.equal(reused.body.code, 'INVALID_TOKEN');
  assert.equal((await api(server.baseUrl, 'POST', '/api/auth/resend-verification', { token: ann.token })).body.already_verified, true);
  assert.equal((await metering.getBalance(ann.user.id)).balance, 5);
  assert.equal((await api(server.baseUrl, 'POST', '/api/auth/verify-email', { body: { token: 'x'.repeat(43) } })).status, 400);
});

test('a resent confirmation link replaces the old one, and links expire', async () => {
  const ben = await registerUser(server.baseUrl, 'Ben', { verified: false });
  const first = linkToken((await waitForMail(ben.email))[0]);
  await api(server.baseUrl, 'POST', '/api/auth/resend-verification', { token: ben.token });
  const second = linkToken(mailTo(ben.email)[1]);
  assert.equal((await api(server.baseUrl, 'POST', '/api/auth/verify-email', { body: { token: first } })).body.code, 'INVALID_TOKEN');

  await sequelize.query("UPDATE auth_tokens SET expires_at = now() - interval '1 minute' WHERE user_id = :id", {
    replacements: { id: ben.user.id },
  });
  assert.equal((await api(server.baseUrl, 'POST', '/api/auth/verify-email', { body: { token: second } })).body.code, 'INVALID_TOKEN');
});

test('password reset: no hint which emails exist, a single-use link, and every old session signed out', async () => {
  const cat = await registerUser(server.baseUrl, 'Cat');
  await waitForMail(cat.email);
  email.outbox.length = 0;
  const forgot = (address) => api(server.baseUrl, 'POST', '/api/auth/forgot-password', { body: { email: address } });

  const unknown = await forgot('nobody@example.test');
  assert.equal(unknown.status, 200);
  assert.equal(mailTo('nobody@example.test').length, 0);

  assert.equal((await forgot(cat.email.toUpperCase())).status, 200);
  const [mail] = mailTo(cat.email);
  assert.match(mail.subject, /Reset your/);
  const token = linkToken(mail);

  const weak = await api(server.baseUrl, 'POST', '/api/auth/reset-password', { body: { token, password: 'short' } });
  assert.equal(weak.body.code, 'WEAK_PASSWORD');
  // Make sure the old session is from an earlier second than the change.
  await new Promise((r) => setTimeout(r, 1100));
  const reset = await api(server.baseUrl, 'POST', '/api/auth/reset-password', { body: { token, password: 'a-new-password-1' } });
  assert.equal(reset.status, 200);
  assert.match(mailTo(cat.email).at(-1).subject, /password was changed/);

  assert.equal((await login(cat.email, cat.password)).status, 401);
  const fresh = await login(cat.email, 'a-new-password-1');
  assert.equal(fresh.status, 200);
  const old = await me(cat.token);
  assert.equal(old.status, 401);
  assert.equal(old.body.code, 'SESSION_EXPIRED');
  assert.equal((await me(fresh.body.token)).status, 200);
  const again = await api(server.baseUrl, 'POST', '/api/auth/reset-password', { body: { token, password: 'another-password' } });
  assert.equal(again.body.code, 'INVALID_TOKEN');

  // At most three reset emails per account per hour.
  email.outbox.length = 0;
  for (let i = 0; i < 5; i++) await forgot(cat.email);
  assert.equal(mailTo(cat.email).length, 2, 'one was already sent this hour, so two more');
});

test('changing the password needs the current one and signs other sessions out', async () => {
  const dan = await registerUser(server.baseUrl, 'Dan');
  const change = (token, body) => api(server.baseUrl, 'POST', '/api/users/me/password', { token, body });
  assert.equal((await change(dan.token, { current_password: 'wrong', new_password: 'new-password-123' })).body.code, 'WRONG_PASSWORD');
  assert.equal((await change(dan.token, { current_password: dan.password, new_password: 'short' })).body.code, 'WEAK_PASSWORD');

  const otherDevice = (await login(dan.email, dan.password)).body.token;
  await new Promise((r) => setTimeout(r, 1100));
  const res = await change(dan.token, { current_password: dan.password, new_password: 'new-password-123' });
  assert.equal(res.status, 200);
  assert.equal((await me(res.body.token)).status, 200, 'this device gets a fresh session');
  assert.equal((await me(otherDevice)).status, 401);
});

test('users can download everything held about them', async () => {
  const eve = await registerUser(server.baseUrl, 'Eve');
  const chat = (await api(server.baseUrl, 'POST', '/api/chats', { token: eve.token, body: { title: 'Trip ideas' } })).body.chat;
  await sequelize.query(
    "INSERT INTO messages (id, chat_id, role, content, created_at) VALUES (gen_random_uuid(), :chatId, 'user', 'Where should I go?', now())",
    { replacements: { chatId: chat.id } }
  );
  await metering.addCredits(eve.user.id, 3, { reason: 'Goodwill' });

  const res = await fetch(`${server.baseUrl}/api/users/me/export`, { headers: { Authorization: `Bearer ${eve.token}` } });
  assert.match(res.headers.get('content-disposition'), /attachment; filename="cognitiveaibot-export-.*\.json"/);
  const data = await res.json();
  assert.equal(data.profile.email, eve.email);
  assert.equal(data.chats[0].title, 'Trip ideas');
  assert.equal(data.chats[0].messages[0].content, 'Where should I go?');
  assert.deepEqual(data.credit_history.map((t) => [t.type, t.credits, t.reason]), [['grant', 3, 'Goodwill']]);
  assert.ok(!JSON.stringify(data).includes('password_hash'));
});

test('deleting an account removes personal data, cancels Stripe, keeps billing records, and needs the password', async () => {
  const fay = await registerUser(server.baseUrl, 'Fay');
  await sequelize.query("UPDATE users SET stripe_customer_id = 'cus_fay' WHERE id = :id", { replacements: { id: fay.user.id } });
  await api(server.baseUrl, 'POST', '/api/chats', { token: fay.token, body: { title: 'Private' } });
  await metering.addCredits(fay.user.id, 2, { reason: 'test' });

  const del = (body) => api(server.baseUrl, 'DELETE', '/api/users/me', { token: fay.token, body });
  assert.equal((await del({ confirm: 'wrong' })).body.code, 'CONFIRMATION_FAILED');
  assert.equal((await del({ confirm: fay.password })).status, 200);

  assert.ok(stripeMock.requests.some((r) => r.method === 'DELETE' && r.path === '/v1/customers/cus_fay'));
  const count = async (sql) => (await sequelize.query(sql, { replacements: { id: fay.user.id } }))[0][0].n;
  assert.equal(await count('SELECT count(*)::int AS n FROM users WHERE id = :id'), 0);
  assert.equal(await count('SELECT count(*)::int AS n FROM chats WHERE user_id = :id'), 0);
  assert.equal(await count("SELECT count(*)::int AS n FROM credit_transactions WHERE reason = 'test' AND user_id IS NULL"), 1);
  assert.equal((await login(fay.email, fay.password)).status, 401);
  assert.equal((await me(fay.token)).status, 401);
  assert.match(mailTo(fay.email).at(-1).subject, /account was deleted/);
});

test('the only admin can’t delete their account', async () => {
  const solo = await registerUser(server.baseUrl, 'Solo admin');
  await sequelize.query("UPDATE users SET type = 'user' WHERE type = 'admin'");
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: solo.user.id } });
  const res = await api(server.baseUrl, 'DELETE', '/api/users/me', { token: solo.token, body: { confirm: solo.password } });
  assert.equal(res.body.code, 'LAST_ADMIN');
});

test('sign-ups from one IP address are limited per hour', async () => {
  process.env.SIGNUPS_PER_IP_PER_HOUR = '2';
  try {
    await require('../src/gateway/rateLimit').resetLimits();
    const signUp = (n) => api(server.baseUrl, 'POST', '/api/auth/register', {
      body: { email: `burst${n}-${Date.now()}@example.test`, password: 'password123' },
    });
    assert.equal((await signUp(1)).status, 201);
    assert.equal((await signUp(2)).status, 201);
    const third = await signUp(3);
    assert.equal(third.status, 429);
    assert.equal(third.body.code, 'TOO_MANY_SIGNUPS');
  } finally {
    process.env.SIGNUPS_PER_IP_PER_HOUR = '100000';
  }
});
