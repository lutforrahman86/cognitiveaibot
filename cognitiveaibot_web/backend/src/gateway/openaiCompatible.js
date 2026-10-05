const { GatewayError, fromUpstreamStatus } = require('./errors');

/**
 * Starts a streamed chat completion against an OpenAI-compatible API.
 *
 * Resolves only once the provider has accepted the request, so callers can
 * still answer with a normal HTTP error (and skip saving anything) when the
 * provider refuses — a bad key, an unknown model, exhausted quota.
 *
 * `events` async-iterates `{ type: 'delta', text }`. `usage` holds the token
 * counts once the provider reports them (some only do with stream_options),
 * and keeps them even if the stream is stopped part-way.
 */
async function openChatStream({ provider, model, messages, maxTokens, signal }) {
  const body = { model, messages, stream: true, [provider.maxTokensParam]: maxTokens };
  if (provider.streamUsage) body.stream_options = { include_usage: true };

  let res;
  try {
    res = await fetch(`${provider.baseUrl}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${provider.apiKey}`,
      },
      body: JSON.stringify(body),
      signal,
    });
  } catch (err) {
    if (signal?.aborted) throw err;
    throw new GatewayError('PROVIDER_UNREACHABLE', 'Could not reach the AI provider.', { cause: err });
  }

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    const error = fromUpstreamStatus(res.status);
    // Logged for us, never returned to the client.
    console.error(`[gateway] ${provider.name} ${model} → HTTP ${res.status}: ${detail.slice(0, 500)}`);
    throw error;
  }

  // Take the reader now, before returning. Node's fetch cancels an unread
  // body once its Response is garbage-collected, and callers do other work
  // (saving the user's message) before they start reading; an unlocked body
  // could be cancelled in between, silently losing the whole reply.
  const reader = res.body.getReader();
  const usage = { inputTokens: undefined, outputTokens: undefined };
  return {
    events: readEvents(reader, provider, model, usage),
    get usage() {
      return usage;
    },
  };
}

async function* readEvents(reader, provider, model, usage) {
  const decoder = new TextDecoder();
  let buffer = '';
  let streamEnded = false;

  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) {
        streamEnded = true;
        return;
      }
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split(/\r?\n/);
      buffer = lines.pop();

      for (const line of lines) {
        if (!line.startsWith('data:')) continue;
        const data = line.slice(5).trim();
        if (data === '[DONE]') return;

        let payload;
        try {
          payload = JSON.parse(data);
        } catch {
          continue;
        }

        if (payload.error) {
          console.error(`[gateway] ${provider.name} ${model} stream error: ${JSON.stringify(payload.error).slice(0, 500)}`);
          throw new GatewayError('PROVIDER_ERROR', 'The AI provider stopped with an error.');
        }

        const text = payload.choices?.[0]?.delta?.content;
        if (text) yield { type: 'delta', text };

        if (payload.usage) {
          usage.inputTokens = payload.usage.prompt_tokens ?? 0;
          usage.outputTokens = payload.usage.completion_tokens ?? 0;
        }
      }
    }
  } finally {
    // Left before the body ended ([DONE], an error, or the caller stopped
    // reading): release the connection rather than leave it half-read.
    if (!streamEnded) reader.cancel().catch(() => {});
  }
}

module.exports = { openChatStream };
