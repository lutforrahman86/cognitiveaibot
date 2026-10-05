<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getBilling, getUsageSummary } from '../api/chat'

const router = useRouter()
const loading = ref(true)
const error = ref('')
const days = ref(30)
const usage = ref(null)
const billing = ref(null)

const KINDS = { chat: 'Chat', embedding: 'Embeddings', image: 'Images', speech: 'Speech', transcription: 'Transcription', video: 'Video' }
const formatNumber = (n) => Number(n || 0).toLocaleString('en-US')
const formatCredits = (n) => {
  const v = Number(n || 0)
  // Tiny charges (an embedding is a few millionths of a credit) aren't zero.
  return v > 0 && v < 0.0001 ? '< 0.0001' : v.toLocaleString('en-US', { maximumFractionDigits: 4 })
}
const formatDate = (d) => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
const maxDay = computed(() => Math.max(0, ...(usage.value?.by_day || []).map((d) => d.credits)))

async function load() {
  error.value = ''
  try {
    const [u, b] = await Promise.all([getUsageSummary(days.value), getBilling()])
    usage.value = u
    billing.value = b
  } catch (err) {
    error.value = err.message
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  load()
})
</script>

<template>
  <div class="page">
    <router-link to="/chat" class="back-link">← Back to chat</router-link>
    <header class="head">
      <h1>Usage</h1>
      <label class="range">
        <span class="sr-only">Period</span>
        <select v-model.number="days" @change="load">
          <option :value="7">Last 7 days</option>
          <option :value="30">Last 30 days</option>
          <option :value="90">Last 90 days</option>
        </select>
      </label>
    </header>

    <p v-if="loading" class="muted">Loading…</p>
    <p v-else-if="error" class="err" role="alert">{{ error }}</p>
    <template v-else>
      <section class="card stats">
        <div>
          <div class="label">Available credits</div>
          <div class="value">{{ formatCredits(billing?.credits.available) }}</div>
          <div v-if="billing?.credits.expiring" class="hint">
            {{ formatCredits(billing.credits.expiring.credits) }} plan credits expire {{ formatDate(billing.credits.expiring.at) }}
          </div>
          <router-link to="/upgrade" class="link">Buy credits</router-link>
        </div>
        <div>
          <div class="label">Credits used</div>
          <div class="value">{{ formatCredits(usage.totals.credits) }}</div>
        </div>
        <div>
          <div class="label">Requests</div>
          <div class="value">{{ formatNumber(usage.totals.requests) }}</div>
          <div v-if="usage.totals.api_requests" class="hint">{{ formatNumber(usage.totals.api_requests) }} through the API</div>
        </div>
        <div>
          <div class="label">Tokens in / out</div>
          <div class="value small">{{ formatNumber(usage.totals.input_tokens) }} / {{ formatNumber(usage.totals.output_tokens) }}</div>
        </div>
      </section>

      <p v-if="!usage.totals.requests" class="muted">Nothing used in this period yet.</p>
      <template v-else>
        <h2>By day</h2>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Day</th><th class="right">Requests</th><th class="bar-col">Credits</th></tr></thead>
            <tbody>
              <tr v-for="d in usage.by_day" :key="d.day">
                <td>{{ formatDate(d.day) }}</td>
                <td class="right">{{ formatNumber(d.requests) }}</td>
                <td class="bar-col">
                  <span class="bar" :style="{ width: maxDay ? `${(d.credits / maxDay) * 100}%` : '0' }" />
                  <span class="bar-value">{{ formatCredits(d.credits) }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <h2>By model</h2>
        <div class="table-wrap">
          <table>
            <thead><tr><th>Model</th><th>Type</th><th class="right">Requests</th><th class="right">Credits</th></tr></thead>
            <tbody>
              <tr v-for="m in usage.by_model" :key="m.model">
                <td>{{ m.name || 'Removed model' }} <span class="muted small-text">{{ m.provider }}</span></td>
                <td>{{ KINDS[m.api_kind] || m.api_kind }}</td>
                <td class="right">{{ formatNumber(m.requests) }}</td>
                <td class="right">{{ formatCredits(m.credits) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </template>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; padding: 2.5rem 1rem 4rem; max-width: 56rem; margin: 0 auto; }
.back-link { display: inline-block; color: #94a3b8; text-decoration: none; font-size: 0.9375rem; margin-bottom: 1.5rem; }
.back-link:hover { color: #f1f5f9; }
.head { display: flex; justify-content: space-between; align-items: center; gap: 1rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
h1 { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; }
h2 { font-size: 1.0625rem; font-weight: 600; color: #e2e8f0; margin: 2rem 0 0.75rem; }
select {
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.25);
  border-radius: 8px;
  color: #f1f5f9;
  font: inherit;
  padding: 0.45rem 0.6rem;
}
.muted { color: #94a3b8; }
.small-text { font-size: 0.8125rem; margin-left: 0.25rem; }
.err { color: #fca5a5; }
.card { padding: 1.375rem; background: rgba(30, 41, 59, 0.6); border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 14px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr)); gap: 1.25rem; }
.label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin-bottom: 0.25rem; }
.value { font-size: 1.375rem; font-weight: 600; color: #f1f5f9; font-variant-numeric: tabular-nums; }
.value.small { font-size: 1rem; }
.hint { color: #94a3b8; font-size: 0.8125rem; margin-top: 0.25rem; }
.link { display: inline-block; margin-top: 0.375rem; color: #a5b4fc; font-size: 0.875rem; }
.table-wrap { overflow-x: auto; border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 12px; }
table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
th { text-align: left; font-weight: 500; color: #64748b; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.625rem 1rem; }
td { padding: 0.55rem 1rem; border-top: 1px solid rgba(148, 163, 184, 0.08); color: #e2e8f0; white-space: nowrap; }
.right { text-align: right; font-variant-numeric: tabular-nums; }
.bar-col { width: 50%; min-width: 10rem; }
td.bar-col { display: flex; align-items: center; gap: 0.625rem; }
.bar { display: inline-block; height: 0.5rem; border-radius: 4px; background: #6366f1; min-width: 2px; }
.bar-value { font-variant-numeric: tabular-nums; color: #cbd5e1; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
</style>
