<script setup>
import { ref } from 'vue'
import AuthCard from '../components/AuthCard.vue'
import { forgotPassword } from '../api/auth'

const email = ref('')
const sent = ref(false)
const busy = ref(false)
const error = ref('')

async function submit() {
  busy.value = true
  error.value = ''
  try {
    await forgotPassword(email.value.trim())
    sent.value = true
  } catch (err) {
    error.value = err.message
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <AuthCard title="Reset your password" subtitle="Enter your account’s email and we’ll send you a link to set a new password.">
    <p v-if="sent" class="ok" role="status">
      If an account uses {{ email }}, a reset link is on its way. It works once, for the next hour. Check your spam folder if it
      doesn’t arrive.
    </p>
    <form v-else @submit.prevent="submit">
      <label>Email <input v-model="email" type="email" required autocomplete="email" /></label>
      <p v-if="error" class="err" role="alert">{{ error }}</p>
      <button type="submit" class="btn" :disabled="busy">{{ busy ? 'Sending…' : 'Send reset link' }}</button>
    </form>
    <p class="links"><router-link to="/signin">Back to sign in</router-link></p>
  </AuthCard>
</template>
