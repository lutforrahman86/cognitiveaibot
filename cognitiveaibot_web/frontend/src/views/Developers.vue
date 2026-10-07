<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getBilling } from '../api/chat'
import { getDeveloper, createApiKey, revokeApiKey, getApiUsage } from '../api/developer'
import InvoiceList from '../components/InvoiceList.vue'

const router = useRouter()
const loading = ref(true)
const loadError = ref('')
const dev = ref(null)
const usage = ref(null)
const balance = ref(null)

const newKeyName = ref('')
const creating = ref(false)
const createError = ref('')
// The full key, shown once right after it's created.
const revealed = ref(null)
const copied = ref('')

const activeKeys = computed(() => (dev.value?.keys || []).filter((k) => !k.revoked_at))
const revokedKeys = computed(() => (dev.value?.keys || []).filter((k) => k.revoked_at))

const formatNumber = (n) => Number(n || 0).toLocaleString('en-US')
const formatCredits = (n) => Number(n || 0).toLocaleString('en-US', { maximumFractionDigits: 4 })
const formatDate = (d) =>
  d ? new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : 'Never'

async function load() {
  const [d, u, b] = await Promise.all([getDeveloper(), getApiUsage(30), getBilling()])
  dev.value = d
  usage.value = u
  balance.value = b?.credits?.available ?? null
}

async function createKey() {
  createError.value = ''
  creating.value = true
  try {
    revealed.value = await createApiKey(newKeyName.value)
    newKeyName.value = ''
    await load()
  } catch (err) {
    createError.value = err.message
  } finally {
    creating.value = false
  }
}

async function revoke(key) {
  if (!window.confirm(`Revoke "${key.name}"? Anything using it will stop working at once.`)) return
  try {
    await revokeApiKey(key.id)
    if (revealed.value?.id === key.id) revealed.value = null
    await load()
  } catch (err) {
    window.alert(err.message)
  }
}

async function copy(text, label) {
  try {
    await navigator.clipboard.writeText(text)
    copied.value = label
    setTimeout(() => (copied.value = ''), 1500)
  } catch {
    copied.value = ''
  }
}

