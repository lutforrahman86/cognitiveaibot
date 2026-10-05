/**
 * An error the gateway can explain to a client: `status` is the HTTP status to
 * answer with and `code` is a stable identifier clients can branch on.
 * `message` is safe to show to an end user — provider responses and keys are
 * never passed through verbatim.
 */
class GatewayError extends Error {
  constructor(code, message, { status = 502, cause } = {}) {
    super(message, cause ? { cause } : undefined);
    this.name = 'GatewayError';
    this.code = code;
    this.status = status;
  }
}

function fromUpstreamStatus(status) {
  if (status === 401 || status === 403) {
    return new GatewayError('PROVIDER_AUTH_FAILED', 'The AI provider rejected the server’s API key.');
  }
  if (status === 404) {
    return new GatewayError('PROVIDER_MODEL_NOT_FOUND', 'The AI provider does not offer this model.');
  }
  // 529 is Anthropic's "overloaded": as retryable as a rate limit.
  if (status === 429 || status === 529) {
    return new GatewayError(
      'PROVIDER_RATE_LIMITED',
      'The AI provider is busy or out of quota. Try again shortly.',
      { status: 503 }
    );
  }
  if (status >= 400 && status < 500) {
    return new GatewayError('PROVIDER_REJECTED_REQUEST', 'The AI provider could not process this request.');
  }
  return new GatewayError('PROVIDER_ERROR', 'The AI provider had an error. Try again shortly.');
}

module.exports = { GatewayError, fromUpstreamStatus };
