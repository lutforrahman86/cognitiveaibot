<script setup>
import { ref, computed, onMounted } from 'vue'
import { isAuthenticated } from '../api/auth'
import { getModels } from '../api/chat'
import { getDeveloper } from '../api/developer'

const baseUrl = ref(`${window.location.origin}/v1`)
const models = ref([])
const lang = ref('python')
const copied = ref('')

const firstModel = computed(() => models.value.find((m) => m.slug === 'gpt-4o-mini')?.slug || models.value[0]?.slug || 'gpt-4o-mini')

const samples = computed(() => ({
  python: `from openai import OpenAI

client = OpenAI(
    base_url="${baseUrl.value}",
    api_key="sk-cog-...",  # from the Developer API page
)

reply = client.chat.completions.create(
    model="${firstModel.value}",
    messages=[{"role": "user", "content": "Write a haiku about the sea."}],
)
print(reply.choices[0].message.content)`,
  javascript: `import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "${baseUrl.value}",
  apiKey: process.env.COGNITIVE_API_KEY, // sk-cog-...
});

const reply = await client.chat.completions.create({
  model: "${firstModel.value}",
  messages: [{ role: "user", content: "Write a haiku about the sea." }],
});
console.log(reply.choices[0].message.content);`,
  curl: `curl ${baseUrl.value}/chat/completions \\
  -H "Authorization: Bearer $COGNITIVE_API_KEY" \\
  -H "Content-Type: application/json" \\
  -d '{
    "model": "${firstModel.value}",
    "messages": [{"role": "user", "content": "Write a haiku about the sea."}]
  }'`,
}))

const streamSample = computed(() => `stream = client.chat.completions.create(
    model="${firstModel.value}",
    messages=[{"role": "user", "content": "Tell me a story."}],
    stream=True,
    stream_options={"include_usage": True},  # last chunk carries token usage
)
for chunk in stream:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")`)

const mediaSample = computed(() => `# Embeddings
vectors = client.embeddings.create(model="text-embedding-3-small", input=["first text", "second text"])

# Image generation (returned as base64)
image = client.images.generate(model="gpt-image-1-mini", prompt="A paper boat at dawn", size="1024x1024", quality="low")

# Text to speech
audio = client.audio.speech.create(model="tts-1", voice="alloy", input="Hello there")
audio.write_to_file("hello.mp3")

# Speech to text
with open("hello.mp3", "rb") as f:
    text = client.audio.transcriptions.create(model="whisper-1", file=f)`)

const videoSample = computed(() => `# Videos are generated in the background: start one, then poll it.
curl ${baseUrl.value}/videos \\
  -H "Authorization: Bearer $COGNITIVE_API_KEY" -H "Content-Type: application/json" \\
  -d '{"model": "sora-2", "prompt": "A paper boat drifting down a river", "seconds": 4, "size": "1280x720"}'
# → {"id": "…", "status": "queued", …}

curl ${baseUrl.value}/videos/<id> -H "Authorization: Bearer $COGNITIVE_API_KEY"
# → status: queued → in_progress (with progress) → completed or failed

curl ${baseUrl.value}/videos/<id>/content -H "Authorization: Bearer $COGNITIVE_API_KEY" -o video.mp4`)

const ERRORS = [
  ['400', 'invalid_request, unsupported_parameter', 'The request is malformed or uses a feature not supported yet. `param` names the field.'],
  ['401', 'missing_api_key, invalid_api_key', 'No key, a wrong key, or a revoked key.'],
  ['402', 'insufficient_credits', 'Your balance can’t cover even a short reply. Top up or wait for your plan to renew.'],
  ['403', 'api_access_required', 'Your plan doesn’t include API access (or has lapsed).'],
  ['404', 'model_not_found', 'No such model, or it isn’t available right now. List models with GET /models.'],
  ['429', 'rate_limit_exceeded', 'Over your plan’s requests or tokens per minute. Wait for the retry-after header’s seconds.'],
  ['502 / 503', 'provider_error, provider_rate_limited, …', 'The model’s provider failed or is busy. Safe to retry with backoff.'],
]

