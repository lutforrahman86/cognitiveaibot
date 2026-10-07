/**
 * Per-account API rate limits (roadmap C3): requests and tokens per minute,
 * set by the account's plan, counted across all of its keys.
 *
 * Counters live in Redis when REDIS_URL is set, so every server process shares
 * them. Without it they live in this process's memory, which is right for
 * development and tests but undercounts with several processes.
 *
 * Windows are fixed calendar minutes. Requests are counted when they start;
 * tokens when a call settles, so a request is refused once the minute's
 * tokens are used up (the call that crosses the limit still completes).
 * If Redis is unreachable, limits are skipped rather than refusing every
 * call: credits still cap what anyone can spend.
 */
const { getRedis } = require('../services/redis');

const WINDOW_MS = 60_000;

function memoryStore() {
  const counters = new Map();
  return {
    async incrBy(key, by, ttlMs) {
      const now = Date.now();
      const entry = counters.get(key);
      if (!entry || entry.expiresAt <= now) {
        counters.set(key, { value: by, expiresAt: now + ttlMs });
        return by;
      }
      entry.value += by;
      return entry.value;
    },
    async get(key) {
      const entry = counters.get(key);
      return entry && entry.expiresAt > Date.now() ? entry.value : 0;
    },
    reset() {
      counters.clear();
    },
  };
}

function redisStore(redis) {
  return {
    async incrBy(key, by, ttlMs) {
      const client = await redis;
      const [, value] = await client.multi().set(key, 0, { PX: ttlMs, NX: true }).incrBy(key, by).exec();
      return Number(value);
    },
    async get(key) {
      return Number((await (await redis).get(key)) || 0);
    },
    async reset() {
      const client = await redis;
      for await (const keys of client.scanIterator({ MATCH: 'rl:*' })) {
        if (keys.length) await client.del(keys);
      }
    },
  };
}

const memory = memoryStore();
function getStore() {
  const redis = getRedis();
  return redis ? redisStore(redis) : memory;
}

function window() {
  const start = Math.floor(Date.now() / WINDOW_MS) * WINDOW_MS;
  return { id: start, resetMs: start + WINDOW_MS - Date.now() };
}

/**
 * Counts one request against the account's limits. Returns whether it may
 * proceed, with the figures for the x-ratelimit-* headers.
 */
async function checkRequest(userId, limits) {
  const w = window();
  const base = { limitRequests: limits.requestsPerMinute, limitTokens: limits.tokensPerMinute, resetMs: w.resetMs };
  try {
    const s = getStore();
    const tokens = await s.get(`rl:${userId}:tok:${w.id}`);
    if (tokens >= limits.tokensPerMinute) {
      return { ...base, allowed: false, reason: 'tokens', remainingRequests: null, remainingTokens: 0 };
    }
    const requests = await s.incrBy(`rl:${userId}:req:${w.id}`, 1, WINDOW_MS * 2);
    return {
      ...base,
      allowed: requests <= limits.requestsPerMinute,
      reason: requests <= limits.requestsPerMinute ? null : 'requests',
      remainingRequests: Math.max(0, limits.requestsPerMinute - requests),
      remainingTokens: Math.max(0, limits.tokensPerMinute - tokens),
    };
  } catch (err) {
    console.error('[rate-limit] skipped:', err.message);
    return { ...base, allowed: true, reason: null, remainingRequests: null, remainingTokens: null };
  }
}

/** Adds a settled call's tokens to the account's current minute. */
async function addTokens(userId, tokens) {
  if (!tokens) return;
  try {
    await getStore().incrBy(`rl:${userId}:tok:${window().id}`, tokens, WINDOW_MS * 2);
  } catch (err) {
    console.error('[rate-limit] could not count tokens:', err.message);
  }
}

/** Clears every counter. For tests. */
async function resetLimits() {
  await getStore().reset();
}

module.exports = { checkRequest, addTokens, resetLimits };
