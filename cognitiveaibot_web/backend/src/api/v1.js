/**
 * The developer API, OpenAI-compatible (roadmap C2): a developer points the
 * OpenAI SDK they already use at {API_URL}/v1 with an "sk-cog-…" key.
 *
 *   GET  /v1/models              models callable right now, by slug
 *   GET  /v1/models/:id
 *   POST /v1/chat/completions    streaming or not, text only for now
 *
 * Every call takes the same gateway path as the apps: plan check, rate limit,
 * credit hold, direct provider call, exact settlement, request log.
 *
 * Nothing a developer sends or receives is stored (Decision 6): no chat or
 * message rows, only the request log's metadata (model, tokens, cost, key).
 *
 * Errors use OpenAI's shape: { error: { message, type, param, code } }.
 */
const express = require('express');
const AIModel = require('../models/AIModel');
const gateway = require('../gateway');
const rateLimit = require('../gateway/rateLimit');
const keys = require('./keys');
const { ApiError, errorBody, sendError, invalid, callableModel, admit, moderate } = require('./v1Common');
const media = require('./v1Media');

// ---------------------------------------------------------------------------

const router = express.Router();
router.use(express.json({ limit: '4mb' }));
router.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') return sendError(res, invalid(null, 'The request body isn’t valid JSON.'));
  if (err.type === 'entity.too.large') return sendError(res, invalid(null, 'The request body is larger than 4 MB.'));
  next(err);
});

/** Resolves the Bearer key to req.apiKey, or answers 401. */
router.use(async (req, res, next) => {
  try {
    const header = req.headers.authorization || '';
    const presented = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
    if (!presented) {
      throw new ApiError(401, 'missing_api_key', 'Send your API key as a Bearer token: "Authorization: Bearer sk-cog-…".');
    }
    req.apiKey = await keys.authenticate(presented);
    if (!req.apiKey) throw new ApiError(401, 'invalid_api_key', 'Incorrect or revoked API key.');
    if (req.apiKey.suspended_at) throw new ApiError(403, 'account_suspended', 'This account is suspended. Contact support.');
    next();
  } catch (err) {
    sendError(res, err);
  }
});

// ---------------------------------------------------------------------------
// Models

const toApiModel = (m) => ({
  id: m.slug,
  object: 'model',
  created: Math.floor(new Date(m.created_at).getTime() / 1000),
  owned_by: m.provider,
  name: m.name,
  type: m.api_kind || 'chat',
  context_window: m.context_window,
  max_output_tokens: m.max_output_tokens,
  pricing:
    m.pricing_unit === 'second'
      ? { credits_per_second: Number(m.unit_credits) }
      : m.pricing_unit === 'character'
        ? { credits_per_million_characters: Number(m.input_credits_per_mtok) }
        : {
            input_credits_per_million_tokens: Number(m.input_credits_per_mtok),
            output_credits_per_million_tokens: Number(m.output_credits_per_mtok),
          },
});

/** The caller's model tier: what their API plan unlocks (0 without one). */
async function tierOf(req) {
  const access = await keys.apiAccess(req.apiKey.user_id);
  return access?.plan.model_tier || 0;
}

router.get('/models', async (req, res) => {
  try {
    const tier = await tierOf(req);
    const models = (await AIModel.findAll()).filter((m) => gateway.availability(m).available && (m.tier || 0) <= tier);
    res.json({ object: 'list', data: models.map(toApiModel) });
  } catch (err) {
    sendError(res, err);
  }
});

router.get('/models/:id', async (req, res) => {
  try {
    const model = await callableModel(req.params.id);
    if (model && (model.tier || 0) > (await tierOf(req))) {
      throw new ApiError(403, 'model_requires_plan', `${model.name} is available on higher plans.`, 'model');
    }
    if (!model) throw new ApiError(404, 'model_not_found', `The model "${req.params.id}" does not exist or isn’t available.`);
    res.json(toApiModel(model));
  } catch (err) {
    sendError(res, err);
  }
});

// ---------------------------------------------------------------------------
// Chat completions