onMounted(async () => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  try {
    await load()
  } catch (err) {
    loadError.value = err.message
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page">
    <router-link to="/chat" class="back-link">← Back to chat</router-link>
    <header class="page-header">
      <h1>Developer API</h1>
      <p>
        Call every model from your own code with the OpenAI SDK you already use. Usage is paid from the same
        credit balance as the app. We don’t store your prompts or replies.
        <router-link to="/docs/api">Read the docs →</router-link>
      </p>
    </header>

    <p v-if="loading" class="muted">Loading…</p>
    <p v-else-if="loadError" class="notice notice-error" role="alert">{{ loadError }}</p>

    <template v-else>
      <section v-if="!dev.access" class="card card-cta">
        <div>
          <h2>Your plan doesn’t include API access</h2>
          <p class="muted">API access comes with plans marked “API access”. Your existing keys start working again when you subscribe.</p>
        </div>
        <router-link to="/upgrade" class="btn btn-primary">See plans</router-link>
      </section>

      <section v-else class="card stats">
        <div>
          <div class="label">Plan</div>
          <div class="value">{{ dev.access.plan }}</div>
        </div>
        <div>
          <div class="label">Limits</div>
          <div class="value small-value">
            {{ formatNumber(dev.access.requests_per_minute) }} requests/min · {{ formatNumber(dev.access.tokens_per_minute) }} tokens/min
          </div>
        </div>
        <div>
          <div class="label">Available credits</div>
          <div class="value">{{ balance === null ? '—' : formatCredits(balance) }}</div>
        </div>
        <div class="stat-wide">
          <div class="label">Base URL</div>
          <div class="code-line">
            <code>{{ dev.base_url }}</code>
            <button class="btn-small" @click="copy(dev.base_url, 'url')">{{ copied === 'url' ? 'Copied' : 'Copy' }}</button>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>API keys</h2>

        <div v-if="revealed" class="notice notice-ok reveal" role="status">
          <strong>Copy your new key now. You won’t be able to see it again.</strong>
          <div class="code-line">
            <code class="key">{{ revealed.key }}</code>
            <button class="btn-small" @click="copy(revealed.key, 'key')">{{ copied === 'key' ? 'Copied' : 'Copy' }}</button>
          </div>
          <button class="link-btn" @click="revealed = null">I’ve saved it</button>
        </div>

        <form v-if="dev.access" class="create-form" @submit.prevent="createKey">
          <input v-model="newKeyName" placeholder="Key name, e.g. “Production server”" maxlength="100" required />
          <button type="submit" class="btn btn-primary" :disabled="creating">{{ creating ? 'Creating…' : 'Create key' }}</button>
        </form>
        <p v-if="createError" class="notice notice-error" role="alert">{{ createError }}</p>

        <div class="table-wrap">
          <table>
            <thead>
              <tr><th>Name</th><th>Key</th><th>Created</th><th>Last used</th><th></th></tr>
            </thead>
            <tbody>
              <tr v-for="k in activeKeys" :key="k.id">
                <td>{{ k.name }}</td>
                <td><code>{{ k.prefix }}…</code></td>
                <td>{{ formatDate(k.created_at) }}</td>
                <td>{{ formatDate(k.last_used_at) }}</td>
                <td class="right"><button class="btn-small danger" @click="revoke(k)">Revoke</button></td>
              </tr>
              <tr v-for="k in revokedKeys" :key="k.id" class="revoked">
                <td>{{ k.name }}</td>
                <td><code>{{ k.prefix }}…</code></td>
                <td>{{ formatDate(k.created_at) }}</td>
                <td>{{ formatDate(k.last_used_at) }}</td>
                <td class="right muted">Revoked</td>
              </tr>
              <tr v-if="!dev.keys.length">
                <td colspan="5" class="muted empty">No keys yet.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="section">
        <h2>Usage, last {{ usage.days }} days</h2>
        <div class="card stats">
          <div><div class="label">Requests</div><div class="value">{{ formatNumber(usage.totals.requests) }}</div></div>
          <div><div class="label">Input tokens</div><div class="value">{{ formatNumber(usage.totals.input_tokens) }}</div></div>
          <div><div class="label">Output tokens</div><div class="value">{{ formatNumber(usage.totals.output_tokens) }}</div></div>
          <div><div class="label">Credits used</div><div class="value">{{ formatCredits(usage.totals.credits) }}</div></div>
        </div>

        <template v-if="usage.totals.requests">
          <h3>By model</h3>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Model</th><th class="right">Requests</th><th class="right">Tokens in / out</th><th class="right">Credits</th></tr></thead>
              <tbody>
                <tr v-for="m in usage.by_model" :key="m.model">
                  <td>{{ m.name || m.model }} <code class="muted">{{ m.model }}</code></td>
                  <td class="right">{{ formatNumber(m.requests) }}</td>
                  <td class="right">{{ formatNumber(m.input_tokens) }} / {{ formatNumber(m.output_tokens) }}</td>
                  <td class="right">{{ formatCredits(m.credits) }}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h3>By key</h3>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Key</th><th class="right">Requests</th><th class="right">Failed</th><th class="right">Credits</th></tr></thead>
              <tbody>
                <tr v-for="k in usage.by_key" :key="k.id || 'deleted'">
                  <td>{{ k.name || 'Deleted key' }} <code v-if="k.prefix" class="muted">{{ k.prefix }}…</code></td>
                  <td class="right">{{ formatNumber(k.requests) }}</td>
                  <td class="right">{{ formatNumber(k.failed) }}</td>
                  <td class="right">{{ formatCredits(k.credits) }}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h3>By day</h3>
          <div class="table-wrap">
            <table>
              <thead><tr><th>Day</th><th class="right">Requests</th><th class="right">Tokens in / out</th><th class="right">Credits</th></tr></thead>
              <tbody>
                <tr v-for="d in usage.by_day" :key="d.day">
                  <td>{{ d.day }}</td>
                  <td class="right">{{ formatNumber(d.requests) }}</td>
                  <td class="right">{{ formatNumber(d.input_tokens) }} / {{ formatNumber(d.output_tokens) }}</td>
                  <td class="right">{{ formatCredits(d.credits) }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>
        <p v-else class="muted">No API calls yet. The <router-link to="/docs/api">quickstart</router-link> gets you to your first one.</p>
      </section>

      <InvoiceList />
    </template>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; padding: 2.5rem 1rem 4rem; max-width: 64rem; margin: 0 auto; }
.back-link { display: inline-block; color: #94a3b8; text-decoration: none; font-size: 0.9375rem; margin-bottom: 1.5rem; }
.back-link:hover { color: #f1f5f9; }
.page-header { margin-bottom: 1.75rem; }
.page-header h1 { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; margin-bottom: 0.375rem; }
.page-header p, .muted { color: #94a3b8; }
.page-header a { color: #a5b4fc; }
h2 { font-size: 1.0625rem; font-weight: 600; color: #e2e8f0; margin-bottom: 0.875rem; }
h3 { font-size: 0.9375rem; font-weight: 600; color: #cbd5e1; margin: 1.5rem 0 0.625rem; }
.section { margin-bottom: 2.5rem; }
.label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin-bottom: 0.25rem; }

.card {
  padding: 1.375rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 14px;
  margin-bottom: 2rem;
}
.card-cta { display: flex; justify-content: space-between; align-items: center; gap: 1.5rem; flex-wrap: wrap; }
.card-cta h2 { margin-bottom: 0.25rem; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(10rem, 1fr)); gap: 1.25rem; }
.stat-wide { grid-column: 1 / -1; }
.value { font-size: 1.25rem; font-weight: 600; color: #f1f5f9; font-variant-numeric: tabular-nums; }
.small-value { font-size: 0.9375rem; }

.code-line { display: flex; align-items: center; gap: 0.625rem; flex-wrap: wrap; min-width: 0; }
code {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.8125rem;
  color: #e2e8f0;
  background: rgba(15, 23, 42, 0.8);
  padding: 0.2rem 0.45rem;
  border-radius: 6px;
  overflow-wrap: anywhere;
}
code.muted { color: #94a3b8; background: none; padding: 0; margin-left: 0.25rem; }
.key { font-size: 0.875rem; padding: 0.4rem 0.6rem; }

.notice { padding: 0.875rem 1rem; border-radius: 10px; margin-bottom: 1rem; font-size: 0.9375rem; border: 1px solid transparent; }
.notice-ok { background: rgba(34, 197, 94, 0.08); border-color: rgba(34, 197, 94, 0.35); color: #bbf7d0; }
.notice-error { background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.3); color: #fca5a5; }
.reveal { display: flex; flex-direction: column; gap: 0.625rem; align-items: flex-start; }

.create-form { display: flex; gap: 0.75rem; margin-bottom: 1rem; flex-wrap: wrap; }
.create-form input {
  flex: 1;
  min-width: 14rem;
  padding: 0.625rem 0.875rem;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.25);
  border-radius: 10px;
  color: #f1f5f9;
  font: inherit;
}
.btn {
  padding: 0.625rem 1rem;
  border-radius: 10px;
  font: inherit;
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  text-decoration: none;
  white-space: nowrap;
}
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.btn-primary { background: #6366f1; color: white; }
.btn-primary:hover:not(:disabled) { background: #4f46e5; }
.btn-small {
  padding: 0.3rem 0.7rem;
  border-radius: 8px;
  border: 1px solid rgba(148, 163, 184, 0.3);
  background: transparent;
  color: #e2e8f0;
  font: inherit;
  font-size: 0.8125rem;
  cursor: pointer;
}
.btn-small:hover { border-color: #a5b4fc; }
.btn-small.danger:hover { border-color: #f87171; color: #fca5a5; }
.link-btn { background: none; border: none; color: #86efac; font: inherit; font-size: 0.875rem; cursor: pointer; padding: 0; text-decoration: underline; }

.table-wrap { overflow-x: auto; border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 12px; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; font-weight: 500; color: #64748b; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.625rem 1rem; }
td { padding: 0.625rem 1rem; border-top: 1px solid rgba(148, 163, 184, 0.08); color: #e2e8f0; white-space: nowrap; }
.right { text-align: right; }
td.right, th.right { font-variant-numeric: tabular-nums; }
.revoked td { color: #64748b; }
.empty { text-align: center; padding: 1.25rem; }
</style>
