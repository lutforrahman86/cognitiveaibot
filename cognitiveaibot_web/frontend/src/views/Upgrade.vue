<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getPlans, getBilling, getCredits, startCheckout, openBillingPortal } from '../api/chat'
import InvoiceList from '../components/InvoiceList.vue'

const route = useRoute()
const router = useRouter()

const plans = ref([])
const billing = ref(null)
const activity = ref([])
const loading = ref(true)
const loadError = ref('')
const actionError = ref('')
const busyPlanId = ref(null)
const portalBusy = ref(false)
// After returning from Stripe: 'waiting' until the webhook's credits land, then 'arrived'.
const checkoutState = ref(route.query.checkout === 'success' ? 'waiting' : route.query.checkout === 'cancelled' ? 'cancelled' : null)
let pollTimer = null

const signedIn = isAuthenticated()
const subscriptions = computed(() => plans.value.filter((p) => p.kind === 'subscription'))
const topups = computed(() => plans.value.filter((p) => p.kind === 'topup'))
const currentPlan = computed(() => billing.value?.plan || null)
const sub = computed(() => billing.value?.subscription || null)
const paymentsEnabled = computed(() => billing.value?.payments_enabled ?? true)
const hasPurchased = computed(() => Boolean(sub.value) || activity.value.some((t) => t.type === 'purchase'))

function formatPrice(plan) {
  const amount = (plan.price_cents / 100).toLocaleString('en-US', {
    style: 'currency',
    currency: plan.currency.toUpperCase(),
    minimumFractionDigits: plan.price_cents % 100 ? 2 : 0,
  })
  return amount
}
const formatCredits = (n) => Number(n).toLocaleString('en-US', { maximumFractionDigits: 2 })
const formatDate = (d) => new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })

const statusLine = computed(() => {
  if (!sub.value) return 'You’re not subscribed. Top-up credits never expire.'
  if (sub.value.payment_failed) return 'Your last payment failed. Update your card in Manage billing to keep your plan.'
  if (!sub.value.current_period_end) return 'Active.'
  return sub.value.cancel_at_period_end
    ? `Ends on ${formatDate(sub.value.current_period_end)}. It won’t renew.`
    : `Renews on ${formatDate(sub.value.current_period_end)}.`
})

async function load() {
  const [planList, billingRes, creditsRes] = await Promise.all([
    getPlans(),
    signedIn ? getBilling() : null,
    signedIn ? getCredits() : null,
  ])
  plans.value = planList
  billing.value = billingRes
  activity.value = creditsRes?.transactions || []
}

// Credits arrive by webhook a moment after Stripe redirects back, so check
// for a new purchase for up to ~30 seconds.
const latestPurchaseId = () => activity.value.find((t) => t.type === 'purchase')?.id || null

function waitForCredits() {
  const before = latestPurchaseId()
  let tries = 0
  pollTimer = setInterval(async () => {
    tries += 1
    await load().catch(() => {})
    const arrived = latestPurchaseId() !== before
    if (arrived || tries >= 15) {
      clearInterval(pollTimer)
      checkoutState.value = arrived ? 'arrived' : 'slow'
    }
  }, 2000)
}

async function choose(plan) {
  if (!signedIn) {
    router.push('/signup')
    return
  }
  actionError.value = ''
  busyPlanId.value = plan.id
  try {
    window.location.assign(await startCheckout(plan.id))
  } catch (err) {
    actionError.value = err.message
    busyPlanId.value = null
  }
}

async function manageBilling() {
  actionError.value = ''
  portalBusy.value = true
  try {
    window.location.assign(await openBillingPortal())
  } catch (err) {
    actionError.value = err.message
    portalBusy.value = false
  }
}

function subscribeLabel(plan) {
  if (currentPlan.value?.id === plan.id) return 'Your plan'
  if (sub.value) return 'Change in Manage billing'
  return signedIn ? 'Subscribe' : 'Sign up to subscribe'
}

onMounted(async () => {
  try {
    await load()
    if (checkoutState.value === 'waiting') waitForCredits()
  } catch (err) {
    loadError.value = err.message
  } finally {
    loading.value = false
  }
  if (route.query.checkout) router.replace({ query: {} })
})
onUnmounted(() => clearInterval(pollTimer))
</script>

