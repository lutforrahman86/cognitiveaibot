<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import AuthCard from '../components/AuthCard.vue'
import { verifyEmail, isAuthenticated } from '../api/auth'

const route = useRoute()
const state = ref('working')
const error = ref('')

onMounted(async () => {
  try {
    await verifyEmail(String(route.query.token || ''))
    state.value = 'done'
  } catch (err) {
    error.value = err.message
    state.value = 'failed'
  }
})
</script>

<template>
  <AuthCard title="Confirm your email">
    <p v-if="state === 'working'" class="ok" role="status">Confirming…</p>
    <template v-else-if="state === 'done'">
      <p class="ok" role="status">Your email is confirmed. Thanks!</p>
      <p class="links"><router-link :to="isAuthenticated() ? '/chat' : '/signin'" class="btn">Continue</router-link></p>
    </template>
    <template v-else>
      <p class="err" role="alert">{{ error }}</p>
      <p class="links">Signed in? You can send a new link from the banner in the chat.</p>
    </template>
  </AuthCard>
</template>
