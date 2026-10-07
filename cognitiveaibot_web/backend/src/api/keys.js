/**
 * Developer API keys (roadmap C1) and who may use the API.
 *
 * A key is "sk-cog-" + 43 characters of base64url (256 random bits). It is
 * returned once, at creation; only its SHA-256 hash is stored, with the first
 * few characters kept visible so users can tell keys apart.
 *
 * API access comes from the plan (Decision 5: no free API tier): only an
 * active subscription to a plan with `includes_api` can create or use keys.
 * Keys outlive a lapsed plan and work again when the user resubscribes.
 */
const crypto = require('crypto');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const { currentSubscription } = require('../billing/service');
const { getPlan } = require('../billing/plans');

const KEY_PREFIX = 'sk-cog-';
const VISIBLE_CHARS = KEY_PREFIX.length + 4;
const MAX_ACTIVE_KEYS = 20;

const hashKey = (key) => crypto.createHash('sha256').update(key).digest('hex');

/** The user's API plan and limits, or null when their plan doesn't include the API. */
async function apiAccess(userId) {
  const sub = await currentSubscription(userId);
  const plan = sub?.plan_id ? await getPlan(sub.plan_id) : null;
  if (!plan?.includes_api) return null;
  return {
    plan,
    limits: { requestsPerMinute: plan.api_requests_per_minute, tokensPerMinute: plan.api_tokens_per_minute },
  };
}

const requireAccessError = () =>
  new GatewayError('API_ACCESS_REQUIRED', 'Your plan doesn’t include API access. Upgrade to a plan that does.', {
    status: 403,
  });

const toPublic = (k) => ({
  id: k.id,
  name: k.name,
  prefix: k.prefix,
  created_at: k.created_at,
  last_used_at: k.last_used_at,
  revoked_at: k.revoked_at,
});

async function listKeys(userId) {
  const rows = await sequelize.query(
    `SELECT id, name, prefix, created_at, last_used_at, revoked_at FROM api_keys
      WHERE user_id = :userId ORDER BY revoked_at IS NOT NULL, created_at DESC`,
    { replacements: { userId }, type: QueryTypes.SELECT }
  );
  return rows.map(toPublic);
}

/** Creates a key and returns it in full. This is the only time it can be seen. */
async function createKey(userId, name) {
  if (!(await apiAccess(userId))) throw requireAccessError();
  const label = typeof name === 'string' ? name.trim().slice(0, 100) : '';
  if (!label) throw new GatewayError('NAME_REQUIRED', 'Give the key a name, such as where it will be used.', { status: 400 });

  const [{ count }] = await sequelize.query(
    'SELECT count(*)::int AS count FROM api_keys WHERE user_id = :userId AND revoked_at IS NULL',
    { replacements: { userId }, type: QueryTypes.SELECT }
  );
  if (count >= MAX_ACTIVE_KEYS) {
    throw new GatewayError('TOO_MANY_KEYS', `You can have up to ${MAX_ACTIVE_KEYS} active keys. Revoke one first.`, {
      status: 400,
    });
  }

  const key = KEY_PREFIX + crypto.randomBytes(32).toString('base64url');
  const [row] = await sequelize.query(
    `INSERT INTO api_keys (user_id, name, key_hash, prefix) VALUES (:userId, :name, :hash, :prefix)
     RETURNING id, name, prefix, created_at, last_used_at, revoked_at`,
    {
      replacements: { userId, name: label, hash: hashKey(key), prefix: key.slice(0, VISIBLE_CHARS) },
      type: QueryTypes.SELECT,
    }
  );
  return { ...toPublic(row), key };
}

async function revokeKey(userId, keyId) {
  if (!/^[0-9a-f-]{36}$/i.test(String(keyId))) return false;
  const rows = await sequelize.query(
    `UPDATE api_keys SET revoked_at = COALESCE(revoked_at, now())
      WHERE id = :keyId AND user_id = :userId RETURNING id`,
    { replacements: { keyId, userId }, type: QueryTypes.SELECT }
  );
  return rows.length > 0;
}

/**
 * Resolves a presented key to its active key row, or null. Records when the
 * key was last used (at most once a minute, to avoid a write per request).
 */
async function authenticate(presented) {
  if (typeof presented !== 'string' || !presented.startsWith(KEY_PREFIX) || presented.length > 100) return null;
  const [row] = await sequelize.query(
    `SELECT k.id, k.user_id, k.name, u.suspended_at FROM api_keys k JOIN users u ON u.id = k.user_id
      WHERE k.key_hash = :hash AND k.revoked_at IS NULL`,
    { replacements: { hash: hashKey(presented) }, type: QueryTypes.SELECT }
  );
  if (!row) return null;
  sequelize
    .query(
      `UPDATE api_keys SET last_used_at = now()
        WHERE id = :id AND (last_used_at IS NULL OR last_used_at < now() - interval '1 minute')`,
      { replacements: { id: row.id } }
    )
    .catch((err) => console.error('api key last_used_at:', err.message));
  return row;
}

module.exports = { apiAccess, listKeys, createKey, revokeKey, authenticate, requireAccessError, KEY_PREFIX };
