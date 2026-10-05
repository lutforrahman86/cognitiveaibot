/**
 * The Stripe client. Payments are off until STRIPE_SECRET_KEY is set: the
 * plan catalog still lists, but checkout answers 503.
 *
 * STRIPE_API_BASE points the SDK at another server (tests use a local
 * stand-in, the same way they replace AI providers).
 */
const Stripe = require('stripe');
const { GatewayError } = require('../gateway/errors');

let cached = { signature: null, client: null };

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return null;
  const base = process.env.STRIPE_API_BASE || '';
  const signature = `${key}|${base}`;
  if (cached.signature !== signature) {
    const options = { maxNetworkRetries: 2, appInfo: { name: 'CognitiveAI Bot' } };
    if (base) {
      const url = new URL(base);
      options.host = url.hostname;
      options.port = url.port;
      options.protocol = url.protocol.replace(':', '');
    }
    cached = { signature, client: new Stripe(key, options) };
  }
  return cached.client;
}

function requireStripe() {
  const stripe = getStripe();
  if (!stripe) {
    throw new GatewayError('PAYMENTS_NOT_CONFIGURED', 'Payments aren’t set up yet. Try again later.', {
      status: 503,
    });
  }
  return stripe;
}

module.exports = { getStripe, requireStripe };
