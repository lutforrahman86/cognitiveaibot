<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getProfile, updateProfile, uploadAvatar } from '../api/chat'

const router = useRouter()
const user = ref(null)
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const success = ref('')

const form = reactive({ name: '', avatar_url: '' })
const avatarInputRef = ref(null)
const uploading = ref(false)

function getSignInMethod() {
  if (!user.value) return ''
  if (user.value.google_id) return 'Google'
  if (user.value.github_id) return 'GitHub'
  if (user.value.apple_id) return 'Apple'
  return 'Email'
}

function formatDate(ts) {
  if (!ts) return ''
  const d = new Date(ts)
  return d.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' })
}

function goBack() {
  router.push('/chat')
}

async function loadProfile() {
  loading.value = true
  error.value = ''
  try {
    user.value = await getProfile()
    if (user.value) {
      form.name = user.value.name || ''
      form.avatar_url = user.value.avatar_url || ''
    }
  } catch (err) {
    error.value = err.message || 'Failed to load profile'
  } finally {
    loading.value = false
  }
}

const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
const MAX_SIZE = 2 * 1024 * 1024 // 2MB

function triggerAvatarInput() {
  avatarInputRef.value?.click()
}

async function handleAvatarSelect(e) {
  const file = e.target.files?.[0]
  if (!file) return
  e.target.value = ''
  if (!ALLOWED_TYPES.includes(file.type)) {
    error.value = 'Please select a JPEG, PNG, GIF, or WebP image.'
    return
  }
  if (file.size > MAX_SIZE) {
    error.value = 'Image must be 2MB or smaller.'
    return
  }
  error.value = ''
  success.value = ''
  uploading.value = true
  try {
    user.value = await uploadAvatar(file)
    form.avatar_url = user.value.avatar_url || ''
    success.value = 'Photo updated successfully'
    setTimeout(() => { success.value = '' }, 3000)
  } catch (err) {
    error.value = err.message || 'Failed to upload photo'
  } finally {
    uploading.value = false
  }
}

async function handleSave() {
  error.value = ''
  success.value = ''
  const name = form.name?.trim()
  const avatar_url = form.avatar_url?.trim() || null
  if (!name) {
    error.value = 'Name is required'
    return
  }
  saving.value = true
  try {
    user.value = await updateProfile({ name, avatar_url })
    form.name = user.value.name || ''
    form.avatar_url = user.value.avatar_url || ''
    success.value = 'Profile updated successfully'
    setTimeout(() => { success.value = '' }, 3000)
  } catch (err) {
    error.value = err.message || 'Failed to update profile'
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  await loadProfile()
})
</script>

<template>
  <div class="profile-page">
    <div class="profile-card">
      <a href="#" class="back-link" @click.prevent="goBack">← Back to Chat</a>
      <div class="profile-header">
        <span class="logo-icon">◇</span>
        <h1>Profile</h1>
        <p>Manage your account details</p>
      </div>

      <div v-if="loading" class="profile-loading">Loading...</div>

      <template v-else-if="user">
        <div class="profile-avatar-section">
          <input
            ref="avatarInputRef"
            type="file"
            accept="image/jpeg,image/png,image/gif,image/webp"
            class="avatar-input-hidden"
            @change="handleAvatarSelect"
          />
          <button
            type="button"
            class="profile-avatar-btn"
            :disabled="uploading"
            @click="triggerAvatarInput"
          >
            <img
              v-if="form.avatar_url"
              :src="form.avatar_url"
              alt="Avatar"
              class="profile-avatar"
            />
            <div v-else class="profile-avatar profile-avatar-placeholder">
              {{ (form.name || user.email || 'U').charAt(0).toUpperCase() }}
            </div>
            <span class="profile-avatar-overlay">
              {{ uploading ? 'Uploading...' : 'Change photo' }}
            </span>
          </button>
        </div>

        <div v-if="error" class="error-msg">{{ error }}</div>
        <div v-if="success" class="success-msg">{{ success }}</div>

        <form class="profile-form" @submit.prevent="handleSave">
          <div class="field">
            <label for="name">Display name</label>
            <input
              id="name"
              v-model="form.name"
              type="text"
              placeholder="Your name"
              required
              autocomplete="name"
            />
          </div>
          <div class="field">
            <label for="avatar_url">Avatar URL</label>
            <input
              id="avatar_url"
              v-model="form.avatar_url"
              type="url"
              placeholder="Or paste an image URL"
              autocomplete="off"
            />
            <span class="field-hint">Optional. Upload above or paste an image URL.</span>
          </div>
          <div class="field field-readonly">
            <label>Email</label>
            <div class="readonly-value">{{ user.email }}</div>
          </div>
          <div class="field field-readonly">
            <label>Signed in with</label>
            <div class="readonly-value">{{ getSignInMethod() }}</div>
          </div>
          <div v-if="user.created_at" class="field field-readonly">
            <label>Member since</label>
            <div class="readonly-value">{{ formatDate(user.created_at) }}</div>
          </div>
          <button type="submit" class="btn btn-primary btn-block" :disabled="saving">
            {{ saving ? 'Saving...' : 'Save changes' }}
          </button>
        </form>
      </template>
    </div>
  </div>