const UNSUPPORTED = {
  tools: 'Tool calling isn’t supported yet.',
  functions: 'Function calling isn’t supported yet.',
  tool_choice: 'Tool calling isn’t supported yet.',
  logprobs: 'Log probabilities aren’t supported.',
  audio: 'Audio output isn’t supported yet.',
};

function normalizeMessages(input) {
  if (!Array.isArray(input) || input.length === 0) throw invalid('messages', '`messages` must be a non-empty array.');
  return input.map((m, i) => {
    const param = `messages[${i}]`;
    if (!m || typeof m !== 'object') throw invalid(param, `${param} must be an object.`);
    if (!['system', 'developer', 'user', 'assistant'].includes(m.role)) {
      throw invalid(`${param}.role`, `${param}.role must be "system", "developer", "user" or "assistant". Tool messages aren’t supported yet.`);
    }
    let { content } = m;
    if (Array.isArray(content)) {
      if (content.some((part) => part?.type !== 'text' || typeof part.text !== 'string')) {
        throw invalid(`${param}.content`, 'Only text content is supported for now; image and audio input are coming.');
      }
      content = content.map((part) => part.text).join('');
    }
    if (typeof content !== 'string') throw invalid(`${param}.content`, `${param}.content must be a string.`);
    // "developer" is OpenAI's newer name for the system role.
    return { role: m.role === 'developer' ? 'system' : m.role, content };
  });
}

function parseOptions(body) {
  for (const [param, message] of Object.entries(UNSUPPORTED)) {
    if (body[param] != null && !(param === 'logprobs' && body[param] === false)) {
      throw invalid(param, message, 'unsupported_parameter');
    }
  }
  if (body.response_format && body.response_format.type !== 'text') {
    throw invalid('response_format', 'Structured output (response_format) isn’t supported yet.', 'unsupported_parameter');
  }
  if (body.n != null && body.n !== 1) throw invalid('n', 'Only n = 1 is supported.', 'unsupported_parameter');

  const options = {};
  const number = (param, min, max) => {
    const v = body[param];
    if (v == null) return;
    if (typeof v !== 'number' || v < min || v > max) throw invalid(param, `${param} must be a number from ${min} to ${max}.`);
    options[param] = v;
  };
  number('temperature', 0, 2);
  number('top_p', 0, 1);
  if (body.stop != null) {
    const stop = [].concat(body.stop);
    if (stop.length > 4 || stop.some((s) => typeof s !== 'string' || !s)) {
      throw invalid('stop', 'stop must be a string or up to 4 strings.');
    }
    options.stop = body.stop;
  }

  const requested = body.max_completion_tokens ?? body.max_tokens;
  if (requested != null && (!Number.isInteger(requested) || requested < 1)) {
    throw invalid(body.max_completion_tokens != null ? 'max_completion_tokens' : 'max_tokens', 'The token limit must be a positive whole number.');
  }
  return { options, maxTokens: requested ?? null };
}