async function copy(text, label) {
  try {
    await navigator.clipboard.writeText(text)
    copied.value = label
    setTimeout(() => (copied.value = ''), 1500)
  } catch {
    copied.value = ''
  }
}

const price = (n) => Number(n).toLocaleString('en-US', { maximumFractionDigits: 2 })

onMounted(async () => {
  getModels().then((all) => (models.value = all.filter((m) => m.available))).catch(() => {})
  if (isAuthenticated()) getDeveloper().then((d) => (baseUrl.value = d.base_url)).catch(() => {})
})
</script>

<template>
  <div class="page">
    <router-link :to="isAuthenticated() ? '/developers' : '/'" class="back-link">← Back</router-link>
    <header class="page-header">
      <h1>API documentation</h1>
      <p>
        The CognitiveAI API is compatible with OpenAI’s Chat Completions API. If your code already uses an OpenAI SDK,
        change the base URL and the key, and every model below works.
      </p>
    </header>

    <nav class="toc" aria-label="On this page">
      <a href="#quickstart">Quickstart</a>
      <a href="#streaming">Streaming</a>
      <a href="#media">Images, audio &amp; video</a>
      <a href="#models">Models</a>
      <a href="#billing">Billing</a>
      <a href="#limits">Rate limits</a>
      <a href="#errors">Errors</a>
      <a href="#support">What’s supported</a>
      <a href="#privacy">Privacy</a>
    </nav>

    <section id="quickstart">
      <h2>Quickstart</h2>
      <ol class="steps">
        <li>Subscribe to a plan with API access, then create a key on the <router-link to="/developers">Developer API</router-link> page. Keys start with <code>sk-cog-</code> and are shown once.</li>
        <li>Point your SDK at <code>{{ baseUrl }}</code> and send the key as a Bearer token.</li>
        <li>Use a model id from <a href="#models">the list below</a>.</li>
      </ol>
      <div class="code-block">
        <div class="tabs" role="tablist">
          <button v-for="l in ['python', 'javascript', 'curl']" :key="l" role="tab" :aria-selected="lang === l" :class="{ active: lang === l }" @click="lang = l">
            {{ l === 'javascript' ? 'JavaScript' : l === 'curl' ? 'curl' : 'Python' }}
          </button>
          <button class="copy" @click="copy(samples[lang], 'quick')">{{ copied === 'quick' ? 'Copied' : 'Copy' }}</button>
        </div>
        <pre><code>{{ samples[lang] }}</code></pre>
      </div>
      <p class="muted small">Install the SDK with <code>pip install openai</code> or <code>npm install openai</code>.</p>
    </section>

    <section id="streaming">
      <h2>Streaming</h2>
      <p>Set <code>stream: true</code> to receive the reply as it’s written, in OpenAI’s server-sent events format, ending with <code>data: [DONE]</code>.</p>
      <div class="code-block">
        <div class="tabs"><span class="tab-label">Python</span><button class="copy" @click="copy(streamSample, 'stream')">{{ copied === 'stream' ? 'Copied' : 'Copy' }}</button></div>
        <pre><code>{{ streamSample }}</code></pre>
      </div>
    </section>

    <section id="media">
      <h2>Embeddings, images, audio and video</h2>
      <p>The same SDK covers every kind of model. Each call is charged by what the provider reports: tokens for embeddings and images, characters for speech, seconds of audio for transcription, seconds of video for video.</p>
      <div class="code-block">
        <div class="tabs"><span class="tab-label">Python</span><button class="copy" @click="copy(mediaSample, 'media')">{{ copied === 'media' ? 'Copied' : 'Copy' }}</button></div>
        <pre><code>{{ mediaSample }}</code></pre>
      </div>
      <p>
        Video generation takes minutes, so it runs as a job. Its full price is reserved when you start it and charged only if it
        completes; a failed video costs nothing. Finished videos can be downloaded for 7 days.
      </p>
      <div class="code-block">
        <div class="tabs"><span class="tab-label">curl</span><button class="copy" @click="copy(videoSample, 'video')">{{ copied === 'video' ? 'Copied' : 'Copy' }}</button></div>
        <pre><code>{{ videoSample }}</code></pre>
      </div>
    </section>

    <section id="models">
      <h2>Models</h2>
      <p>
        <code>GET {{ baseUrl }}/models</code> lists the models you can call right now, with prices. Every model is called directly at
        its own provider.
      </p>
      <div class="table-wrap">
        <table>
          <thead>
            <tr><th>Model id</th><th>Provider</th><th class="right">Context</th><th class="right">Input credits / 1M tokens</th><th class="right">Output credits / 1M tokens</th></tr>
          </thead>
          <tbody>
            <tr v-for="m in models" :key="m.slug">
              <td><code>{{ m.slug }}</code></td>
              <td>{{ m.provider }}</td>
              <td class="right">{{ m.context_window ? `${Math.round(m.context_window / 1000)}K` : '—' }}</td>
              <td class="right">{{ price(m.input_credits_per_mtok) }}</td>
              <td class="right">{{ price(m.output_credits_per_mtok) }}</td>
            </tr>
            <tr v-if="!models.length"><td colspan="5" class="muted empty">Loading models…</td></tr>
          </tbody>
        </table>
      </div>
    </section>

    <section id="billing">
      <h2>Billing</h2>
      <ul class="plain">
        <li>API calls use the same credit balance as the app. One credit is worth US$0.01.</li>
        <li>A call costs its input tokens × the model’s input price plus its output tokens × its output price, using the provider’s own token counts. The response’s <code>usage</code> shows them.</li>
        <li>Before a call runs, its worst-case cost is reserved; afterwards only what it used is charged. If your balance can only cover a shorter reply, the reply is shortened (<code>finish_reason: "length"</code>) rather than overspending.</li>
        <li>A request refused before reaching the model costs nothing. A non-streamed reply that fails part-way costs nothing; a streamed one costs what was delivered.</li>
      </ul>
    </section>

    <section id="limits">
      <h2>Rate limits</h2>
      <p>
        Each plan sets requests per minute and tokens per minute, shared by all of an account’s keys. Every response carries
        <code>x-ratelimit-limit-requests</code>, <code>x-ratelimit-remaining-requests</code>, <code>x-ratelimit-reset-requests</code> and the same three for tokens.
        Over a limit, you get <code>429</code> with a <code>retry-after</code> header in seconds; the OpenAI SDKs retry these for you.
      </p>
    </section>

    <section id="errors">
      <h2>Errors</h2>
      <p>Errors use OpenAI’s shape: <code>{"error": {"message", "type", "param", "code"}}</code>.</p>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Status</th><th>code</th><th>Meaning</th></tr></thead>
          <tbody>
            <tr v-for="[status, code, meaning] in ERRORS" :key="status">
              <td>{{ status }}</td>
              <td><code>{{ code }}</code></td>
              <td class="wrap">{{ meaning }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <section id="support">
      <h2>What’s supported</h2>
      <ul class="plain">
        <li>
          <strong>Endpoints:</strong> <code>POST /chat/completions</code>, <code>POST /embeddings</code>, <code>POST /images/generations</code>,
          <code>POST /audio/speech</code>, <code>POST /audio/transcriptions</code>, <code>POST /videos</code>, <code>GET /videos/{id}</code>,
          <code>GET /videos/{id}/content</code>, <code>GET /models</code>, <code>GET /models/{id}</code>. Each endpoint takes models of its own type
          (the <code>type</code> field in <code>GET /models</code>).
        </li>
        <li><strong>Parameters:</strong> <code>model</code>, <code>messages</code> (roles <code>system</code>, <code>developer</code>, <code>user</code>, <code>assistant</code>; text content), <code>max_tokens</code> / <code>max_completion_tokens</code>, <code>temperature</code>, <code>top_p</code>, <code>stop</code>, <code>stream</code>, <code>stream_options.include_usage</code>.</li>
        <li><strong>Not yet:</strong> image and audio input to chat models, tool and function calling, structured output (<code>response_format</code>), <code>n</code> above 1 in chat, and image editing. Requests using them get a clear <code>400</code>.</li>
      </ul>
    </section>

    <section id="privacy">
      <h2>Privacy</h2>
      <p>
        We don’t store what you send to the API or what the models reply. For billing we keep only metadata: the time, model,
        key, token counts and cost. The one exception is a generated video, kept for 7 days so you can download it. Your
        prompts are sent to the model’s own provider to be answered.
      </p>
    </section>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; padding: 2.5rem 1rem 5rem; max-width: 56rem; margin: 0 auto; color: #cbd5e1; line-height: 1.6; }
.back-link { display: inline-block; color: #94a3b8; text-decoration: none; font-size: 0.9375rem; margin-bottom: 1.5rem; }
.back-link:hover { color: #f1f5f9; }
.page-header h1 { font-size: 1.875rem; font-weight: 700; color: #f1f5f9; margin-bottom: 0.5rem; }
.page-header p { color: #94a3b8; max-width: 44rem; }
.toc { display: flex; flex-wrap: wrap; gap: 0.5rem 1.25rem; margin: 1.5rem 0 2.5rem; padding-bottom: 1rem; border-bottom: 1px solid rgba(148, 163, 184, 0.12); }
.toc a { color: #a5b4fc; text-decoration: none; font-size: 0.9375rem; }
.toc a:hover { text-decoration: underline; }
section { margin-bottom: 2.75rem; scroll-margin-top: 1.5rem; }
h2 { font-size: 1.25rem; font-weight: 600; color: #f1f5f9; margin-bottom: 0.75rem; }
p { margin-bottom: 0.75rem; }
a { color: #a5b4fc; }
.muted { color: #94a3b8; }
.small { font-size: 0.875rem; }
code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.8125rem;
  color: #e2e8f0;
  background: rgba(30, 41, 59, 0.8);
  padding: 0.1rem 0.375rem;
  border-radius: 5px;
  overflow-wrap: anywhere;
}
.steps, .plain { padding-left: 1.25rem; margin-bottom: 1rem; display: flex; flex-direction: column; gap: 0.5rem; }
.code-block { border: 1px solid rgba(148, 163, 184, 0.15); border-radius: 12px; overflow: hidden; margin-bottom: 0.75rem; background: #0b1220; }
.tabs { display: flex; align-items: center; gap: 0.25rem; padding: 0.375rem 0.5rem; border-bottom: 1px solid rgba(148, 163, 184, 0.12); background: rgba(30, 41, 59, 0.5); }
.tabs button {
  background: none;
  border: none;
  color: #94a3b8;
  font: inherit;
  font-size: 0.8125rem;
  padding: 0.3rem 0.65rem;
  border-radius: 6px;
  cursor: pointer;
}
.tabs button.active { background: rgba(99, 102, 241, 0.2); color: #e0e7ff; }
.tabs .copy { margin-left: auto; border: 1px solid rgba(148, 163, 184, 0.25); }
.tab-label { font-size: 0.8125rem; color: #94a3b8; padding: 0.3rem 0.65rem; }
pre { margin: 0; padding: 1rem 1.125rem; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: 0.8125rem; line-height: 1.6; color: #e2e8f0; overflow-wrap: normal; white-space: pre; }
.table-wrap { overflow-x: auto; border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 12px; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; font-weight: 500; color: #64748b; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.625rem 1rem; white-space: nowrap; }
td { padding: 0.5rem 1rem; border-top: 1px solid rgba(148, 163, 184, 0.08); color: #e2e8f0; white-space: nowrap; }
td.wrap { white-space: normal; min-width: 16rem; }
.right { text-align: right; font-variant-numeric: tabular-nums; }
.empty { text-align: center; }
</style>
