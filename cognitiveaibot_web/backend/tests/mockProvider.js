/**
 * A local stand-in for an OpenAI-compatible provider, speaking the same
 * streaming format. Used by the tests, and by `npm run dev:mock-ai` to work on
 * the chat UI without a provider key or any cost. It never contacts a real
 * provider.
 */
const http = require('http');

// Dev mode: a clearly fake reply, streamed a word at a time.
function echoChunks(text) {
  const reply = `[Mock reply: not a real AI model] You said: "${text.slice(0, 200)}". ` +
    'Set a real provider key in backend/.env and run `npm run dev` to get real answers.';
  return reply.split(/(?<= )/);
}

/**
 * A stand-in for an OpenAI-compatible provider. Set `mock.reply` before a
 * call to choose what it does; every request is recorded in `mock.requests`.
 */
async function startMockProvider({ echo = false } = {}) {
  const mock = {
    requests: [],
    reply: {},
    aborted: 0,
  };
  const server = http.createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const type = req.headers['content-type'] || '';
    const request = { method: req.method, url: req.url, headers: req.headers, body: null, fields: {} };
    if (raw && type.includes('json')) request.body = JSON.parse(raw);
    else if (type.includes('multipart/form-data')) {
      // Text fields of a multipart upload (the file part is kept as its size).
      for (const part of raw.split(/--[^\r\n]+\r\n/)) {
        const m = part.match(/name="([^"]+)"(; filename="([^"]*)")?[^]*?\r\n\r\n([^]*)\r\n$/);
        if (m) request.fields[m[1]] = m[2] ? { filename: m[3], bytes: Buffer.byteLength(m[4]) } : m[4];
      }
    }
    mock.requests.push(request);

    const media = handleMedia(req, res, request, mock);
    if (media) return;

    if (req.method === 'GET' && req.url.endsWith('/models')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ data: (mock.reply.models || []).map((id) => ({ id })) }));
    }

    const lastUser = [...(request.body?.messages || [])].reverse().find((m) => m.role === 'user');
    const {
      status = 200,
      chunks = echo ? echoChunks(lastUser?.content || '') : ['Hello', ' there', '!'],
      usage = { prompt_tokens: 12, completion_tokens: 3 },
      delayMs = echo ? 40 : 0,
      failAfter = null,
    } = mock.reply;

    if (status !== 200) {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ type: 'error', error: { type: 'mock_error', message: 'mock upstream error' } }));
    }

    if (req.url.endsWith('/v1/messages')) {
      return streamAnthropic(res, mock, { chunks, usage, delayMs, failAfter, stopReason: mock.reply.stopReason });
    }

    res.writeHead(200, { 'Content-Type': 'text/event-stream' });
    let closed = false;
    res.on('close', () => {
      if (!res.writableFinished) {
        closed = true;
        mock.aborted += 1;
      }
    });
    const write = (obj) => res.write(`data: ${JSON.stringify(obj)}\n\n`);
    for (let i = 0; i < chunks.length; i++) {
      if (closed) return;
      if (failAfter !== null && i === failAfter) {
        write({ error: { message: 'mock failure mid-stream' } });
        return res.end();
      }
      write({ choices: [{ index: 0, delta: { content: chunks[i] } }] });
      if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
    }
    if (closed) return;
    write({ choices: [{ index: 0, delta: {}, finish_reason: 'stop' }] });
    if (usage) write({ choices: [], usage });
    res.write('data: [DONE]\n\n');
    res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  mock.baseUrl = `http://127.0.0.1:${server.address().port}/v1`;
  mock.close = () => new Promise((r) => server.close(r));
  return mock;
}

/**
 * OpenAI's media endpoints. `mock.videos` maps a video id to its state
 * ({ status, progress }); tests move a video along by editing it.
 */
