const Chat = require('../models/Chat');
const Message = require('../models/Message');
const AIModel = require('../models/AIModel');
const gateway = require('../gateway');

const MAX_MESSAGE_CHARS = 32000;
// Earlier turns sent as context, newest first until either limit is hit.
const HISTORY_MAX_MESSAGES = 40;
const HISTORY_MAX_CHARS = 48000;

// Users with a reply currently streaming. One at a time per user, so a single
// account can't fan out unlimited provider calls. Per-process only: this
// moves to Redis with real rate limiting (roadmap C3).
const activeReplies = new Set();

function buildContext(history, newText) {
  const context = [];
  let chars = newText.length;
  for (let i = history.length - 1; i >= 0 && context.length < HISTORY_MAX_MESSAGES; i--) {
    const m = history[i];
    if (m.role !== 'user' && m.role !== 'assistant') continue;
    if (!m.content) continue;
    chars += m.content.length;
    if (chars > HISTORY_MAX_CHARS) break;
    context.unshift({ role: m.role, content: m.content });
  }
  context.push({ role: 'user', content: newText });
  return context;
}

function titleFrom(text) {
  const line = text.split('\n').find((l) => l.trim()) || text;
  const trimmed = line.trim();
  return trimmed.length > 60 ? `${trimmed.slice(0, 57)}…` : trimmed;
}

function sendError(res, err) {
  if (err instanceof gateway.GatewayError) {
    return res.status(err.status).json({ error: err.message, code: err.code });
  }
  console.error('completion:', err);
  return res.status(500).json({ error: 'Something went wrong. Try again.', code: 'INTERNAL_ERROR' });
}

/**
 * POST /api/chats/:chatId/completions  { content, model_id }
 *
 * Answers with a Server-Sent Events stream of JSON events:
 *   { type: 'start', user_message, chat }       the user's message, now saved
 *   { type: 'delta', text }                     the next piece of the reply
 *   { type: 'done', message, usage, credits }   the saved reply and its charge
 *   { type: 'error', code, error, message }     the provider failed mid-reply
 *
 * Anything that fails before the provider accepts the request — including
 * not having enough credits (402) — is a plain JSON error, nothing is saved
 * and nothing is charged.
 */
