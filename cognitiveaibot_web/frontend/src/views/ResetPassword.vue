<script setup>
import { ref } from 'vue'
import { useRoute } from 'vue-router'
import AuthCard from '../components/AuthCard.vue'
import { resetPassword, clearToken } from '../api/auth'

const route = useRoute()
const token = String(route.query.token || '')
const password = ref('')
const confirm = ref('')
const done = ref(false)
const busy = ref(false)
const error = ref('')

async function submit() {
  error.value = ''
  if (password.value !== confirm.value) {
    error.value = 'The two passwords don’t match.'
    return
  }
  busy.value = true
  try {
    await resetPassword(token, password.value)
    // Every session ends with a password change, this browser's included.
    clearToken()
    done.value = true
  } catch (err) {
    error.value = err.message
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <AuthCard title="Choose a new password">
    <template v-if="done">
      <p class="ok" role="status">Your password is changed, and you’ve been signed out everywhere.</p>
      <p class="links"><router-link to="/signin" class="btn">Sign in</router-link></p>
    </template>
    <template v-else-if="!token">
      <p class="err" role="alert">This link is missing its code. Open the link from the email again, or ask for a new one.</p>
      <p class="links"><router-link to="/forgot-password">Send a new link</router-link></p>
    </template>
    <form v-else @submit.prevent="submit">
      <label>New password <input v-model="password" type="password" minlength="8" required autocomplete="new-password" /></label>
      <label>Repeat it <input v-model="confirm" type="password" minlength="8" required autocomplete="new-password" /></label>
      <p v-if="error" class="err" role="alert">
        {{ error }}
        <router-link v-if="/expired|invalid/i.test(error)" to="/forgot-password">Send a new link</router-link>
      </p>
      <button type="submit" class="btn" :disabled="busy">{{ busy ? 'Saving…' : 'Set new password' }}</button>
    </form>
  </AuthCard>
</template>
