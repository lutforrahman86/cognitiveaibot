/**
 * The shared Redis connection, when REDIS_URL is set (rate limits and the
 * cache use it). Null without it: callers fall back to per-process memory.
 * Reconnects on its own; a Redis outage makes callers fall back, not fail.
 */
let client = null;
let clientUrl = null;
let ready = null;

function getRedis() {
  const url = process.env.REDIS_URL || null;
  if (url !== clientUrl) {
    if (client) {
      const old = client;
      ready.then(() => old.quit()).catch(() => {});
    }
    client = null;
    ready = null;
    clientUrl = url;
    if (url) {
      const { createClient } = require('redis');
      client = createClient({ url, socket: { reconnectStrategy: (retries) => Math.min(retries * 200, 5000) } });
      client.on('error', (err) => console.error('[redis]', err.message));
      ready = client.connect();
    }
  }
  return client ? ready.then(() => client) : null;
}

module.exports = { getRedis };