router.post('/chat/completions', async (req, res) => {
  const userId = req.apiKey.user_id;
  const body = req.body || {};
  let meter;
  let stream;
  const abort = new AbortController();
  let responded = false;
  res.on('close', () => {
    if (!responded) abort.abort();
  });

  // --- Everything that can refuse the request, before any provider call.
  let model;
  let messages;
  let prepared;
  let options;
  let maxTokens;
  try {
    messages = normalizeMessages(body.messages);
    ({ options, maxTokens } = parseOptions(body));
    ({ model, prepared } = await admit(req, res, body.model, 'chat'));
    const lastUser = [...messages].reverse().find((m) => m.role === 'user');
    await moderate(req, lastUser?.content, 'chat');

    meter = await gateway.metering.start({
      userId,
      model,
      route: prepared.route.provider.name,
      upstreamModel: prepared.route.upstreamModel,
      messages,
      maxOutputTokens: Math.min(maxTokens ?? prepared.maxOutputTokens, prepared.maxOutputTokens),
      source: 'api',
      apiKeyId: req.apiKey.id,
    });

    const providerCalledAt = Date.now();
    try {
      stream = await gateway.openStream({
        route: prepared.route,
        messages,
        maxTokens: meter.maxOutputTokens,
        signal: abort.signal,
        options,
      });
    } catch (err) {
      await meter.finish({ status: abort.signal.aborted ? 'cancelled' : 'failed', errorCode: err.code || 'INTERNAL_ERROR' });
      throw err;
    }
    meter.providerCalledAt = providerCalledAt;
  } catch (err) {
    responded = true;
    if (abort.signal.aborted) return res.end();
    return sendError(res, err);
  }

  // --- The provider accepted: stream (or collect) the reply, then settle.
  const id = `chatcmpl-${meter.requestId.replace(/-/g, '')}`;
  const created = Math.floor(Date.now() / 1000);
  const streaming = body.stream === true;
  const includeUsage = streaming && body.stream_options?.include_usage === true;
  const chunk = (delta, finishReason = null) => ({
    id,
    object: 'chat.completion.chunk',
    created,
    model: model.slug,
    choices: [{ index: 0, delta, finish_reason: finishReason, logprobs: null }],
  });
  const write = (obj) => {
    if (!res.writableEnded) res.write(`data: ${JSON.stringify(obj)}\n\n`);
  };

  if (streaming) {
    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    write(chunk({ role: 'assistant', content: '' }));
  }

  let reply = '';
  let firstTokenMs = null;
  let streamError = null;
  try {
    for await (const event of stream.events) {
      if (event.type !== 'delta') continue;
      if (firstTokenMs === null) firstTokenMs = Date.now() - meter.providerCalledAt;
      reply += event.text;
      if (streaming) write(chunk({ content: event.text }));
    }
  } catch (err) {
    if (!abort.signal.aborted) streamError = err;
  }

  // A non-streamed reply that fails part-way delivers nothing, so it costs nothing.
  const deliveredNothing = streamError && !streaming;
  let settled;
  try {
    settled = await meter.finish({
      status: streamError ? 'failed' : abort.signal.aborted ? 'cancelled' : 'succeeded',
      errorCode: streamError ? streamError.code || 'INTERNAL_ERROR' : null,
      inputTokens: deliveredNothing ? undefined : stream.usage.inputTokens,
      outputTokens: deliveredNothing ? undefined : stream.usage.outputTokens,
      replyText: deliveredNothing ? '' : reply,
      firstTokenMs,
    });
    if (settled) {
      await gateway.recordUsage({
        userId,
        modelId: model.id,
        inputTokens: settled.inputTokens,
        outputTokens: settled.outputTokens,
        chargedCredits: settled.charged,
      });
      await rateLimit.addTokens(userId, settled.inputTokens + settled.outputTokens);
    }
  } catch (err) {
    console.error('v1 settle:', err);
  }
  responded = true;
  if (abort.signal.aborted) return res.end();

  const usage = settled && {
    prompt_tokens: settled.inputTokens,
    completion_tokens: settled.outputTokens,
    total_tokens: settled.inputTokens + settled.outputTokens,
  };
  const finishReason = stream.stopReason || 'stop';
  const safeError = streamError instanceof gateway.GatewayError ? streamError : null;
  if (streamError && !safeError) console.error('v1 stream:', streamError);

  if (streaming) {
    if (streamError) {
      write(errorBody(502, safeError?.code.toLowerCase() || 'internal_error', safeError?.message || 'The reply stopped unexpectedly.'));
      return res.end();
    }
    write(chunk({}, finishReason));
    if (includeUsage) write({ id, object: 'chat.completion.chunk', created, model: model.slug, choices: [], usage });
    res.write('data: [DONE]\n\n');
    return res.end();
  }

  if (streamError) {
    const status = safeError?.status || 502;
    return res.status(status).json(errorBody(status, safeError?.code.toLowerCase() || 'internal_error', safeError?.message || 'The reply stopped unexpectedly.'));
  }
  res.json({
    id,
    object: 'chat.completion',
    created,
    model: model.slug,
    choices: [{ index: 0, message: { role: 'assistant', content: reply, refusal: null }, finish_reason: finishReason, logprobs: null }],
    usage,
  });
});

router.use(media);

router.use((req, res) => sendError(res, new ApiError(404, 'not_found', `No endpoint ${req.method} /v1${req.path}.`)));

module.exports = router;
