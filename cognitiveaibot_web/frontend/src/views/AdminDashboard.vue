<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated, getMe, clearToken } from '../api/auth'
import {
  getAdminDashboard,
  getAdminUsers,
  getAdminSubscriptions,
  getAdminUsage,
  getAdminModels,
  adjustUserCredits,
  checkModelUpdates,
  getAdminPlans,
  saveAdminPlan,
} from '../api/admin'

const router = useRouter()
const loading = ref(true)
const error = ref('')

const menuItems = [
  { id: 'overview', label: 'Overview', icon: '◉' },
  { id: 'models', label: 'Models', icon: '◇' },
  { id: 'users', label: 'Users', icon: '👤' },
  { id: 'plans', label: 'Plans', icon: '▤' },
  { id: 'subscriptions', label: 'Subscriptions', icon: '◆' },
  { id: 'usage', label: 'Usage', icon: '⎙' },
]

const activeTab = ref('overview')
const activeTabLabel = computed(() => {
  const item = menuItems.find((m) => m.id === activeTab.value)
  return item ? item.label : 'Admin Dashboard'
})

const user = ref(null)
const showUserMenu = ref(false)
const dashboard = ref(null)
const users = ref([])
const usersTotal = ref(0)
const subscriptions = ref([])
const usage = ref(null)
const models = ref([])
const modelsLoading = ref(false)
const modelCheckResult = ref(null)
const modelCheckLoading = ref(false)
const plans = ref([])
// The plan form: null when closed; `id` is null for a new plan.
const planForm = ref(null)
const planFormError = ref('')
const planSaving = ref(false)

