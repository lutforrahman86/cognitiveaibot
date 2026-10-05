/**
 * Providers the gateway can call. Every model is called directly at its maker
 * (keyed by the `provider` column, using provider_model_id), with that
 * provider's own key. Aggregators and resellers are never used (ROADMAP
 * Decision 1): a provider is added here only as a direct integration.
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
    // Images, speech, transcription, embeddings and video (openaiMedia.js).
    media: true,
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
};

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
    media: Boolean(spec.media),
  };
}

module.exports = { getProvider, PROVIDER_NAMES: Object.keys(PROVIDERS) };
