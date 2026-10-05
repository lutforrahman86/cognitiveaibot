/**
 * Account recovery and lifecycle (roadmap B18): password reset, email
 * verification, account deletion and data export.
 *
 * Email links carry a random 256-bit token; only its SHA-256 hash is stored.
 * A token works once and expires (reset: 1 hour, verification: 24 hours),
 * and issuing a new one cancels the previous unused one.
 */
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcrypt');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const metering = require('../gateway/metering');
const { getStripe } = require('../billing/stripe');
const { sendEmail, templates } = require('../services/email');

const TTL_MINUTES = { password_reset: 60, verify_email: 24 * 60 };
// Reset emails per account per hour, so the form can't be used to flood an inbox.
const MAX_RESETS_PER_HOUR = 3;
const MIN_PASSWORD = 8;

const hash = (token) => crypto.createHash('sha256').update(token).digest('hex');
const fail = (code, message, status = 400) => new GatewayError(code, message, { status });

async function issueToken(userId, purpose) {
  const token = crypto.randomBytes(32).toString('base64url');
  await sequelize.transaction(async (transaction) => {
    await sequelize.query(
      'UPDATE auth_tokens SET used_at = now() WHERE user_id = :userId AND purpose = :purpose AND used_at IS NULL',
      { replacements: { userId, purpose }, transaction }
    );
    await sequelize.query(
      `INSERT INTO auth_tokens (user_id, purpose, token_hash, expires_at)
       VALUES (:userId, :purpose, :hash, now() + (:minutes * interval '1 minute'))`,
      { replacements: { userId, purpose, hash: hash(token), minutes: TTL_MINUTES[purpose] }, transaction }
    );
  });
  return token;
}

/** Marks a valid token used and returns its user id; null if invalid, used or expired. */
async function consumeToken(token, purpose) {
  if (typeof token !== 'string' || token.length < 20 || token.length > 100) return null;
  const [row] = await sequelize.query(
    `UPDATE auth_tokens SET used_at = now()
      WHERE token_hash = :hash AND purpose = :purpose AND used_at IS NULL AND expires_at > now()
      RETURNING user_id`,
    { replacements: { hash: hash(token), purpose }, type: QueryTypes.SELECT }
  );
  return row?.user_id || null;
}

function checkPassword(password) {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD) {
    throw fail('WEAK_PASSWORD', `Use a password of at least ${MIN_PASSWORD} characters.`);
  }
  if (password.length > 200) throw fail('WEAK_PASSWORD', 'That password is too long.');
}

/**
 * Emails a reset link if an account has this address. Always "succeeds", so
 * the form can't be used to find out which emails have accounts.
 */
async function requestPasswordReset(email) {
  const address = typeof email === 'string' ? email.trim().toLowerCase() : '';
  const [user] = await sequelize.query(
    `SELECT u.id, u.email, u.suspended_at,
            (SELECT count(*)::int FROM auth_tokens t
              WHERE t.user_id = u.id AND t.purpose = 'password_reset' AND t.created_at > now() - interval '1 hour') AS recent
       FROM users u WHERE u.email = :address`,
    { replacements: { address }, type: QueryTypes.SELECT }
  );
  if (!user || user.suspended_at || user.recent >= MAX_RESETS_PER_HOUR) return;
  const token = await issueToken(user.id, 'password_reset');
  await sendEmail({ to: user.email, ...templates.passwordReset(token) });
}

/** Sets a new password from an emailed link and signs every existing session out. */
async function resetPassword(token, password) {
  checkPassword(password);
  const userId = await consumeToken(token, 'password_reset');
  if (!userId) throw fail('INVALID_TOKEN', 'This reset link is invalid or has expired. Ask for a new one.');
  const passwordHash = await bcrypt.hash(password, 10);
  // Following the emailed link also proves the address is theirs.
  const [user] = await sequelize.query(
    `UPDATE users SET password_hash = :passwordHash, password_changed_at = now(),
            email_verified_at = COALESCE(email_verified_at, now()), updated_at = now()
      WHERE id = :userId RETURNING email`,
    { replacements: { userId, passwordHash }, type: QueryTypes.SELECT }
  );
  await sequelize.query(
    "UPDATE auth_tokens SET used_at = now() WHERE user_id = :userId AND purpose = 'password_reset' AND used_at IS NULL",
    { replacements: { userId } }
  );
  await grantTrialCredits(userId);
  await sendEmail({ to: user.email, ...templates.passwordChanged() });
  return userId;
}