</template>

<style scoped>
.profile-page {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 2rem;
  padding-top: 4rem;
}

.profile-card {
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

.profile-header {
  text-align: center;
  margin-bottom: 2rem;
}

.profile-header .logo-icon {
  display: block;
  font-size: 2rem;
  color: #6366f1;
  margin-bottom: 0.75rem;
}

.profile-header h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 0.5rem 0;
}

.profile-header p {
  font-size: 0.9375rem;
  color: #94a3b8;
  margin: 0;
}

.profile-loading {
  text-align: center;
  color: #94a3b8;
  padding: 2rem;
}

.avatar-input-hidden {
  position: absolute;
  width: 0;
  height: 0;
  opacity: 0;
  pointer-events: none;
}

.profile-avatar-section {
  display: flex;
  justify-content: center;
  margin-bottom: 1.5rem;
}

.profile-avatar-btn {
  position: relative;
  padding: 0;
  background: none;
  border: none;
  cursor: pointer;
  border-radius: 50%;
  overflow: hidden;
}

.profile-avatar-btn:disabled {
  cursor: not-allowed;
}

.profile-avatar-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.6);
  color: white;
  font-size: 0.75rem;
  font-weight: 500;
  opacity: 0;
  transition: opacity 0.2s;
}

.profile-avatar-btn:hover:not(:disabled) .profile-avatar-overlay {
  opacity: 1;
}

.profile-avatar-btn:disabled .profile-avatar-overlay {
  opacity: 1;
  background: rgba(0, 0, 0, 0.5);
}

.profile-avatar {
  width: 5rem;
  height: 5rem;
  border-radius: 50%;
  object-fit: cover;
  display: block;
}

.profile-avatar-placeholder {
  width: 5rem;
  height: 5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: white;
  font-size: 1.75rem;
  font-weight: 600;
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

.success-msg {
  padding: 0.75rem 1rem;
  background: rgba(34, 197, 94, 0.15);
  border: 1px solid rgba(34, 197, 94, 0.3);
  border-radius: 8px;
  color: #86efac;
  font-size: 0.875rem;
  margin-bottom: 1rem;
}

.profile-form .field {
  margin-bottom: 1.25rem;
}

.profile-form label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #cbd5e1;
  margin-bottom: 0.5rem;
}

.profile-form input {
  width: 100%;
  padding: 0.75rem 1rem;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 8px;
  color: #f1f5f9;
  font-size: 1rem;
}

.profile-form input::placeholder {
  color: #64748b;
}

.profile-form input:focus {
  outline: none;
  border-color: #6366f1;
}

.field-hint {
  display: block;
  font-size: 0.75rem;
  color: #64748b;
  margin-top: 0.375rem;
}

.field-readonly .readonly-value {
  padding: 0.75rem 1rem;
  background: rgba(15, 23, 42, 0.5);
  border: 1px solid rgba(148, 163, 184, 0.15);
  border-radius: 8px;
  color: #94a3b8;
  font-size: 0.9375rem;
}

.btn-block {
  width: 100%;
  margin-top: 0.5rem;
  padding: 0.875rem;
  font-size: 1rem;
}

.btn-primary {
  background: linear-gradient(135deg, #6366f1, #8b5cf6);
  color: white;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn-primary:hover:not(:disabled) {
  opacity: 0.9;
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