function handleMedia(req, res, request, mock) {
  const json = (status, body) => {
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
    return true;
  };
  const { status = 200 } = mock.reply;
  const path = req.url.replace(/^\/v1/, '');
  // Moderation: `mock.moderation` lists the categories to flag, or is
  // { status } to fail.
  if (req.method === 'POST' && path === '/moderations') {
    const m = mock.moderation || [];
    if (!Array.isArray(m)) return json(m.status, { error: { message: 'mock moderation failure' } });
    const categories = Object.fromEntries(['sexual', 'sexual/minors', 'violence', 'violence/graphic', 'hate', 'hate/threatening', 'self-harm/instructions', 'illicit/violent'].map((c) => [c, m.includes(c)]));
    return json(200, { id: 'modr-mock', model: request.body.model, results: [{ flagged: m.length > 0, categories }] });
  }
  const isMedia = /^\/(embeddings|images\/generations|audio\/speech|audio\/transcriptions|videos)/.test(path);
  if (!isMedia) return false;
  if (status !== 200) return json(status, { error: { message: 'mock upstream error' } });

  if (req.method === 'POST' && path === '/embeddings') {
    const inputs = [].concat(request.body.input);
    return json(200, {
      object: 'list',
      data: inputs.map((t, index) => ({ object: 'embedding', index, embedding: [0.1, 0.2, 0.3] })),
      usage: { prompt_tokens: mock.reply.embeddingTokens ?? inputs.length * 5, total_tokens: inputs.length * 5 },
    });
  }
  if (req.method === 'POST' && path === '/images/generations') {
    const n = request.body.n || 1;
    return json(200, {
      created: 1,
      data: Array.from({ length: n }, () => ({ b64_json: Buffer.from('fake-png').toString('base64') })),
      usage: mock.reply.imageUsage ?? { input_tokens: 10, output_tokens: 272 * n, total_tokens: 10 + 272 * n },
    });
  }
  if (req.method === 'POST' && path === '/audio/speech') {
    res.writeHead(200, { 'Content-Type': 'audio/mpeg' });
    res.end(Buffer.from('fake-mp3-audio'));
    return true;
  }
  if (req.method === 'POST' && path === '/audio/transcriptions') {
    return json(200, { task: 'transcribe', language: 'english', duration: mock.reply.duration ?? 3.2, text: 'hello world', segments: [] });
  }
  mock.videos = mock.videos || {};
  if (req.method === 'POST' && path === '/videos') {
    const id = `video_mock_${Object.keys(mock.videos).length + 1}`;
    mock.videos[id] = { status: 'queued', progress: 0 };
    return json(200, { id, object: 'video', status: 'queued', progress: 0 });
  }
  const content = path.match(/^\/videos\/([^/]+)\/content$/);
  if (req.method === 'GET' && content) {
    res.writeHead(200, { 'Content-Type': 'video/mp4' });
    res.end(Buffer.from('fake-mp4-video-bytes'));
    return true;
  }
  const one = path.match(/^\/videos\/([^/]+)$/);
  if (req.method === 'GET' && one) {
    const v = mock.videos[one[1]];
    return v ? json(200, { id: one[1], object: 'video', ...v }) : json(404, { error: { message: 'no such video' } });
  }
  return json(404, { error: { message: 'no mock' } });
}

// Anthropic Messages API streaming format: input tokens arrive in
// message_start, output tokens in message_delta.
async function streamAnthropic(res, mock, { chunks, usage, delayMs, failAfter, stopReason = 'end_turn' }) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream' });
  let closed = false;
  res.on('close', () => {
    if (!res.writableFinished) {
      closed = true;
      mock.aborted += 1;
    }
  });
  const send = (event, data) => res.write(`event: ${event}\ndata: ${JSON.stringify({ type: event, ...data })}\n\n`);
  send('message_start', {
    message: {
      id: 'msg_mock', type: 'message', role: 'assistant', model: 'mock', content: [],
      stop_reason: null, stop_sequence: null,
      usage: { input_tokens: usage?.prompt_tokens ?? 0, output_tokens: 1 },
    },
  });
  send('content_block_start', { index: 0, content_block: { type: 'text', text: '' } });
  for (let i = 0; i < chunks.length; i++) {
    if (closed) return;
    if (failAfter !== null && i === failAfter) {
      send('error', { error: { type: 'overloaded_error', message: 'mock failure mid-stream' } });
      return res.end();
    }
    send('content_block_delta', { index: 0, delta: { type: 'text_delta', text: chunks[i] } });
    if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
  }
  if (closed) return;
  send('content_block_stop', { index: 0 });
  send('message_delta', {
    delta: { stop_reason: stopReason, stop_sequence: null },
    usage: { output_tokens: usage?.completion_tokens ?? 0 },
  });
  send('message_stop', {});
  res.end();
}

module.exports = { startMockProvider };