<template>
  <div class="page">
    <router-link :to="signedIn ? '/chat' : '/'" class="back-link">← Back</router-link>
    <header class="page-header">
      <h1>Plans & credits</h1>
      <p>
        Every model is paid for in credits. A plan gives you credits each month, used first and reset at
        renewal; top-up credits never expire.
      </p>
    </header>

    <div v-if="checkoutState" class="notice" :class="checkoutState === 'cancelled' ? 'notice-muted' : 'notice-ok'" role="status">
      <template v-if="checkoutState === 'waiting'">Payment received. Adding your credits…</template>
      <template v-else-if="checkoutState === 'arrived'">Payment received. Your credits have been added.</template>
      <template v-else-if="checkoutState === 'slow'">Payment received. Your credits are taking longer than usual; refresh in a minute.</template>
      <template v-else>Checkout cancelled. You weren’t charged.</template>
    </div>
    <div v-if="!loading && !paymentsEnabled" class="notice notice-muted" role="status">
      Payments aren’t set up yet, so plans can’t be bought right now.
    </div>
    <p v-if="actionError" class="notice notice-error" role="alert">{{ actionError }}</p>

    <p v-if="loading" class="muted">Loading plans…</p>
    <p v-else-if="loadError" class="notice notice-error" role="alert">{{ loadError }}</p>

    <template v-else>
      <section v-if="signedIn && billing" class="status-card" :class="{ 'status-warn': sub?.payment_failed }">
        <div>
          <div class="label">Current plan</div>
          <div class="status-plan">{{ currentPlan?.name || 'Free' }}</div>
          <div class="muted small">{{ statusLine }}</div>
        </div>
        <div class="status-right">
          <div class="label">Available credits</div>
          <div class="status-credits">{{ formatCredits(billing.credits.available) }}</div>
          <div v-if="billing.credits.expiring" class="muted small">
            {{ formatCredits(billing.credits.expiring.credits) }} plan credits expire {{ formatDate(billing.credits.expiring.at) }}
          </div>
          <button
            v-if="hasPurchased && paymentsEnabled"
            class="btn btn-secondary"
            :disabled="portalBusy"
            @click="manageBilling"
          >
            {{ portalBusy ? 'Opening…' : 'Manage billing' }}
          </button>
        </div>
      </section>

      <section v-if="subscriptions.length" class="plan-section">
        <h2>Monthly plans</h2>
        <div class="plan-grid">
          <article
            v-for="plan in subscriptions"
            :key="plan.id"
            class="plan-card"
            :class="{ 'plan-current': currentPlan?.id === plan.id }"
          >
            <div class="plan-name">
              {{ plan.name }}
              <span v-if="plan.includes_api" class="badge">API access</span>
            </div>
            <div class="plan-price">
              {{ formatPrice(plan) }}<span class="per">/{{ plan.interval }}</span>
            </div>
            <div class="plan-credits">{{ formatCredits(plan.credits) }} credits every {{ plan.interval }}</div>
            <div v-if="plan.api_limits" class="plan-api muted small">
              API: {{ formatCredits(plan.api_limits.requests_per_minute) }} requests and
              {{ formatCredits(plan.api_limits.tokens_per_minute) }} tokens per minute
            </div>
            <p v-if="plan.description" class="plan-desc">{{ plan.description }}</p>
            <button
              class="btn btn-primary"
              :disabled="!paymentsEnabled || Boolean(sub) || busyPlanId !== null"
              @click="choose(plan)"
            >
              {{ busyPlanId === plan.id ? 'Opening checkout…' : subscribeLabel(plan) }}
            </button>
          </article>
        </div>
      </section>

      <section v-if="topups.length" class="plan-section">
        <h2>Top up</h2>
        <div class="plan-grid">
          <article v-for="plan in topups" :key="plan.id" class="plan-card">
            <div class="plan-name">{{ plan.name }}</div>
            <div class="plan-price">{{ formatPrice(plan) }}</div>
            <div class="plan-credits">{{ formatCredits(plan.credits) }} credits, once</div>
            <p v-if="plan.description" class="plan-desc">{{ plan.description }}</p>
            <button class="btn btn-secondary" :disabled="!paymentsEnabled || busyPlanId !== null" @click="choose(plan)">
              {{ busyPlanId === plan.id ? 'Opening checkout…' : signedIn ? 'Buy' : 'Sign up to buy' }}
            </button>
          </article>
        </div>
      </section>

      <p v-if="!plans.length" class="muted">No plans are available yet.</p>

      <InvoiceList v-if="signedIn" />

      <section v-if="signedIn && activity.length" class="plan-section">
        <h2>Recent credit activity</h2>
        <ul class="activity">
          <li v-for="t in activity.slice(0, 10)" :key="t.id">
            <span class="activity-reason">{{ t.reason || t.type }}</span>
            <span class="activity-date muted small">{{ formatDate(t.created_at) }}</span>
            <span class="activity-amount" :class="t.amount >= 0 ? 'plus' : 'minus'">
              {{ t.amount >= 0 ? '+' : '' }}{{ formatCredits(t.amount) }}
            </span>
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>

