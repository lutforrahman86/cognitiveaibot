/**
 * A short-lived cache for read-heavy, rarely-changing responses (the public
 * model list and plan catalog). In Redis when REDIS_URL is set, so every
 * process shares it and an admin edit clears it everywhere; in memory
 * otherwise. Any cache error just means computing the value again.
 */
const { getRedis } = require('./redis');

const memory = new Map();

async function cached(key, ttlSeconds, compute) {
  const fullKey = `cache:${key}`;
  try {
    const redis = await getRedis();
    if (redis) {
      const hit = await redis.get(fullKey);
      if (hit !== null) return JSON.parse(hit);
    } else {
      const hit = memory.get(fullKey);
      if (hit && hit.expiresAt > Date.now()) return hit.value;
    }
  } catch (err) {
    console.error('[cache] read failed:', err.message);
  }
  const value = await compute();
  try {
    const redis = await getRedis();
    if (redis) await redis.set(fullKey, JSON.stringify(value), { EX: ttlSeconds });
    else memory.set(fullKey, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
  } catch (err) {
    console.error('[cache] write failed:', err.message);
  }
  return value;
}

/** Drops every cached value whose key starts with `prefix`. */
async function invalidate(prefix) {
  const full = `cache:${prefix}`;
  for (const key of memory.keys()) if (key.startsWith(full)) memory.delete(key);
  try {
    const redis = await getRedis();
    if (!redis) return;
    for await (const keys of redis.scanIterator({ MATCH: `${full}*` })) {
      if (keys.length) await redis.del(keys);
    }
  } catch (err) {
    console.error('[cache] invalidate failed:', err.message);
  }
}

module.exports = { cached, invalidate };