function formatDate(ts) {
  if (!ts) return ''
  return new Date(ts).toLocaleDateString(undefined, {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatCurrency(n) {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 2,
  }).format(n || 0)
}

function formatUsd(n) {
  // Per-request costs are fractions of a cent: show enough digits to see them.
  const v = Number(n || 0)
  return v !== 0 && Math.abs(v) < 0.01 ? `$${v.toFixed(5)}` : formatCurrency(v)
}

function formatCredits(n) {
  return Number(n || 0).toLocaleString('en-US', { maximumFractionDigits: 4 })
}

const UNAVAILABLE_REASONS = {
  inactive: 'Inactive',
  not_priced: 'No price set',
  not_connected: 'No route',
  provider_not_configured: 'No API key',
}

async function handleAdjustCredits(u) {
  const amount = window.prompt(`Credits to add for ${u.email} (negative to remove):`, '10')
  if (amount === null) return
  const credits = Number(amount)
  if (!Number.isFinite(credits) || credits === 0) {
    window.alert('Enter a non-zero number.')
    return
  }
  const reason = window.prompt('Reason (kept with the change):', '')
  if (reason === null) return
  try {
    await adjustUserCredits(u.id, credits, reason)
    await loadUsers()
  } catch (err) {
    window.alert(err.message)
  }
}

function formatNumber(n) {
  if (n >= 1e6) return (n / 1e6).toFixed(1) + 'M'
  if (n >= 1e3) return (n / 1e3).toFixed(1) + 'K'
  return String(n ?? 0)
}

function goBack() {
  router.push('/chat')
}

function toggleUserMenu() {
  showUserMenu.value = !showUserMenu.value
}

function closeUserMenu() {
  showUserMenu.value = false
}

function handleClickOutside(e) {
  if (showUserMenu.value && !e.target.closest('.admin-user-menu')) {
    closeUserMenu()
  }
}

function navigateAndClose(path) {
  router.push(path)
  closeUserMenu()
}

function signOut() {
  clearToken()
  router.push('/signin')
}

async function loadDashboard() {
  loading.value = true
  error.value = ''
  try {
    dashboard.value = await getAdminDashboard()
    subscriptions.value = dashboard.value.subscriptions?.recent || []
  } catch (err) {
    error.value = err.message || 'Failed to load dashboard'
    if (err.message?.includes('Admin') || err.message?.includes('403')) {
      router.push('/chat')
    }
  } finally {
    loading.value = false
  }
}

async function loadUsers() {
  try {
    const data = await getAdminUsers({ limit: 50 })
    users.value = data.users || []
    usersTotal.value = data.total || 0
  } catch (err) {
    error.value = err.message || 'Failed to load users'
  }
}

async function loadSubscriptions() {
  try {
    const data = await getAdminSubscriptions({ limit: 100 })
    subscriptions.value = data.subscriptions || []
  } catch (err) {
    error.value = err.message || 'Failed to load subscriptions'
  }
}

async function loadUsage() {
  try {
    usage.value = await getAdminUsage({ days: 30 })
  } catch (err) {
    error.value = err.message || 'Failed to load usage'
  }
}

async function loadModels() {
  modelsLoading.value = true
  modelCheckResult.value = null
  try {
    const data = await getAdminModels()
    models.value = data.models || []
  } catch (err) {
    error.value = err.message || 'Failed to load models'
  } finally {
    modelsLoading.value = false
  }
}

async function handleCheckModelUpdates() {
  modelCheckLoading.value = true
  modelCheckResult.value = null
  error.value = ''
  try {
    const result = await checkModelUpdates()
    modelCheckResult.value = result
  } catch (err) {
    error.value = err.message || 'Failed to check for new models'
  } finally {
    modelCheckLoading.value = false
  }
}

async function loadPlans() {
  try {
    plans.value = await getAdminPlans()
  } catch (err) {
    error.value = err.message || 'Failed to load plans'
  }
}

function formatPlanPrice(p) {
  const amount = new Intl.NumberFormat('en-US', { style: 'currency', currency: p.currency.toUpperCase() }).format(p.price_cents / 100)
  return p.billing_interval ? `${amount}/${p.billing_interval}` : amount
}

function editPlan(p = null) {
  planFormError.value = ''
  planForm.value = p
    ? {
        id: p.id,
        slug: p.slug,
        name: p.name,
        description: p.description || '',
        kind: p.kind,
        interval: p.billing_interval || 'month',
        price: (p.price_cents / 100).toFixed(2),
        credits: p.credits,
        includes_api: p.includes_api,
        active: p.active,
        sort_order: p.sort_order,
      }
    : { id: null, slug: '', name: '', description: '', kind: 'subscription', interval: 'month', price: '', credits: '', includes_api: false, active: true, sort_order: 0 }
}

async function submitPlan() {
  const f = planForm.value
  planFormError.value = ''
  planSaving.value = true
  try {
    await saveAdminPlan(
      {
        slug: f.slug,
        name: f.name,
        description: f.description,
        kind: f.kind,
        interval: f.kind === 'subscription' ? f.interval : null,
        price_cents: Math.round(Number(f.price) * 100),
        credits: Number(f.credits),
        includes_api: f.includes_api,
        active: f.active,
        sort_order: Number(f.sort_order) || 0,
      },
      f.id
    )
    planForm.value = null
    await loadPlans()
  } catch (err) {
    planFormError.value = err.message
  } finally {
    planSaving.value = false
  }
}

function onTabChange(tab) {
  activeTab.value = tab
  if (tab === 'users') loadUsers()
  else if (tab === 'subscriptions') loadSubscriptions()
  else if (tab === 'usage') loadUsage()
  else if (tab === 'models') loadModels()
  else if (tab === 'plans') loadPlans()
}

onMounted(async () => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  user.value = await getMe()
  await loadDashboard()
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<template>
  <div class="admin-layout">
    <aside class="admin-sidebar">
      <div class="sidebar-header">
        <span class="sidebar-logo">◇</span>
        <h2 class="sidebar-title">Admin</h2>
      </div>
      <nav class="sidebar-nav">
        <button
          v-for="t in menuItems"
          :key="t.id"
          class="sidebar-item"
          :class="{ active: activeTab === t.id }"
          @click="onTabChange(t.id)"
        >
          <span class="sidebar-icon">{{ t.icon }}</span>
          <span class="sidebar-label">{{ t.label }}</span>
        </button>
      </nav>
      <div class="sidebar-footer">
        <a href="#" class="sidebar-back" @click.prevent="goBack">
          <span>←</span> Back to app
        </a>
      </div>
    </aside>

    <main class="admin-main">
      <header class="admin-header">
        <h1>{{ activeTabLabel }}</h1>
        <div class="admin-user-menu">
          <button
            class="admin-user-trigger"
            @click="toggleUserMenu"
            aria-label="User menu"
          >
            <img
              v-if="user?.avatar_url"
              :src="user.avatar_url"
              alt=""
              class="admin-user-avatar"
            />
            <div v-else class="admin-user-avatar admin-user-avatar-placeholder">
              {{ (user?.name || user?.email || 'U')[0].toUpperCase() }}
            </div>
            <span class="admin-user-name">{{ user?.name || user?.email || 'User' }}</span>
            <span class="admin-user-chevron">▼</span>
          </button>
          <div v-show="showUserMenu" class="admin-user-dropdown">
            <button class="admin-user-dropdown-item" @click="navigateAndClose('/profile')">
              Profile
            </button>
            <button class="admin-user-dropdown-item" @click="navigateAndClose('/settings')">
              Settings
            </button>
            <div class="admin-user-dropdown-divider"></div>
            <button class="admin-user-dropdown-item admin-user-dropdown-logout" @click="signOut">
              Logout
            </button>
          </div>
        </div>
      </header>

      <div v-if="error" class="error-msg">{{ error }}</div>

      <div v-if="loading" class="admin-loading">Loading...</div>

      <template v-else-if="dashboard">
      <div v-if="activeTab === 'overview'" class="admin-overview">
        <div class="stats-grid">
          <div class="stat-card">
            <span class="stat-value">{{ dashboard.users?.total ?? 0 }}</span>
            <span class="stat-label">Total Users</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ dashboard.subscriptions?.total ?? 0 }}</span>
            <span class="stat-label">Subscriptions</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ formatCurrency(dashboard.usage?.total_cost) }}</span>
            <span class="stat-label">Usage Cost (30d)</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ formatNumber(dashboard.usage?.total_tokens) }}</span>
            <span class="stat-label">Tokens (30d)</span>
          </div>
          <div class="stat-card">
            <span class="stat-value">{{ dashboard.models ?? 0 }}</span>
            <span class="stat-label">Models</span>
          </div>
        </div>

        <div class="section">
          <h2>Models</h2>
          <div class="models-grid">
            <div
              v-for="m in (dashboard.modelsList || [])"
              :key="m.id"
              class="model-chip"
            >
              <span class="model-name">{{ m.name }}</span>
              <span class="model-meta">{{ m.provider }} · {{ m.category || '—' }}</span>
              <span v-if="!m.is_active" class="model-inactive">Inactive</span>
            </div>
          </div>
        </div>

        <div class="section">
          <h2>Recent Subscriptions</h2>
          <div class="table-wrap">
            <table class="admin-table">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Product</th>
                  <th>Status</th>
                  <th>Started</th>
                  <th>Expires</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="s in (dashboard.subscriptions?.recent || [])" :key="s.id">
                  <td>
                    <span class="user-email">{{ s.email }}</span>
                    <span v-if="s.name" class="user-name">{{ s.name }}</span>
                  </td>
                  <td>{{ s.product_id || '—' }}</td>
                  <td><span class="badge" :class="s.status">{{ s.status }}</span></td>
                  <td>{{ formatDate(s.started_at) }}</td>
                  <td>{{ s.expires_at ? formatDate(s.expires_at) : '—' }}</td>
                </tr>
                <tr v-if="!dashboard.subscriptions?.recent?.length">
                  <td colspan="5" class="empty">No subscriptions</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div v-if="activeTab === 'models'" class="admin-section">
        <div class="models-header">
          <h2>Models ({{ models.length }})</h2>
          <button
            class="btn-check-updates"
            :disabled="modelCheckLoading"
            @click="handleCheckModelUpdates"
          >
            {{ modelCheckLoading ? 'Checking...' : 'Check for new models' }}
          </button>
        </div>

        <div v-if="modelCheckResult" class="model-check-result">
          <div v-if="modelCheckResult.totalNew > 0" class="model-check-new">
            <span class="model-check-icon">✓</span>
            <strong>{{ modelCheckResult.totalNew }} new model(s) available</strong> from
            {{ modelCheckResult.checkedProviders.join(', ') }}
            <ul class="model-check-list">
              <li v-for="m in modelCheckResult.newModels" :key="m.slug">
                <span class="model-check-name">{{ m.name }}</span>
                <code>{{ m.slug }}</code>
                <span class="model-check-provider">{{ m.provider }}</span>
              </li>
            </ul>
            <p class="model-check-hint">
              Add these models to your database seed or create them manually to make them available.
            </p>
          </div>
          <div v-else class="model-check-up-to-date">
            <span class="model-check-icon">◇</span>
            All models are up to date. Checked: {{ modelCheckResult.checkedProviders.join(', ') || 'None (add API keys)' }}
          </div>
          <div v-if="modelCheckResult.errors?.length" class="model-check-errors">
            <strong>Notes:</strong>
            <ul>
              <li v-for="e in modelCheckResult.errors" :key="e.provider">{{ e.provider }}: {{ e.message }}</li>
            </ul>
          </div>
        </div>

        <div v-if="modelsLoading" class="admin-loading">Loading models...</div>
        <div v-else class="table-wrap">
          <table class="admin-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Slug</th>
                <th>Provider</th>
                <th>Category</th>
                <th>Credits / 1M tokens (in · out)</th>
                <th>Provider cost / 1M (in · out)</th>
                <th>Callable</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="m in models" :key="m.id">
                <td><span class="model-name">{{ m.name }}</span></td>
                <td><code class="model-slug">{{ m.slug }}</code></td>
                <td>{{ m.provider || '—' }}</td>
                <td>{{ m.category || '—' }}</td>
                <td>
                  <template v-if="m.input_credits_per_mtok != null">
                    {{ formatCredits(m.input_credits_per_mtok) }} · {{ formatCredits(m.output_credits_per_mtok) }}
                  </template>
                  <template v-else>—</template>
                </td>
                <td>
                  <template v-if="m.input_cost_per_mtok != null">
                    {{ formatCurrency(m.input_cost_per_mtok) }} · {{ formatCurrency(m.output_cost_per_mtok) }}
                  </template>
                  <template v-else>—</template>
                </td>
                <td>
                  <span v-if="m.available" class="badge active">Yes</span>
                  <span v-else class="model-unavailable">{{ UNAVAILABLE_REASONS[m.unavailable_reason] || 'No' }}</span>
                </td>
                <td>
                  <span class="badge" :class="m.is_active ? 'active' : 'inactive'">
                    {{ m.is_active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
              </tr>
              <tr v-if="!modelsLoading && !models.length">
                <td colspan="8" class="empty">No models</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="activeTab === 'users'" class="admin-section">
        <h2>Users ({{ usersTotal }})</h2>
        <div class="table-wrap">
          <table class="admin-table">
            <thead>
              <tr>
                <th>Email</th>
                <th>Name</th>
                <th>Type</th>
                <th>Credits</th>
                <th>Joined</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="u in users" :key="u.id">
                <td>{{ u.email }}</td>
                <td>{{ u.name || '—' }}</td>
                <td><span class="badge" :class="u.type">{{ u.type || 'user' }}</span></td>
                <td>
                  {{ formatCredits(u.credits) }}
                  <span v-if="u.credits_held" class="user-name">({{ formatCredits(u.credits_held) }} held)</span>
                </td>
                <td>{{ formatDate(u.created_at) }}</td>
                <td><button class="btn-adjust" @click="handleAdjustCredits(u)">Adjust credits</button></td>
              </tr>
              <tr v-if="!users.length">
                <td colspan="6" class="empty">No users</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="activeTab === 'plans'" class="admin-section">
        <div class="models-header">
          <h2>Plans ({{ plans.length }})</h2>
          <button class="btn-check-updates" @click="editPlan()">New plan</button>
        </div>
        <p class="usage-note">
          What users can buy. A subscription grants its credits every paid period; a top-up grants them once.
          Edits apply to new purchases: running subscriptions keep the price and credits they started with.
        </p>

        <form v-if="planForm" class="plan-form" @submit.prevent="submitPlan">
          <h3>{{ planForm.id ? `Edit ${planForm.name}` : 'New plan' }}</h3>
          <div class="plan-form-grid">
            <label>Name <input v-model="planForm.name" required /></label>
            <label>Slug <input v-model="planForm.slug" required pattern="[a-z0-9][a-z0-9\-]*" placeholder="pro-monthly" /></label>
            <label>Kind
              <select v-model="planForm.kind">
                <option value="subscription">Subscription</option>
                <option value="topup">Top-up</option>
              </select>
            </label>
            <label v-if="planForm.kind === 'subscription'">Billed every
              <select v-model="planForm.interval">
                <option value="month">Month</option>
                <option value="year">Year</option>
              </select>
            </label>
            <label>Price (USD) <input v-model="planForm.price" type="number" min="0.5" step="0.01" required /></label>
            <label>{{ planForm.kind === 'subscription' ? 'Credits per period' : 'Credits' }}
              <input v-model="planForm.credits" type="number" min="1" step="1" required />
            </label>
            <label>Sort order <input v-model="planForm.sort_order" type="number" step="1" /></label>
            <label class="plan-form-wide">Description <input v-model="planForm.description" /></label>
            <label class="plan-form-check"><input v-model="planForm.includes_api" type="checkbox" /> Includes API access</label>
            <label class="plan-form-check"><input v-model="planForm.active" type="checkbox" /> On sale</label>
          </div>
          <p v-if="planFormError" class="plan-form-error" role="alert">{{ planFormError }}</p>
          <div class="plan-form-actions">
            <button type="submit" class="btn-check-updates" :disabled="planSaving">{{ planSaving ? 'Saving…' : 'Save plan' }}</button>
            <button type="button" class="btn-adjust" @click="planForm = null">Cancel</button>
          </div>
        </form>

        <div class="table-wrap">
          <table class="admin-table">
            <thead>
              <tr>
                <th>Plan</th>
                <th>Kind</th>
                <th>Price</th>
                <th>Credits</th>
                <th>API</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="p in plans" :key="p.id">
                <td>
                  <span class="user-email">{{ p.name }}</span>
                  <span class="user-name">{{ p.slug }}</span>
                </td>
                <td>{{ p.kind === 'topup' ? 'Top-up' : 'Subscription' }}</td>
                <td>{{ formatPlanPrice(p) }}</td>
                <td>{{ formatCredits(p.credits) }}</td>
                <td>{{ p.includes_api ? 'Yes' : '—' }}</td>
                <td><span class="badge" :class="p.active ? 'active' : 'inactive'">{{ p.active ? 'On sale' : 'Off sale' }}</span></td>
                <td><button class="btn-adjust" @click="editPlan(p)">Edit</button></td>
              </tr>
              <tr v-if="!plans.length">
                <td colspan="7" class="empty">No plans yet. Create one so users have something to buy.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="activeTab === 'subscriptions'" class="admin-section">
        <h2>Subscriptions</h2>
        <div class="table-wrap">
          <table class="admin-table">
            <thead>
              <tr>
                <th>User</th>
                <th>Product</th>
                <th>Status</th>
                <th>Started</th>
                <th>Expires</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="s in subscriptions" :key="s.id">
                <td>
                  <span class="user-email">{{ s.email }}</span>
                  <span v-if="s.name" class="user-name">{{ s.name }}</span>
                </td>
                <td>{{ s.product_id || '—' }}</td>
                <td><span class="badge" :class="s.status">{{ s.status }}</span></td>
                <td>{{ formatDate(s.started_at) }}</td>
                <td>{{ s.expires_at ? formatDate(s.expires_at) : '—' }}</td>
              </tr>
              <tr v-if="!subscriptions.length">
                <td colspan="5" class="empty">No subscriptions</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div v-if="activeTab === 'usage'" class="admin-section">
        <h2>Usage (30 days)</h2>
        <div v-if="usage" class="usage-stats">
          <div class="usage-summary">
            <div class="usage-item">
              <span class="usage-label">Total Cost</span>
              <span class="usage-value">{{ formatCurrency(usage.totals?.cost) }}</span>
            </div>
            <div class="usage-item">
              <span class="usage-label">Total Tokens</span>
              <span class="usage-value">{{ formatNumber(usage.totals?.tokens) }}</span>
            </div>
          </div>

          <template v-if="usage.margin">
            <h3>Provider cost vs. charged</h3>
            <p class="usage-note">
              From the request log. Charged credits are valued at
              {{ formatCurrency(usage.margin.credit_usd_value) }} each. Unbilled credits are
              cost above what a reply's hold covered.
            </p>
            <div class="usage-summary">
              <div class="usage-item">
                <span class="usage-label">Requests</span>
                <span class="usage-value">{{ usage.margin.requests }}</span>
                <span class="usage-label">
                  {{ usage.margin.succeeded }} ok · {{ usage.margin.failed }} failed · {{ usage.margin.cancelled }} stopped
                </span>
              </div>
              <div class="usage-item">
                <span class="usage-label">Provider cost</span>
                <span class="usage-value">{{ formatUsd(usage.margin.provider_cost_usd) }}</span>
              </div>
              <div class="usage-item">
                <span class="usage-label">Charged</span>
                <span class="usage-value">{{ formatUsd(usage.margin.charged_usd) }}</span>
                <span class="usage-label">{{ formatCredits(usage.margin.charged_credits) }} credits</span>
              </div>
              <div class="usage-item">
                <span class="usage-label">Margin</span>
                <span class="usage-value">{{ formatUsd(usage.margin.margin_usd) }}</span>
              </div>
              <div class="usage-item">
                <span class="usage-label">Unbilled</span>
                <span class="usage-value">{{ formatCredits(usage.margin.unbilled_credits) }}</span>
                <span class="usage-label">credits</span>
              </div>
            </div>
            <div class="table-wrap">
              <table class="admin-table">
                <thead>
                  <tr>
                    <th>Model</th>
                    <th>Route</th>
                    <th>Requests</th>
                    <th>Provider cost</th>
                    <th>Charged</th>
                    <th>Margin</th>
                    <th>Unbilled credits</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="m in usage.margin.by_model" :key="`${m.name}-${m.route}`">
                    <td>{{ m.name || '—' }}</td>
                    <td>{{ m.route }}</td>
                    <td>{{ m.requests }}</td>
                    <td>{{ formatUsd(m.provider_cost_usd) }}</td>
                    <td>{{ formatUsd(m.charged_usd) }}</td>
                    <td>{{ formatUsd(m.margin_usd) }}</td>
                    <td>{{ formatCredits(m.unbilled_credits) }}</td>
                  </tr>
                  <tr v-if="!usage.margin.by_model.length">
                    <td colspan="7" class="empty">No model calls yet</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>

          <h3>By Model</h3>
          <div class="table-wrap">
            <table class="admin-table">
              <thead>
                <tr>
                  <th>Model</th>
                  <th>Provider</th>
                  <th>Cost</th>
                  <th>Tokens</th>
                  <th>Users</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="m in (usage.byModel || [])" :key="m.slug">
                  <td>{{ m.name }}</td>
                  <td>{{ m.provider }}</td>
                  <td>{{ formatCurrency(m.total_cost) }}</td>
                  <td>{{ formatNumber(m.total_tokens) }}</td>
                  <td>{{ m.user_count ?? 0 }}</td>
                </tr>
                <tr v-if="!usage.byModel?.length">
                  <td colspan="5" class="empty">No usage data</td>
                </tr>
              </tbody>
            </table>
          </div>

          <h3>Daily (last 14 days)</h3>
          <div class="table-wrap">
            <table class="admin-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Tokens</th>
                  <th>Cost</th>
                  <th>Active Users</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="d in (usage.daily || []).slice().reverse()" :key="d.record_date">
                  <td>{{ d.record_date }}</td>
                  <td>{{ formatNumber(d.tokens) }}</td>
                  <td>{{ formatCurrency(d.cost) }}</td>
                  <td>{{ d.active_users ?? 0 }}</td>
                </tr>
                <tr v-if="!usage.daily?.length">
                  <td colspan="4" class="empty">No daily data</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </template>
    </main>
  </div>
</template>

<style scoped>
.admin-layout {
  display: flex;
  min-height: 100vh;
  background: #0d1117;
}

.admin-sidebar {
  width: 240px;
  flex-shrink: 0;
  background: rgba(22, 27, 34, 0.95);
  border-right: 1px solid #21262d;
  display: flex;
  flex-direction: column;
  padding: 1.5rem 0;
}

.sidebar-header {
  padding: 0 1.25rem 1.5rem;
  border-bottom: 1px solid #21262d;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.sidebar-logo {
  font-size: 1.5rem;
  color: #6366f1;
}

.sidebar-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #f1f5f9;
  margin: 0;
}

.sidebar-nav {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  padding: 0 0.75rem;
}

.sidebar-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.625rem 0.75rem;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: #94a3b8;
  font-size: 0.9375rem;
  cursor: pointer;
  transition: all 0.2s;
  text-align: left;
  width: 100%;
}

