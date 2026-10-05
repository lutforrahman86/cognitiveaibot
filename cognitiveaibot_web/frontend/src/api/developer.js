function authHeaders() {
  const token = localStorage.getItem('token')
  return {
    'Content-Type': 'application/json',
    ...(token && { Authorization: `Bearer ${token}` }),
  }
}

async function request(method, path, body) {
  const res = await fetch(path, {
    method,
    headers: authHeaders(),
    body: body === undefined ? undefined : JSON.stringify(body),
  })
  const data = await res.json().catch(() => ({}))
  if (!res.ok) {
    const err = new Error(data.error || 'Something went wrong. Try again.')
    err.code = data.code
    throw err
  }
  return data
}

/** API access, the base URL and the user's keys. */
export const getDeveloper = () => request('GET', '/api/developer')

/** Creates a key; the response holds the full key, which is never shown again. */
export const createApiKey = async (name) => (await request('POST', '/api/developer/keys', { name })).key

export const revokeApiKey = (id) => request('DELETE', `/api/developer/keys/${id}`)

export const getApiUsage = (days = 30) => request('GET', `/api/developer/usage?days=${days}`)
