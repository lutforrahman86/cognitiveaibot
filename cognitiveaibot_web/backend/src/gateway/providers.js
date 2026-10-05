/**
 * Providers the gateway can call.
 *
 * A model can have two routes: direct to its maker (keyed by the `provider`
 * column, using provider_model_id) and through the aggregator (OpenRouter,
 * using aggregator_model_id). The gateway prefers direct when that key is set.
 *
 * `adapter` picks the wire format: 'openai' for OpenAI-compatible Chat
 * Completions APIs (openaiCompatible.js), 'anthropic' for Anthropic's
 * Messages API (anthropic.js).
 *
 * Keys are read from the environment and must never be sent to a client.
 */
const PROVIDERS = {
  OpenAI: {
    adapter: 'openai',
    defaultBaseUrl: 'https://api.openai.com/v1',
    baseUrlEnv: 'OPENAI_BASE_URL',
    apiKeyEnv: ['OPENAI_API_KEY'],
    // Newer OpenAI models reject `max_tokens`.
    maxTokensParam: 'max_completion_tokens',
    streamUsage: true,
  },
  Anthropic: {
    adapter: 'anthropic',
    defaultBaseUrl: 'https://api.anthropic.com',
    baseUrlEnv: 'ANTHROPIC_BASE_URL',
    apiKeyEnv: ['ANTHROPIC_API_KEY'],
  },
  Google: {
    adapter: 'openai',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    baseUrlEnv: 'GEMINI_BASE_URL',
    apiKeyEnv: ['GEMINI_API_KEY', 'GOOGLE_AI_API_KEY'],
    maxTokensParam: 'max_tokens',
    streamUsage: false,
  },
  // The aggregator: one key reaches every model in the catalog.
  OpenRouter: {
    adapter: 'openai',
    defaultBaseUrl: 'https://openrouter.ai/api/v1',
    baseUrlEnv: 'OPENROUTER_BASE_URL',
    apiKeyEnv: ['OPENROUTER_API_KEY'],
    maxTokensParam: 'max_tokens',
    streamUsage: true,
  },
};

const AGGREGATOR = 'OpenRouter';

function getProvider(name) {
  const spec = PROVIDERS[name];
  if (!spec) return null;
  const apiKey = spec.apiKeyEnv.map((k) => process.env[k]).find(Boolean) || null;
  return {
    name,
    adapter: spec.adapter,
    baseUrl: (process.env[spec.baseUrlEnv] || spec.defaultBaseUrl).replace(/\/+$/, ''),
    apiKey,
    maxTokensParam: spec.maxTokensParam,
    streamUsage: spec.streamUsage,
  };
}

module.exports = { getProvider, AGGREGATOR, PROVIDER_NAMES: Object.keys(PROVIDERS) };