async function create(req, res) {
  const userId = req.user.id;
  const { chatId } = req.params;
  const text = typeof req.body?.content === 'string' ? req.body.content.trim() : '';
  const modelId = req.body?.model_id;

  if (!text) return res.status(400).json({ error: 'Message is empty.', code: 'EMPTY_MESSAGE' });
  if (text.length > MAX_MESSAGE_CHARS) {
    return res
      .status(400)
      .json({ error: `Messages are limited to ${MAX_MESSAGE_CHARS} characters.`, code: 'MESSAGE_TOO_LONG' });
  }
  if (!modelId) return res.status(400).json({ error: 'Choose a model.', code: 'MODEL_REQUIRED' });

  let chat;
  let model;
  try {
    [chat, model] = await Promise.all([Chat.findById(chatId, userId), AIModel.findById(modelId)]);
  } catch (err) {
    return sendError(res, err);
  }
  if (!chat) return res.status(404).json({ error: 'Chat not found', code: 'CHAT_NOT_FOUND' });
  if (!model) return res.status(400).json({ error: 'Unknown model.', code: 'MODEL_NOT_FOUND' });

  let prepared;
  try {
    prepared = gateway.prepare(model);
  } catch (err) {
    return sendError(res, err);
  }

  if (activeReplies.has(userId)) {
    return res
      .status(429)
      .json({ error: 'Wait for the current reply to finish.', code: 'REPLY_IN_PROGRESS' });
  }
  activeReplies.add(userId);

  const abort = new AbortController();
  let finished = false;
  res.on('close', () => {
    if (!finished) abort.abort();
  });

  try {
    const history = await Message.findByChatId(chatId, userId);
    const context = buildContext(history, text);

    let meter;
    try {
      meter = await gateway.metering.start({
        userId,
        chatId,
        model,
        route: prepared.route.provider.name,
        upstreamModel: prepared.route.upstreamModel,
        messages: context,
        maxOutputTokens: prepared.maxOutputTokens,
      });
    } catch (err) {
      return sendError(res, err);
    }

    let stream;
    try {
      stream = await gateway.openStream({
        route: prepared.route,
        messages: context,
        maxTokens: meter.maxOutputTokens,
        signal: abort.signal,
      });
    } catch (err) {
      await meter.finish({
        status: abort.signal.aborted ? 'cancelled' : 'failed',
        errorCode: err.code || 'INTERNAL_ERROR',
      });
      if (abort.signal.aborted) return;
      return sendError(res, err);
    }

    const userMessage = await Message.create(chatId, { role: 'user', content: text }, userId);
    const isFirstMessage = history.length === 0 && (!chat.title || chat.title === 'New chat');
    const updatedChat = await Chat.update(chatId, userId, {
      model_id: model.id,
      ...(isFirstMessage ? { title: titleFrom(text) } : {}),
    });

    res.writeHead(200, {
      'Content-Type': 'text/event-stream; charset=utf-8',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    });
    const send = (event) => {
      if (!res.writableEnded) res.write(`data: ${JSON.stringify(event)}\n\n`);
    };
    send({ type: 'start', user_message: userMessage, chat: { id: chatId, title: updatedChat?.title } });

    const startedAt = Date.now();
    let firstTokenMs = null;
    let reply = '';
    let streamError = null;
    try {
      for await (const event of stream.events) {
        if (event.type === 'delta') {
          if (firstTokenMs === null) firstTokenMs = Date.now() - startedAt;
          reply += event.text;
          send(event);
        }
      }
    } catch (err) {
      if (!abort.signal.aborted) streamError = err;
    }

    // Charged for what was actually produced, using the provider's token
    // counts when it reported them.
    const settled = await meter.finish({
      status: streamError ? 'failed' : abort.signal.aborted ? 'cancelled' : 'succeeded',
      errorCode: streamError ? streamError.code || 'INTERNAL_ERROR' : null,
      inputTokens: stream.usage.inputTokens,
      outputTokens: stream.usage.outputTokens,
      replyText: reply,
      firstTokenMs,
    });

    // A stopped or failed reply keeps whatever arrived, so the chat history
    // matches what the user saw.
    let assistantMessage = null;
    if (reply) {
      assistantMessage = await Message.create(
        chatId,
        {
          role: 'assistant',
          content: reply,
          model_id: model.id,
          tokens_input: settled?.inputTokens,
          tokens_output: settled?.outputTokens,
        },
        userId
      );
    }
    await Message.updateExcerptForChat(chatId, userId, reply || text);
    if (settled) {
      await gateway.recordUsage({
        userId,
        modelId: model.id,
        inputTokens: settled.inputTokens,
        outputTokens: settled.outputTokens,
        chargedCredits: settled.charged,
      });
    }

    const usage = settled
      ? { input_tokens: settled.inputTokens, output_tokens: settled.outputTokens, estimated: settled.usageEstimated }
      : null;
    const credits = settled ? { charged: settled.charged, balance: settled.balance } : null;
    if (streamError) {
      const safe = streamError instanceof gateway.GatewayError ? streamError : null;
      if (!safe) console.error('completion stream:', streamError);
      send({
        type: 'error',
        code: safe?.code || 'INTERNAL_ERROR',
        error: safe?.message || 'The reply stopped unexpectedly.',
        message: assistantMessage,
        credits,
      });
    } else if (!abort.signal.aborted) {
      send({ type: 'done', message: assistantMessage, usage, credits });
    }
    finished = true;
    res.end();
  } catch (err) {
    if (!res.headersSent) sendError(res, err);
    else {
      console.error('completion:', err);
      res.end();
    }
  } finally {
    finished = true;
    activeReplies.delete(userId);
  }
}

module.exports = { create, buildContext };
