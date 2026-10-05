<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getSettings, updateSettings } from '../api/chat'

const router = useRouter()
const loading = ref(true)
const saving = ref(false)
const message = ref('')
const error = ref('')
const form = ref({ font_size: 'medium', enter_to_send: true, show_timestamps: true, system_prompt: '', temperature: '' })

const MAX_PROMPT = 4000

async function save() {
  saving.value = true
  message.value = ''
  error.value = ''
  try {
    const temperature = form.value.temperature === '' || form.value.temperature === null ? null : Number(form.value.temperature)
    const saved = await updateSettings({
      font_size: form.value.font_size,
      enter_to_send: form.value.enter_to_send,
      show_timestamps: form.value.show_timestamps,
      system_prompt: form.value.system_prompt.trim() || null,
      temperature,
    })
    fill(saved)
    message.value = 'Saved.'
  } catch (err) {
    error.value = err.message
  } finally {
    saving.value = false
  }
}

function fill(s) {
  form.value = {
    font_size: s.font_size || 'medium',
    enter_to_send: s.enter_to_send !== false,
    show_timestamps: s.show_timestamps !== false,
    system_prompt: s.system_prompt || '',
    temperature: s.temperature === null || s.temperature === undefined ? '' : Number(s.temperature),
  }
}

onMounted(async () => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  const s = await getSettings()
  if (s) fill(s)
  else error.value = 'Couldn’t load your settings.'
  loading.value = false
})
</script>

<template>
  <div class="page">
    <router-link to="/chat" class="back-link">← Back to chat</router-link>
    <h1>Settings</h1>

    <p v-if="loading" class="muted">Loading…</p>
    <form v-else class="card" @submit.prevent="save">
      <section>
        <h2>Chat</h2>
        <label class="row">
          <span>
            <span class="label">Text size</span>
            <span class="hint">For messages in the chat.</span>
          </span>
          <select v-model="form.font_size">
            <option value="small">Small</option>
            <option value="medium">Medium</option>
            <option value="large">Large</option>
          </select>
        </label>
        <label class="row">
          <span>
            <span class="label">Enter sends the message</span>
            <span class="hint">Off: Enter adds a new line and you send with the button.</span>
          </span>
          <input v-model="form.enter_to_send" type="checkbox" class="toggle" />
        </label>
        <label class="row">
          <span>
            <span class="label">Show times on messages</span>
          </span>
          <input v-model="form.show_timestamps" type="checkbox" class="toggle" />
        </label>
      </section>

      <section>
        <h2>Model behaviour</h2>
        <label class="stack">
          <span class="label">Custom instructions</span>
          <span class="hint">Sent to the model at the start of every chat, e.g. “Answer briefly” or “I’m a Python developer”.</span>
          <textarea v-model="form.system_prompt" rows="5" :maxlength="MAX_PROMPT" placeholder="None" />
          <span class="hint right">{{ form.system_prompt.length }} / {{ MAX_PROMPT }}</span>
        </label>
        <label class="row">
          <span>
            <span class="label">Temperature</span>
            <span class="hint">
              Lower is more focused, higher more varied (0–2). Leave empty for each model’s default. Reasoning models (such
              as GPT-5 and later) only accept their default, so set this only if you use other models.
            </span>
          </span>
          <input v-model="form.temperature" type="number" min="0" max="2" step="0.1" placeholder="Default" class="number" />
        </label>
      </section>

      <div class="actions">
        <button type="submit" class="btn" :disabled="saving">{{ saving ? 'Saving…' : 'Save settings' }}</button>
        <span v-if="message" class="ok" role="status">{{ message }}</span>
        <span v-if="error" class="err" role="alert">{{ error }}</span>
      </div>
    </form>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; padding: 2.5rem 1rem 4rem; max-width: 44rem; margin: 0 auto; }
.back-link { display: inline-block; color: #94a3b8; text-decoration: none; font-size: 0.9375rem; margin-bottom: 1.5rem; }
.back-link:hover { color: #f1f5f9; }
h1 { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; margin-bottom: 1.5rem; }
h2 { font-size: 0.8125rem; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin-bottom: 0.75rem; font-weight: 600; }
.muted { color: #94a3b8; }
.card { padding: 1.5rem; background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 16px; }
section { margin-bottom: 1.75rem; }
.row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1.5rem;
  padding: 0.75rem 0;
  border-top: 1px solid rgba(148, 163, 184, 0.08);
}
.row:first-of-type { border-top: none; }
.stack { display: flex; flex-direction: column; gap: 0.375rem; padding: 0.75rem 0; }
.label { display: block; color: #e2e8f0; font-size: 0.9375rem; }
.hint { display: block; color: #94a3b8; font-size: 0.8125rem; line-height: 1.45; margin-top: 0.125rem; }
.right { text-align: right; }
select, textarea, .number {
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.25);
  border-radius: 8px;
  color: #f1f5f9;
  font: inherit;
  font-size: 0.9375rem;
  padding: 0.5rem 0.625rem;
}
textarea { resize: vertical; min-height: 6rem; line-height: 1.5; }
.number { width: 6.5rem; flex-shrink: 0; }
.toggle { width: 1.125rem; height: 1.125rem; accent-color: #6366f1; flex-shrink: 0; }
.actions { display: flex; align-items: center; gap: 1rem; flex-wrap: wrap; }
.btn {
  padding: 0.625rem 1.25rem;
  border-radius: 10px;
  border: none;
  background: #6366f1;
  color: white;
  font: inherit;
  font-weight: 500;
  cursor: pointer;
}
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.ok { color: #86efac; font-size: 0.9375rem; }
.err { color: #fca5a5; font-size: 0.9375rem; }
@media (max-width: 560px) {
  .row { flex-direction: column; align-items: flex-start; gap: 0.5rem; }
}
</style>
