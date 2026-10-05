const API_BASE = ''

function authHeaders() {
  const token = localStorage.getItem('token')
  return {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
  }
}

export async function getModels(filters = {}) {
  const params = new URLSearchParams(filters)
  const res = await fetch(`${API_BASE}/api/models?${params}`)
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch models')
  return data.models
}

export async function getChats(params = {}) {
  const q = new URLSearchParams(params)
  const res = await fetch(`${API_BASE}/api/chats?${q}`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch chats')
  return data.chats
}

export async function getChat(id) {
  const res = await fetch(`${API_BASE}/api/chats/${id}`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to fetch chat')
  return data.chat
}

export async function createChat(body = {}) {
  const res = await fetch(`${API_BASE}/api/chats`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to create chat')
  return data.chat
}

export async function deleteChat(id) {
  const res = await fetch(`${API_BASE}/api/chats/${id}`, { method: 'DELETE', headers: authHeaders() })
  if (!res.ok && res.status !== 404) throw new Error('Failed to delete chat')
}

/**
 * Sends a message and streams the model's reply.
 *
 * Calls `onEvent` with each server event as it arrives:
 *   { type: 'start', user_message, chat }  { type: 'delta', text }
 *   { type: 'done', message, usage }       { type: 'error', code, error, message }
 * Rejects with an Error carrying `code` when the request is refused before
 * streaming starts (nothing was saved). Abort `signal` to stop the reply.
 */
export async function streamCompletion(chatId, { content, model_id }, { onEvent, signal } = {}) {
  const res = await fetch(`${API_BASE}/api/chats/${chatId}/completions`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ content, model_id }),
    signal,
  })
  if (!(res.headers.get('content-type') || '').startsWith('text/event-stream')) {
    const data = await res.json().catch(() => ({}))
    const err = new Error(data.error || 'Could not get a reply. Try again.')
    err.code = data.code
    throw err
  }

  const reader = res.body.getReader()
  const decoder = new TextDecoder()
  let buffer = ''
  try {
    while (true) {
      const { value, done } = await reader.read()
      if (done) break
      buffer += decoder.decode(value, { stream: true })
      const parts = buffer.split('\n\n')
      buffer = parts.pop()
      for (const part of parts) {
        if (part.startsWith('data: ')) onEvent?.(JSON.parse(part.slice(6)))
      }
    }
  } catch (err) {
    if (err.name !== 'AbortError') throw err
  }
}

export async function createMessage(chatId, { role, content, model_id }) {
  const res = await fetch(`${API_BASE}/api/chats/${chatId}/messages`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify({ role, content, model_id }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to send message')
  return data.message
}

export async function getCredits() {
  const res = await fetch(`${API_BASE}/api/credits`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) return null
  return data
}

export async function getProfile() {
  const res = await fetch(`${API_BASE}/api/users/me`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) return null
  return data.user
}

export async function updateProfile({ name, avatar_url }) {
  const res = await fetch(`${API_BASE}/api/users/me`, {
    method: 'PATCH',
    headers: authHeaders(),
    body: JSON.stringify({ name: name || undefined, avatar_url: avatar_url || undefined }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to update profile')
  return data.user
}

async function postJson(path, body) {
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body || {}),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(data.error || 'Something went wrong. Try again.')
    err.code = data.code
    throw err
  }
  return data
}

/** The active plan catalog (public). */
export async function getPlans() {
  const res = await fetch(`${API_BASE}/api/plans`)
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to load plans')
  return data.plans
}

/** The caller's plan, subscription state and credit balance. */
export async function getBilling() {
  const res = await fetch(`${API_BASE}/api/billing`, { headers: authHeaders() })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) return null
  return data
}

/** Starts Stripe Checkout for a plan; resolves to the URL to send the browser to. */
export async function startCheckout(planId) {
  return (await postJson('/api/billing/checkout', { plan_id: planId })).url
}

/** Opens Stripe's billing portal; resolves to its URL. */
export async function openBillingPortal() {
  return (await postJson('/api/billing/portal')).url
}

export async function uploadAvatar(file) {
  const formData = new FormData()
  formData.append('avatar', file)
  const token = localStorage.getItem('token')
  const headers = {}
  if (token) headers.Authorization = `Bearer ${token}`
  const res = await fetch(`${API_BASE}/api/users/me/avatar`, {
    method: 'POST',
    headers,
    body: formData,
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Failed to upload photo')
  return data.user
}
