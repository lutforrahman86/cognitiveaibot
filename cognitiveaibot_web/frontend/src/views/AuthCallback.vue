<script setup>
import { onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { setToken, getMe } from '../api/auth'

const route = useRoute()
const router = useRouter()

onMounted(async () => {
  const token = route.query.token
  const error = route.query.error

  if (error) {
    router.replace({ path: '/signin', query: { error } })
    return
  }

  if (token) {
    setToken(token)
    const user = await getMe()
    router.replace(user?.type === 'admin' ? '/admin' : '/')
    return
  }

  router.replace('/signin')
})
</script>

<template>
  <div class="callback">
    <p>Completing sign in...</p>
  </div>
</template>

<style scoped>
.callback {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #94a3b8;
}
</style>