/** Changes the password of a signed-in user who knows the current one. */
async function changePassword(userId, currentPassword, newPassword) {
  checkPassword(newPassword);
  const [user] = await sequelize.query('SELECT email, password_hash FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (user.password_hash && !(await bcrypt.compare(String(currentPassword || ''), user.password_hash))) {
    throw fail('WRONG_PASSWORD', 'Your current password isn’t right.', 403);
  }
  await sequelize.query(
    'UPDATE users SET password_hash = :passwordHash, password_changed_at = now(), updated_at = now() WHERE id = :userId',
    { replacements: { userId, passwordHash: await bcrypt.hash(newPassword, 10) } }
  );
  await sendEmail({ to: user.email, ...templates.passwordChanged() });
}

/**
 * Trial credits (SIGNUP_TRIAL_CREDITS) are granted once, when an account's
 * email is verified, so throwaway sign-ups can't farm them.
 */
async function grantTrialCredits(userId) {
  const trial = Number(process.env.SIGNUP_TRIAL_CREDITS || 0);
  if (!(trial > 0)) return;
  await metering.addCredits(userId, trial, { type: 'grant', reason: 'Trial credits', externalRef: `trial:${userId}` });
}

async function sendVerification(userId) {
  const [user] = await sequelize.query('SELECT email, email_verified_at FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (!user || user.email_verified_at) return false;
  const token = await issueToken(userId, 'verify_email');
  await sendEmail({ to: user.email, ...templates.verifyEmail(token) });
  return true;
}

async function verifyEmail(token) {
  const userId = await consumeToken(token, 'verify_email');
  if (!userId) throw fail('INVALID_TOKEN', 'This confirmation link is invalid or has expired. Ask for a new one.');
  await sequelize.query('UPDATE users SET email_verified_at = COALESCE(email_verified_at, now()) WHERE id = :userId', {
    replacements: { userId },
  });
  await grantTrialCredits(userId);
  return userId;
}

/** A signed-in user's verified state, for the checks that need it. */
async function requireVerified(userId) {
  const [user] = await sequelize.query('SELECT email_verified_at FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (!user?.email_verified_at) {
    throw fail('EMAIL_NOT_VERIFIED', 'Confirm your email address first: use the link we emailed you.', 403);
  }
}

/** Everything the service holds about a user, as one JSON document. */
async function exportData(userId) {
  const q = (sql) => sequelize.query(sql, { replacements: { userId }, type: QueryTypes.SELECT });
  const [[profile], settings, chats, messages, credits, subscriptions, keys, usage] = await Promise.all([
    q(`SELECT id, email, name, avatar_url, created_at, email_verified_at,
              (google_id IS NOT NULL) AS google_linked, (github_id IS NOT NULL) AS github_linked
         FROM users WHERE id = :userId`),
    q('SELECT * FROM user_settings WHERE user_id = :userId'),
    q('SELECT id, title, created_at, updated_at FROM chats WHERE user_id = :userId ORDER BY created_at'),
    q(`SELECT m.chat_id, m.role, m.content, m.created_at, a.name AS model
         FROM messages m JOIN chats c ON c.id = m.chat_id LEFT JOIN ai_models a ON a.id = m.model_id
        WHERE c.user_id = :userId ORDER BY m.created_at`),
    q(`SELECT type, amount_micros / 1e6 AS credits, balance_after_micros / 1e6 AS balance_after, reason, created_at
         FROM credit_transactions WHERE user_id = :userId ORDER BY created_at`),
    q(`SELECT source, product_id, status, started_at, expires_at, cancel_at_period_end
         FROM subscriptions WHERE user_id = :userId ORDER BY created_at`),
    q('SELECT name, prefix, created_at, last_used_at, revoked_at FROM api_keys WHERE user_id = :userId ORDER BY created_at'),
    q(`SELECT r.created_at, a.name AS model, r.source, r.status, r.input_tokens, r.output_tokens, r.unit, r.units,
              r.charged_micros / 1e6 AS credits
         FROM request_logs r LEFT JOIN ai_models a ON a.id = r.model_id
        WHERE r.user_id = :userId ORDER BY r.created_at`),
  ]);
  const byChat = new Map(chats.map((c) => [c.id, { ...c, messages: [] }]));
  for (const m of messages) byChat.get(m.chat_id)?.messages.push({ role: m.role, content: m.content, model: m.model, created_at: m.created_at });
  return {
    exported_at: new Date().toISOString(),
    profile,
    settings: settings[0] || null,
    chats: [...byChat.values()],
    credit_history: credits.map((c) => ({ ...c, credits: Number(c.credits), balance_after: Number(c.balance_after) })),
    subscriptions,
    api_keys: keys,
    usage: usage.map((u) => ({ ...u, credits: Number(u.credits) })),
    note: 'Prompts and replies sent through the developer API are never stored, so they are not included.',
  };
}

/**
 * Deletes an account: cancels any Stripe subscription, removes the user's
 * files and every personal record (chats, messages, settings, keys,
 * subscriptions, balance). Ledger entries and request logs are kept without
 * the user link, as billing records. `confirm` must be the account's
 * password, or its email for accounts without one (Google/GitHub sign-in).
 */
async function deleteAccount(userId, confirm) {
  const [user] = await sequelize.query(
    'SELECT id, email, password_hash, stripe_customer_id, avatar_url, type FROM users WHERE id = :userId',
    { replacements: { userId }, type: QueryTypes.SELECT }
  );
  if (!user) throw fail('NOT_FOUND', 'Account not found.', 404);
  const confirmed = user.password_hash
    ? await bcrypt.compare(String(confirm || ''), user.password_hash)
    : String(confirm || '').trim().toLowerCase() === user.email;
  if (!confirmed) {
    throw fail('CONFIRMATION_FAILED', user.password_hash ? 'That password isn’t right.' : 'Type your email address to confirm.', 403);
  }
  if (user.type === 'admin') {
    const [{ admins }] = await sequelize.query("SELECT count(*)::int AS admins FROM users WHERE type = 'admin'", { type: QueryTypes.SELECT });
    if (admins <= 1) throw fail('LAST_ADMIN', 'This is the only admin account. Make another admin before deleting it.');
  }

  // Deleting the Stripe customer cancels its subscriptions at once, so no
  // further renewals are charged.
  const stripe = getStripe();
  if (stripe && user.stripe_customer_id) {
    await stripe.customers.del(user.stripe_customer_id);
  }

  const jobs = await sequelize.query('SELECT output_path FROM media_jobs WHERE user_id = :userId AND output_path IS NOT NULL', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  for (const job of jobs) fs.rmSync(job.output_path, { force: true });
  if (user.avatar_url?.startsWith('/uploads/')) {
    fs.rmSync(path.join(__dirname, '..', '..', user.avatar_url), { force: true });
  }

  await sequelize.transaction(async (transaction) => {
    // In-flight holds can't settle against a deleted account: release them.
    await sequelize.query(
      `UPDATE request_logs SET status = 'cancelled', error_code = 'ACCOUNT_DELETED', finished_at = now()
        WHERE user_id = :userId AND status = 'in_progress'`,
      { replacements: { userId }, transaction }
    );
    await sequelize.query('DELETE FROM users WHERE id = :userId', { replacements: { userId }, transaction });
  });
  await sendEmail({ to: user.email, ...templates.accountDeleted() }).catch((err) =>
    console.error('account deleted email:', err.message)
  );
}

module.exports = {
  requestPasswordReset,
  resetPassword,
  changePassword,
  sendVerification,
  verifyEmail,
  requireVerified,
  grantTrialCredits,
  exportData,
  deleteAccount,
  MIN_PASSWORD,
};
