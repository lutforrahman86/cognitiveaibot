<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { changePassword, downloadMyData, deleteAccount } from '../api/auth'

// Password, data export and account deletion (roadmap B18).
const props = defineProps({ email: { type: String, required: true }, hasOAuth: { type: Boolean, default: false } })
const router = useRouter()

const pw = ref({ current: '', next: '', confirm: '' })
const pwBusy = ref(false)
const pwMsg = ref('')
const pwErr = ref('')

const exporting = ref(false)
const exportErr = ref('')

const showDelete = ref(false)
const confirmText = ref('')
const deleting = ref(false)
const deleteErr = ref('')

async function savePassword() {
  pwMsg.value = ''
  pwErr.value = ''
  if (pw.value.next !== pw.value.confirm) {
    pwErr.value = 'The two new passwords don’t match.'
    return
  }
  pwBusy.value = true
  try {
    await changePassword(pw.value.current, pw.value.next)
    pw.value = { current: '', next: '', confirm: '' }
    pwMsg.value = 'Password changed. Your other devices have been signed out.'
  } catch (err) {
    pwErr.value = err.message
  } finally {
    pwBusy.value = false
  }
}

async function exportData() {
  exportErr.value = ''
  exporting.value = true
  try {
    await downloadMyData()
  } catch (err) {
    exportErr.value = err.message
  } finally {
    exporting.value = false
  }
}

async function confirmDelete() {
  deleteErr.value = ''
  deleting.value = true
  try {
    await deleteAccount(confirmText.value)
    router.push('/?account=deleted')
  } catch (err) {
    deleteErr.value = err.message
    deleting.value = false
  }
}
</script>

<template>
  <div class="account">
    <section>
      <h2>Password</h2>
      <form class="stack" @submit.prevent="savePassword">
        <input v-model="pw.current" type="password" placeholder="Current password" autocomplete="current-password" :required="!props.hasOAuth" />
        <input v-model="pw.next" type="password" placeholder="New password (8+ characters)" minlength="8" required autocomplete="new-password" />
        <input v-model="pw.confirm" type="password" placeholder="Repeat new password" minlength="8" required autocomplete="new-password" />
        <p v-if="props.hasOAuth" class="hint">If you only sign in with Google or GitHub, leave the current password empty to add one.</p>
        <p v-if="pwMsg" class="ok" role="status">{{ pwMsg }}</p>
        <p v-if="pwErr" class="err" role="alert">{{ pwErr }}</p>
        <button type="submit" class="btn" :disabled="pwBusy">{{ pwBusy ? 'Saving…' : 'Change password' }}</button>
      </form>
    </section>

    <section>
      <h2>Your data</h2>
      <p class="hint">Download your profile, chats, settings, credit history, subscriptions and usage as a JSON file.</p>
      <p v-if="exportErr" class="err" role="alert">{{ exportErr }}</p>
      <button type="button" class="btn secondary" :disabled="exporting" @click="exportData">
        {{ exporting ? 'Preparing…' : 'Download my data' }}
      </button>
    </section>

    <section class="danger">
      <h2>Delete account</h2>
      <p class="hint">
        Deletes your chats, settings, API keys and profile at once, and cancels any web subscription. Unused credits are lost.
        App Store subscriptions must be cancelled in your Apple account. Billing records are kept, without your name, as the law requires.
      </p>
      <button v-if="!showDelete" type="button" class="btn danger-btn" @click="showDelete = true">Delete my account…</button>
      <form v-else class="stack" @submit.prevent="confirmDelete">
        <label class="hint" for="confirm-delete">
          To confirm, enter your password, or your email ({{ props.email }}) if you only sign in with Google or GitHub.
        </label>
        <input id="confirm-delete" v-model="confirmText" type="password" autocomplete="current-password" required />
        <p v-if="deleteErr" class="err" role="alert">{{ deleteErr }}</p>
        <div class="row">
          <button type="submit" class="btn danger-btn" :disabled="deleting">{{ deleting ? 'Deleting…' : 'Delete my account permanently' }}</button>
          <button type="button" class="btn secondary" @click="showDelete = false; confirmText = ''">Cancel</button>
        </div>
      </form>
    </section>
  </div>
</template>

<style scoped>
.account { margin-top: 2rem; display: flex; flex-direction: column; gap: 1.75rem; }
section { padding-top: 1.5rem; border-top: 1px solid rgba(148, 163, 184, 0.12); }
h2 { font-size: 1rem; font-weight: 600; color: #f1f5f9; margin-bottom: 0.75rem; }
.stack { display: flex; flex-direction: column; gap: 0.625rem; }
.row { display: flex; gap: 0.625rem; flex-wrap: wrap; }
input {
  padding: 0.625rem 0.875rem;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.25);
  border-radius: 10px;
  color: #f1f5f9;
  font: inherit;
}
.hint { color: #94a3b8; font-size: 0.8125rem; line-height: 1.5; margin-bottom: 0.625rem; }
.ok { color: #86efac; font-size: 0.875rem; }
.err { color: #fca5a5; font-size: 0.875rem; }
.btn {
  padding: 0.625rem 1rem;
  border-radius: 10px;
  border: 1px solid transparent;
  background: #6366f1;
  color: white;
  font: inherit;
  font-weight: 500;
  cursor: pointer;
}
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.secondary { background: transparent; border-color: rgba(148, 163, 184, 0.3); color: #e2e8f0; }
.danger h2 { color: #fca5a5; }
.danger-btn { background: transparent; border-color: rgba(239, 68, 68, 0.5); color: #fca5a5; }
.danger-btn:hover:not(:disabled) { background: rgba(239, 68, 68, 0.12); }
</style>