<style scoped>
.page {
  min-height: 100vh;
  padding: 2.5rem 1rem 4rem;
  max-width: 64rem;
  margin: 0 auto;
}
.back-link {
  display: inline-block;
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.9375rem;
  margin-bottom: 1.5rem;
}
.back-link:hover { color: #f1f5f9; }
.page-header { margin-bottom: 1.75rem; }
.page-header h1 { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; margin-bottom: 0.375rem; }
.page-header p, .muted { color: #94a3b8; }
.small { font-size: 0.8125rem; }
.label { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.06em; color: #64748b; margin-bottom: 0.25rem; }

.notice {
  padding: 0.75rem 1rem;
  border-radius: 10px;
  margin-bottom: 1rem;
  font-size: 0.9375rem;
  border: 1px solid transparent;
}
.notice-ok { background: rgba(34, 197, 94, 0.1); border-color: rgba(34, 197, 94, 0.3); color: #86efac; }
.notice-muted { background: rgba(148, 163, 184, 0.08); border-color: rgba(148, 163, 184, 0.2); color: #cbd5e1; }
.notice-error { background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.3); color: #fca5a5; }

.status-card {
  display: flex;
  justify-content: space-between;
  gap: 1.5rem;
  flex-wrap: wrap;
  padding: 1.5rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 16px;
  margin-bottom: 2rem;
}
.status-warn { border-color: rgba(245, 158, 11, 0.5); }
.status-plan { font-size: 1.375rem; font-weight: 600; color: #f1f5f9; margin-bottom: 0.25rem; }
.status-right { display: flex; flex-direction: column; align-items: flex-end; gap: 0.25rem; }
.status-credits { font-size: 1.375rem; font-weight: 600; color: #f1f5f9; font-variant-numeric: tabular-nums; margin-bottom: 0.5rem; }

.plan-section { margin-bottom: 2.25rem; }
.plan-section h2 { font-size: 1.0625rem; font-weight: 600; color: #e2e8f0; margin-bottom: 0.875rem; }
.plan-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr)); gap: 1rem; }
.plan-card {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
  padding: 1.375rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 14px;
}
.plan-current { border-color: #6366f1; }
.plan-name { font-weight: 600; color: #f1f5f9; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; }
.badge {
  font-size: 0.6875rem;
  font-weight: 500;
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  background: rgba(99, 102, 241, 0.15);
  color: #a5b4fc;
}
.plan-price { font-size: 1.75rem; font-weight: 700; color: #f1f5f9; font-variant-numeric: tabular-nums; }
.per { font-size: 0.9375rem; font-weight: 400; color: #94a3b8; margin-left: 0.125rem; }
.plan-credits { color: #cbd5e1; font-size: 0.9375rem; }
.plan-desc { color: #94a3b8; font-size: 0.875rem; line-height: 1.45; flex: 1; margin: 0.25rem 0 0.75rem; }

.btn {
  margin-top: auto;
  padding: 0.625rem 1rem;
  border-radius: 10px;
  font: inherit;
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  border: 1px solid transparent;
  transition: background 0.15s, border-color 0.15s;
}
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.btn-primary { background: #6366f1; color: white; }
.btn-primary:hover:not(:disabled) { background: #4f46e5; }
.btn-secondary { background: transparent; color: #e2e8f0; border-color: rgba(148, 163, 184, 0.3); }
.btn-secondary:hover:not(:disabled) { border-color: #a5b4fc; }

.activity { list-style: none; border: 1px solid rgba(148, 163, 184, 0.1); border-radius: 12px; overflow: hidden; }
.activity li {
  display: grid;
  grid-template-columns: 1fr auto auto;
  gap: 1rem;
  align-items: baseline;
  padding: 0.625rem 1rem;
  border-top: 1px solid rgba(148, 163, 184, 0.08);
}
.activity li:first-child { border-top: none; }
.activity-reason { color: #e2e8f0; font-size: 0.9375rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.activity-amount { font-variant-numeric: tabular-nums; font-weight: 500; text-align: right; min-width: 5rem; }
.plus { color: #86efac; }
.minus { color: #cbd5e1; }

@media (max-width: 600px) {
  .status-right { align-items: flex-start; }
  .activity-date { display: none; }
  .activity li { grid-template-columns: 1fr auto; }
}
</style>
