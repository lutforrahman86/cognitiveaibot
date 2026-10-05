const Anthropic = require('@anthropic-ai/sdk');
const { GatewayError, fromUpstreamStatus } = require('./errors');

/**
 * Starts a streamed reply from Anthropic's Messages API, with the same
 * contract as openaiCompatible.openChatStream: resolves once the provider has
 * accepted the request (so a refusal is still a plain HTTP error), then
 * `events` yields `{ type: 'delta', text }`, and `usage` holds the token
 * counts seen so far — kept even if the stream is stopped part-way.
 *
 * Thinking is left at each model's default (adaptive on current models).
 * Thinking tokens are billed as output tokens and are included in
 * usage.output_tokens; only the visible text is streamed to the user.
 */
async function openChatStream({ provider, model, messages, maxTokens, signal }) {
  const client = new Anthropic({ apiKey: provider.apiKey, baseURL: provider.baseUrl });
  const usage = { inputTokens: undefined, outputTokens: undefined };

  const stream = client.messages.stream({ model, max_tokens: maxTokens, messages }, { signal });
  const iterator = stream[Symbol.asyncIterator]();

  let first;
  try {
    first = await iterator.next();
  } catch (err) {
    throw mapError(err, signal, provider, model);
  }

  async function* events() {
    let step = first;
    try {
      while (!step.done) {
        const event = step.value;
        if (event.type === 'message_start') {
          const u = event.message.usage || {};
          usage.inputTokens =
            (u.input_tokens || 0) + (u.cache_creation_input_tokens || 0) + (u.cache_read_input_tokens || 0);
          usage.outputTokens = u.output_tokens || 0;
        } else if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
          yield { type: 'delta', text: event.delta.text };
        } else if (event.type === 'message_delta') {
          if (event.usage?.output_tokens != null) usage.outputTokens = event.usage.output_tokens;
          if (event.delta?.stop_reason === 'refusal') {
            throw new GatewayError('PROVIDER_REFUSED', 'The model declined to answer this request.');
          }
        }
        step = await iterator.next();
      }
    } catch (err) {
      throw mapError(err, signal, provider, model);
    }
  }

  return {
    events: events(),
    get usage() {
      return usage;
    },
  };
}

function mapError(err, signal, provider, model) {
  if (err instanceof GatewayError) return err;
  if (signal?.aborted || err instanceof Anthropic.APIUserAbortError) return err;
  // APIConnectionError is a subclass of APIError in this SDK: check it first.
  if (err instanceof Anthropic.APIConnectionError) {
    return new GatewayError('PROVIDER_UNREACHABLE', 'Could not reach the AI provider.', { cause: err });
  }
  if (err instanceof Anthropic.APIError) {
    console.error(`[gateway] ${provider.name} ${model} → HTTP ${err.status}: ${String(err.message).slice(0, 500)}`);
    return fromUpstreamStatus(err.status);
  }
  return err;
}

module.exports = { openChatStream };
