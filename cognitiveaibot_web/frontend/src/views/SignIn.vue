<script setup>
import { ref, reactive } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { login, setToken, getMe } from '../api/auth'

const route = useRoute()
const router = useRouter()
const apiBase = import.meta.env.VITE_API_URL || ''

const form = reactive({ email: '', password: '' })
const error = ref('')
const loading = ref(false)

function goBack() {
  router.push('/')
}

async function handleSubmit() {
  error.value = ''
  if (!form.email?.trim() || !form.password) {
    error.value = 'Email and password are required'
    return
  }
  loading.value = true
  try {
    const data = await login({ email: form.email.trim(), password: form.password })
    setToken(data.token)
    const user = (await getMe()) || data.user
    router.push(user?.type === 'admin' ? '/admin' : '/')
  } catch (err) {
    error.value = err.message || 'Sign in failed'
  } finally {
    loading.value = false
  }
}

function signInWithGoogle() {
  window.location.href = `${apiBase}/api/auth/google`
}

function signInWithGithub() {
  window.location.href = `${apiBase}/api/auth/github`
}
</script>

<template>
  <div class="signin">
    <div class="signin-card">
      <a href="#" class="back-link" @click.prevent="goBack">← Back</a>
      <div class="signin-header">
        <span class="logo-icon">◇</span>
        <h1>Sign in</h1>
        <p>Welcome back to CognitiveAI Bot</p>
      </div>
      <div v-if="route.query.error || error" class="error-msg">{{ route.query.error || error }}</div>
      <div class="oauth-buttons">
        <button type="button" class="btn btn-oauth" @click="signInWithGoogle">
          <svg class="oauth-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
          Continue with Google
        </button>
        <button type="button" class="btn btn-oauth" @click="signInWithGithub">
          <svg class="oauth-icon" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
          Continue with GitHub
        </button>
      </div>
      <div class="divider">
        <span>or</span>
      </div>
      <form class="signin-form" @submit.prevent="handleSubmit">
        <div class="field">
          <label for="email">Email</label>
          <input id="email" v-model="form.email" type="email" placeholder="you@example.com" required autocomplete="email" />
        </div>
        <div class="field">
          <span class="label-row">
            <label for="password">Password</label>
            <router-link to="/forgot-password" class="forgot-link">Forgot password?</router-link>
          </span>
          <input id="password" v-model="form.password" type="password" placeholder="••••••••" required autocomplete="current-password" />
        </div>
        <button type="submit" class="btn btn-primary btn-block" :disabled="loading">
          {{ loading ? 'Signing in...' : 'Sign in' }}
        </button>
      </form>
      <p class="signin-footer">
        Don't have an account?
        <RouterLink to="/signup">Sign up</RouterLink>
      </p>
    </div>
  </div>
</template>

<style scoped>
.signin {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 2rem;
}

.signin-card {
  width: 100%;
  max-width: 28rem;
  padding: 2.5rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 16px;
}

.back-link {
  display: inline-block;
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.9375rem;
  margin-bottom: 1.5rem;
  transition: color 0.2s;
}

.back-link:hover {
  color: #f1f5f9;
}

.signin-header {
  text-align: center;
  margin-bottom: 2rem;
}

.signin-header .logo-icon {
  display: block;
  font-size: 2rem;
  color: #6366f1;
  margin-bottom: 0.75rem;
}

.signin-header h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 0.5rem 0;
}

.signin-header p {
  font-size: 0.9375rem;
  color: #94a3b8;
  margin: 0;
}

.signin-form .field {
  margin-bottom: 1.25rem;
}

.signin-form label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #cbd5e1;
  margin-bottom: 0.5rem;
}

.signin-form input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 8px;
  color: #f1f5f9;
  font-size: 1rem;
}

.signin-form input::placeholder {
  color: #64748b;
}

.signin-form input:focus {
  outline: none;
  border-color: #6366f1;
}

.btn-block {
  width: 100%;
  margin-top: 0.5rem;
  padding: 0.875rem;
}

.btn-block:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.signin-footer {
  text-align: center;
  margin-top: 1.5rem;
  font-size: 0.9375rem;
  color: #94a3b8;
}

.signin-footer a {
  color: #6366f1;
  text-decoration: none;
  font-weight: 500;
}

.signin-footer a:hover {
  text-decoration: underline;
}

.label-row { display: flex; justify-content: space-between; align-items: baseline; }
.forgot-link { color: #a5b4fc; font-size: 0.8125rem; text-decoration: none; }
.forgot-link:hover { text-decoration: underline; }

.error-msg {
  padding: 0.75rem;
  background: rgba(239, 68, 68, 0.15);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: 8px;
  color: #fca5a5;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.oauth-buttons {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.btn-oauth {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.75rem 1rem;
  background: rgba(30, 41, 59, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 8px;
  color: #f1f5f9;
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s;
}

.btn-oauth:hover {
  background: rgba(30, 41, 59, 1);
  border-color: rgba(148, 163, 184, 0.3);
}

.oauth-icon {
  width: 20px;
  height: 20px;
}

.divider {
  display: flex;
  align-items: center;
  margin: 1.5rem 0;
  color: #64748b;
  font-size: 0.8125rem;
}

.divider::before,
.divider::after {
  content: '';
  flex: 1;
  height: 1px;
  background: rgba(148, 163, 184, 0.2);
}

.divider span {
  padding: 0 1rem;
}
</style>