.sidebar-item:hover {
  background: rgba(255, 255, 255, 0.06);
  color: #c9d1d9;
}

.sidebar-item.active {
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.2), rgba(139, 92, 246, 0.2));
  color: #a5b4fc;
  border: 1px solid rgba(99, 102, 241, 0.3);
}

.sidebar-icon {
  font-size: 1rem;
  opacity: 0.9;
}

.sidebar-label {
  font-weight: 500;
}

.sidebar-footer {
  padding: 1rem 1.25rem 0;
  border-top: 1px solid #21262d;
}

.sidebar-back {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.875rem;
  padding: 0.5rem 0;
  transition: color 0.2s;
}

.sidebar-back:hover {
  color: #f1f5f9;
}

.admin-main {
  flex: 1;
  padding: 2rem 2.5rem;
  overflow-x: hidden;
  max-width: 1200px;
}

.admin-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
  gap: 1rem;
}

.admin-header h1 {
  font-size: 1.5rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0;
}

.admin-user-menu {
  position: relative;
}

.admin-user-trigger {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.75rem;
  background: rgba(30, 41, 59, 0.8);
  border: 1px solid #21262d;
  border-radius: 10px;
  color: #c9d1d9;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.admin-user-trigger:hover {
  background: rgba(30, 41, 59, 1);
  border-color: rgba(148, 163, 184, 0.2);
}

