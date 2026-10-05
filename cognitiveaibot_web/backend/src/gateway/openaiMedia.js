/**
 * Non-chat calls to OpenAI's own API (roadmap A1): embeddings, image
 * generation, speech, transcription and video. Like the chat adapters, it
 * maps provider failures to GatewayErrors and never returns provider error
 * bodies to clients (they're logged instead).
 *
 * Every function takes `provider` (from providers.getProvider) and the
 * provider's own model id.
 */
const { GatewayError, fromUpstreamStatus } = require('./errors');

async function call(provider, model, path, { method = 'POST', json, form, signal, raw = false } = {}) {
  let res;
  try {
    res = await fetch(`${provider.baseUrl}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${provider.apiKey}`,
        ...(json ? { 'Content-Type': 'application/json' } : {}),
      },
      body: json ? JSON.stringify(json) : form,
      signal,
    });
  } catch (err) {
    if (signal?.aborted) throw err;
    throw new GatewayError('PROVIDER_UNREACHABLE', 'Could not reach the AI provider.', { cause: err });
  }
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    console.error(`[gateway] ${provider.name} ${model} ${method} ${path} → HTTP ${res.status}: ${detail.slice(0, 500)}`);
    throw fromUpstreamStatus(res.status);
  }
  return raw ? res : res.json();
}

/** Vectors for each input, and the input tokens used. */
async function embed({ provider, model, input, dimensions, signal }) {
  const body = await call(provider, model, '/embeddings', {
    json: { model, input, encoding_format: 'float', ...(dimensions ? { dimensions } : {}) },
    signal,
  });
  return {
    vectors: body.data.sort((a, b) => a.index - b.index).map((d) => d.embedding),
    inputTokens: body.usage?.prompt_tokens ?? body.usage?.total_tokens,
  };
}

/** Base64 images, and the text and image tokens used (as OpenAI reports them). */
async function generateImage({ provider, model, prompt, n, size, quality, signal }) {
  const body = await call(provider, model, '/images/generations', {
    json: { model, prompt, n, size, quality },
    signal,
  });
  return {
    images: body.data.map((d) => d.b64_json),
    inputTokens: body.usage?.input_tokens,
    outputTokens: body.usage?.output_tokens,
  };
}

/** Spoken audio for `input`, as bytes in `format`. */
async function speech({ provider, model, input, voice, format, speed, signal }) {
  const res = await call(provider, model, '/audio/speech', {
    json: { model, input, voice, response_format: format, ...(speed ? { speed } : {}) },
    signal,
    raw: true,
  });
  return { audio: Buffer.from(await res.arrayBuffer()), contentType: res.headers.get('content-type') };
}

/** Text from audio, with the audio's duration in seconds (what it's billed by). */
async function transcribe({ provider, model, file, filename, mimetype, language, prompt, signal }) {
  const form = new FormData();
  form.append('file', new Blob([file], { type: mimetype || 'application/octet-stream' }), filename || 'audio');
  form.append('model', model);
  form.append('response_format', 'verbose_json');
  if (language) form.append('language', language);
  if (prompt) form.append('prompt', prompt);
  const body = await call(provider, model, '/audio/transcriptions', { form, signal });
  return { text: body.text, language: body.language, duration: Number(body.duration), segments: body.segments };
}

/** Starts a video generation; returns the provider's job. */
async function createVideo({ provider, model, prompt, seconds, size }) {
  const form = new FormData();
  form.append('model', model);
  form.append('prompt', prompt);
  form.append('seconds', String(seconds));
  form.append('size', size);
  const body = await call(provider, model, '/videos', { form });
  return { id: body.id, status: body.status, progress: body.progress ?? 0 };
}

/** A video job's state: queued, in_progress, completed or failed. */
async function getVideo({ provider, model, id }) {
  const body = await call(provider, model, `/videos/${encodeURIComponent(id)}`, { method: 'GET' });
  return { status: body.status, progress: body.progress ?? 0, error: body.error || null };
}

/** The finished video, as a fetch Response whose body streams the MP4. */
async function downloadVideo({ provider, model, id }) {
  return call(provider, model, `/videos/${encodeURIComponent(id)}/content`, { method: 'GET', raw: true });
}

module.exports = { embed, generateImage, speech, transcribe, createVideo, getVideo, downloadVideo };
