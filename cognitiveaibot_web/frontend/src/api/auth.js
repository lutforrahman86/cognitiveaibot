const API_BASE = ''

export async function register({ email, password, name }) {
  const res = await fetch(`${API_BASE}/api/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, name: name || null }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    throw new Error(data.error || 'Registration failed')
  }
  return data
}

export async function login({ email, password }) {
  const res = await fetch(`${API_BASE}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    throw new Error(data.error || 'Login failed')
  }
  return data
}

export function getToken() {
  return localStorage.getItem('token')
}

export function setToken(token) {
  localStorage.setItem('token', token)
}

export function clearToken() {
  localStorage.removeItem('token')
}

export function isAuthenticated() {
  return !!getToken()
}

export async function getMe() {
  const token = getToken()
  if (!token) return null
  const res = await fetch(`${API_BASE}/api/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  if (!res.ok) return null
  const data = await res.json()
  return data.user
}

async function postJson(path, body, { auth = false } = {}) {
  const token = getToken()
  const res = await fetch(`${API_BASE}${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(auth && token ? { Authorization: `Bearer ${token}` } : {}) },
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

/** Emails a reset link if the account exists; always resolves the same way. */
export const forgotPassword = (email) => postJson('/api/auth/forgot-password', { email })

export const resetPassword = (token, password) => postJson('/api/auth/reset-password', { token, password })

export const verifyEmail = (token) => postJson('/api/auth/verify-email', { token })

export const resendVerification = () => postJson('/api/auth/resend-verification', {}, { auth: true })

/** Changes the password; stores the fresh session token it returns. */
export async function changePassword(currentPassword, newPassword) {
  const data = await postJson('/api/users/me/password', { current_password: currentPassword, new_password: newPassword }, { auth: true })
  if (data.token) setToken(data.token)
  return data
}

/** Downloads everything held about the user as a JSON file. */
export async function downloadMyData() {
  const res = await fetch(`${API_BASE}/api/users/me/export`, { headers: { Authorization: `Bearer ${getToken()}` } })
  if (!res.ok) throw new Error('Couldn’t export your data. Try again.')
  const blob = await res.blob()
  const name = (res.headers.get('content-disposition') || '').match(/filename="([^"]+)"/)?.[1] || 'cognitiveaibot-export.json'
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = name
  a.click()
  URL.revokeObjectURL(url)
}

/** Deletes the account. `confirm` is the password (or email for Google/GitHub accounts). */
export async function deleteAccount(confirm) {
  const res = await fetch(`${API_BASE}/api/users/me`, {
    method: 'DELETE',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${getToken()}` },
    body: JSON.stringify({ confirm }),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) throw new Error(data.error || 'Couldn’t delete the account.')
  clearToken()
}
