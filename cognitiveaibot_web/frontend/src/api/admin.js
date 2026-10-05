const API_BASE = ''

function authHeaders() {
  const token = localStorage.getItem('token')
  return {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
  }
}

export async function getAdminDashboard() {
  const res = await fetch(`${API_BASE}/api/admin/dashboard`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to load dashboard')
  return data
}

export async function getAdminUsers(params = {}) {
  const q = new URLSearchParams(params)
  const res = await fetch(`${API_BASE}/api/admin/users?${q}`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch users')
  return data
}

export async function getAdminSubscriptions(params = {}) {
  const q = new URLSearchParams(params)
  const res = await fetch(`${API_BASE}/api/admin/subscriptions?${q}`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch subscriptions')
  return data
}

export async function getAdminUsage(params = {}) {
  const q = new URLSearchParams(params)
  const res = await fetch(`${API_BASE}/api/admin/usage?${q}`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch usage')
  return data
}

export async function getAdminModels() {
  const res = await fetch(`${API_BASE}/api/admin/models`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch models')
  return data
}

export async function adjustUserCredits(userId, credits, reason) {
  const res = await fetch(`${API_BASE}/api/admin/users/${userId}/credits`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ credits, reason }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to adjust credits')
  return data
}

export async function checkModelUpdates() {
  const res = await fetch(`${API_BASE}/api/admin/models/check-updates`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to check for new models')
  return data
}

export async function checkIsAdmin() {
  const res = await fetch(`${API_BASE}/api/admin/check`, { headers: authHeaders() })
  if (!res.ok) return false
  const data = await res.json().catch(() => ({}))
  return !!data.isAdmin
}

export async function getAdminPlans() {
  const res = await fetch(`${API_BASE}/api/admin/plans`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch plans')
  return data.plans
}

/** Creates a plan, or updates it when `id` is given. */
export async function saveAdminPlan(plan, id = null) {
  const res = await fetch(`${API_BASE}/api/admin/plans${id ? `/${id}` : ''}`, {
    method: id ? 'PATCH' : 'POST',
    headers: authHeaders(),
    body: JSON.stringify(plan),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to save plan')
  return data.plan
}