.admin-user-avatar {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  object-fit: cover;
}

.admin-user-avatar-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: white;
  font-size: 0.875rem;
  font-weight: 600;
}

.admin-user-name {
  max-width: 140px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.admin-user-chevron {
  font-size: 0.625rem;
  opacity: 0.7;
}

.admin-user-dropdown {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  min-width: 160px;
  padding: 0.5rem;
  background: rgba(22, 27, 34, 0.98);
  border: 1px solid #21262d;
  border-radius: 10px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
  z-index: 100;
}

.admin-user-dropdown-item {
  display: block;
  width: 100%;
  padding: 0.5rem 0.75rem;
  background: none;
  border: none;
  border-radius: 6px;
  color: #c9d1d9;
  font-size: 0.875rem;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s;
}

.admin-user-dropdown-item:hover {
  background: rgba(255, 255, 255, 0.06);
}

.admin-user-dropdown-divider {
  height: 1px;
  background: #21262d;
  margin: 0.5rem 0;
}

.admin-user-dropdown-logout {
  color: #f85149;
}

.admin-user-dropdown-logout:hover {
  background: rgba(248, 81, 73, 0.15);
}

.error-msg {
  padding: 0.75rem 1rem;
  background: rgba(239, 68, 68, 0.15);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: 8px;
  color: #fca5a5;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.admin-loading {
  color: #94a3b8;
  padding: 2rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  padding: 1.25rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 12px;
}

.stat-value {
  display: block;
  font-size: 1.5rem;
  font-weight: 700;
  color: #f1f5f9;
  margin-bottom: 0.25rem;
}

.stat-label {
  font-size: 0.8125rem;
  color: #94a3b8;
}

.section {
  margin-bottom: 2rem;
}

.section h2,
.admin-section h2 {
  font-size: 1.125rem;
  font-weight: 600;
  color: #c9d1d9;
  margin: 0 0 1rem 0;
}

.models-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.model-chip {
  padding: 0.5rem 0.75rem;
  background: rgba(22, 27, 34, 0.8);
  border: 1px solid #21262d;
  border-radius: 8px;
  font-size: 0.875rem;
  color: #c9d1d9;
}

.model-name {
  font-weight: 600;
  margin-right: 0.5rem;
}

.model-meta {
  color: #8b949e;
  font-size: 0.8125rem;
}

.model-slug {
  font-size: 0.8125rem;
  padding: 0.2rem 0.4rem;
  background: rgba(22, 27, 34, 0.8);
  border-radius: 4px;
  color: #8b949e;
}

.models-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.btn-check-updates {
  padding: 0.5rem 1rem;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  border: none;
  border-radius: 8px;
  color: white;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn-check-updates:hover:not(:disabled) {
  opacity: 0.9;
}

.btn-check-updates:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.model-check-result {
  margin-bottom: 1.5rem;
  padding: 1rem 1.25rem;
  background: rgba(22, 27, 34, 0.8);
  border: 1px solid #21262d;
  border-radius: 10px;
  font-size: 0.875rem;
}

.model-check-new {
  color: #7ee787;
}

.model-check-icon {
  margin-right: 0.5rem;
  font-weight: bold;
}

.model-check-list {
  margin: 0.75rem 0 0.5rem 1.5rem;
  padding: 0;
}

.model-check-list li {
  margin-bottom: 0.25rem;
  color: #c9d1d9;
}

.model-check-list code {
  margin-left: 0.5rem;
  padding: 0.1rem 0.35rem;
  background: rgba(0, 0, 0, 0.3);
  border-radius: 4px;
  font-size: 0.8125rem;
}

.model-check-provider {
  margin-left: 0.5rem;
  color: #8b949e;
  font-size: 0.8125rem;
}

.model-check-hint {
  margin: 0.5rem 0 0;
  color: #8b949e;
  font-size: 0.8125rem;
}

.model-check-up-to-date {
  color: #94a3b8;
}

.model-check-errors {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid #21262d;
  color: #8b949e;
  font-size: 0.8125rem;
}

.model-check-errors ul {
  margin: 0.25rem 0 0 1rem;
  padding: 0;
}

.model-check-name {
  font-weight: 500;
  color: #c9d1d9;
}

.model-inactive {
  margin-left: 0.5rem;
  color: #f85149;
  font-size: 0.75rem;
}

.table-wrap {
  overflow-x: auto;
  border: 1px solid #21262d;
  border-radius: 8px;
}

.admin-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.admin-table th,
.admin-table td {
  padding: 0.75rem 1rem;
  text-align: left;
  border-bottom: 1px solid #21262d;
}

.admin-table th {
  background: rgba(22, 27, 34, 0.8);
  color: #8b949e;
  font-weight: 500;
}

.admin-table td {
  color: #c9d1d9;
}

.admin-table tr:last-child td {
  border-bottom: none;
}

.admin-table .empty {
  color: #8b949e;
  text-align: center;
  padding: 2rem;
}

.user-email {
  display: block;
}

.user-name {
  display: block;
  font-size: 0.8125rem;
  color: #8b949e;
}

.badge {
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  font-size: 0.75rem;
}

.badge.active {
  background: rgba(34, 197, 94, 0.2);
  color: #7ee787;
}

.badge.canceled,
.badge.expired,
.badge.inactive {
  background: rgba(248, 81, 73, 0.2);
  color: #f85149;
}

.badge.admin {
  background: rgba(139, 92, 246, 0.2);
  color: #a78bfa;
}

.usage-summary {
  display: flex;
  gap: 2rem;
  margin-bottom: 1.5rem;
}

.usage-item {
  display: flex;
  flex-direction: column;
}

.usage-label {
  font-size: 0.8125rem;
  color: #8b949e;
}

.usage-value {
  font-size: 1.25rem;
  font-weight: 600;
  color: #f1f5f9;
}

.usage-stats h3 {
  font-size: 1rem;
  font-weight: 600;
  color: #c9d1d9;
  margin: 1.5rem 0 0.75rem 0;
}

.btn-adjust {
  padding: 0.25rem 0.6rem;
  border: 1px solid #30363d;
  border-radius: 6px;
  background: transparent;
  color: #c9d1d9;
  font-size: 0.75rem;
  cursor: pointer;
}

.btn-adjust:hover {
  border-color: #58a6ff;
  color: #58a6ff;
}

.plan-form {
  margin-bottom: 1.5rem;
  padding: 1.25rem;
  background: rgba(22, 27, 34, 0.8);
  border: 1px solid #30363d;
  border-radius: 10px;
}

.plan-form h3 {
  font-size: 1rem;
  font-weight: 600;
  color: #c9d1d9;
  margin: 0 0 1rem;
}

.plan-form-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
  gap: 0.875rem 1rem;
}

.plan-form-grid label {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
  font-size: 0.8125rem;
  color: #8b949e;
}

.plan-form-grid input,
.plan-form-grid select {
  padding: 0.45rem 0.6rem;
  background: #0d1117;
  border: 1px solid #30363d;
  border-radius: 6px;
  color: #c9d1d9;
  font: inherit;
  font-size: 0.875rem;
}

.plan-form-wide {
  grid-column: 1 / -1;
}

.plan-form-grid .plan-form-check {
  flex-direction: row;
  align-items: center;
  gap: 0.5rem;
  color: #c9d1d9;
}

.plan-form-error {
  margin: 0.875rem 0 0;
  color: #f85149;
  font-size: 0.875rem;
}

.plan-form-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  margin-top: 1rem;
}

.model-unavailable {
  font-size: 0.75rem;
  color: #8b949e;
}

.usage-note {
  margin: -0.25rem 0 0.75rem;
  font-size: 0.8rem;
  color: #8b949e;
}
</style>
