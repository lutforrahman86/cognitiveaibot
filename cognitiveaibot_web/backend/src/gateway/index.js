/**
 * The AI gateway: the one path every model call takes, whichever client made
 * it. The web, mobile and desktop apps reach it through the chat endpoints;
 * the paid developer API will reach it through /v1 the same way, so both
 * always offer the same models and are metered the same way.
 */
const UsageRecord = require('../models/UsageRecord');
const { getProvider, AGGREGATOR } = require('./providers');
const openaiCompatible = require('./openaiCompatible');
const anthropic = require('./anthropic');
const metering = require('./metering');
const { GatewayError } = require('./errors');

const ADAPTERS = { openai: openaiCompatible, anthropic };

const MAX_OUTPUT_TOKENS = parseInt(process.env.GATEWAY_MAX_OUTPUT_TOKENS, 10) || 8192;
// What one credit is worth in US dollars, for the usage dashboard's cost
// figures. A placeholder until pricing is decided (ROADMAP Decision 4).
const CREDIT_USD_VALUE = Number(process.env.CREDIT_USD_VALUE) || 0.01;

/**
 * The route a call to this model would take right now, preferring direct to
 * the model's maker over the aggregator. Null when no route has a key.
 */
function routeFor(model) {
  if (model.provider_model_id) {
    const direct = getProvider(model.provider);
    if (direct?.apiKey) return { provider: direct, upstreamModel: model.provider_model_id };
  }
  if (model.aggregator_model_id) {
    const aggregator = getProvider(AGGREGATOR);
    if (aggregator?.apiKey) return { provider: aggregator, upstreamModel: model.aggregator_model_id };
  }
  return null;
}

/**
 * Whether a model can be called right now, and if not, why.
 * Reasons: inactive · not_priced · not_connected (no route id) ·
 * provider_not_configured (routes exist but no key is set).
 */
function availability(model) {
  if (!model || model.is_active === false) return { available: false, reason: 'inactive' };
  if (model.input_credits_per_mtok == null || model.output_credits_per_mtok == null) {
    return { available: false, reason: 'not_priced' };
  }
  if (!model.provider_model_id && !model.aggregator_model_id) {
    return { available: false, reason: 'not_connected' };
  }
  const route = routeFor(model);
  if (!route) return { available: false, reason: 'provider_not_configured' };
  return { available: true, route };
}

/** Resolves a model to its route and output cap, or refuses with a clear error. */
function prepare(model) {
  const result = availability(model);
  if (!result.available) {
    throw new GatewayError('MODEL_UNAVAILABLE', `${model?.name || 'This model'} isn’t available yet.`, {
      status: 400,
    });
  }
  return {
    route: result.route,
    maxOutputTokens: Math.min(MAX_OUTPUT_TOKENS, model.max_output_tokens || MAX_OUTPUT_TOKENS),
  };
}

function openStream({ route, messages, maxTokens, signal }) {
  return ADAPTERS[route.provider.adapter].openChatStream({
    provider: route.provider,
    model: route.upstreamModel,
    messages,
    maxTokens,
    signal,
  });
}

/** Adds a settled call to the user's daily usage rollup (the user dashboard). */
async function recordUsage({ userId, modelId, inputTokens = 0, outputTokens = 0, chargedCredits = 0 }) {
  if (!inputTokens && !outputTokens) return;
  const today = new Date().toISOString().slice(0, 10);
  await UsageRecord.upsert(userId, modelId, today, {
    tokens_input: inputTokens,
    tokens_output: outputTokens,
    cost: Number((chargedCredits * CREDIT_USD_VALUE).toFixed(4)),
  });
}

module.exports = {
  availability,
  prepare,
  openStream,
  recordUsage,
  metering,
  GatewayError,
  CREDIT_USD_VALUE,
};
