/**
 * What every /v1 endpoint shares: OpenAI-shaped errors, and admission (the
 * checks a call passes before any credit is held or provider called).
 */
const AIModel = require('../models/AIModel');
const gateway = require('../gateway');
const rateLimit = require('../gateway/rateLimit');
const { requireTier } = require('../billing/service');
const keys = require('./keys');
const { checkPrompt } = require('../gateway/moderation');
const { raiseAlert } = require('../admin/alerts');

const ERROR_TYPES = {
  400: 'invalid_request_error',
  401: 'invalid_request_error',
  402: 'insufficient_quota',
  403: 'permission_error',
  404: 'invalid_request_error',
  409: 'invalid_request_error',
  413: 'invalid_request_error',
  429: 'rate_limit_error',
};

class ApiError extends Error {
  constructor(status, code, message, param = null) {
    super(message);
    Object.assign(this, { status, code, param });
  }
}

function errorBody(status, code, message, param = null) {
  return { error: { message, type: ERROR_TYPES[status] || 'api_error', param, code } };
}

function sendError(res, err) {
  if (err instanceof ApiError) return res.status(err.status).json(errorBody(err.status, err.code, err.message, err.param));
  if (err instanceof gateway.GatewayError) {
    return res.status(err.status).json(errorBody(err.status, err.code.toLowerCase(), err.message));
  }
  console.error('v1:', err);
  return res.status(500).json(errorBody(500, 'internal_error', 'Something went wrong on our side. Try again.'));
}

const invalid = (param, message, code = 'invalid_request') => new ApiError(400, code, message, param);

function setRateLimitHeaders(res, limit) {
  res.set({
    'x-ratelimit-limit-requests': String(limit.limitRequests),
    'x-ratelimit-limit-tokens': String(limit.limitTokens),
    'x-ratelimit-reset-requests': `${Math.ceil(limit.resetMs / 1000)}s`,
    'x-ratelimit-reset-tokens': `${Math.ceil(limit.resetMs / 1000)}s`,
  });
  if (limit.remainingRequests != null) res.set('x-ratelimit-remaining-requests', String(limit.remainingRequests));
  if (limit.remainingTokens != null) res.set('x-ratelimit-remaining-tokens', String(limit.remainingTokens));
}

const ENDPOINTS = {
  chat: 'POST /v1/chat/completions',
  embedding: 'POST /v1/embeddings',
  image: 'POST /v1/images/generations',
  speech: 'POST /v1/audio/speech',
  transcription: 'POST /v1/audio/transcriptions',
  video: 'POST /v1/videos',
};

/** The model named in a request, if it exists and can be called now. */
async function callableModel(slug) {
  if (typeof slug !== 'string' || !slug) return null;
  const model = await AIModel.findBySlug(slug);
  return model && gateway.availability(model).available ? model : null;
}

/**
 * Everything a call must pass before credits are held: a callable model of
 * the endpoint's kind, a plan with API access that unlocks the model's tier,
 * and the plan's rate limit (whose headers are set on `res`).
 */
async function admit(req, res, modelName, kind) {
  if (typeof modelName !== 'string' || !modelName) throw invalid('model', 'Set `model` to a model id from GET /v1/models.');
  const model = await callableModel(modelName);
  if (!model) throw new ApiError(404, 'model_not_found', `The model "${modelName}" does not exist or isn’t available.`, 'model');
  const modelKind = model.api_kind || 'chat';
  if (modelKind !== kind) {
    throw invalid('model', `"${modelName}" is a ${modelKind} model: use ${ENDPOINTS[modelKind]}.`, 'wrong_model_type');
  }
  const prepared = gateway.prepare(model);

  const userId = req.apiKey.user_id;
  const access = await keys.apiAccess(userId);
  if (!access) throw keys.requireAccessError();
  requireTier(model, access.plan.model_tier || 0);

  const limit = await rateLimit.checkRequest(userId, access.limits);
  setRateLimitHeaders(res, limit);
  if (!limit.allowed) {
    const wait = Math.ceil(limit.resetMs / 1000);
    res.set('retry-after', String(wait));
    throw new ApiError(
      429,
      'rate_limit_exceeded',
      limit.reason === 'tokens'
        ? `Your plan allows ${access.limits.tokensPerMinute} tokens per minute. Try again in ${wait}s.`
        : `Your plan allows ${access.limits.requestsPerMinute} requests per minute. Try again in ${wait}s.`
    );
  }
  return { model, prepared, access, userId };
}

/** Moderates a prompt sent through the API (see gateway/moderation.js). */
function moderate(req, text, policy) {
  const userId = req.apiKey.user_id;
  return checkPrompt(text, policy, {
    onSerious: (categories) =>
      raiseAlert('moderation_minors', userId, { source: `api ${policy}`, categories }, `minors:${userId}:${Date.now()}`),
  });
}

module.exports = { moderate, ApiError, errorBody, sendError, invalid, setRateLimitHeaders, callableModel, admit, ENDPOINTS };
