<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated } from '../api/auth'
import { getModels, getChats, getChat, createChat, deleteChat, streamCompletion, getProfile, getBilling } from '../api/chat'
import { checkIsAdmin } from '../api/admin'

const router = useRouter()
const sidebarOpen = ref(false)

const models = ref([])
const chats = ref([])
const currentChat = ref(null)
const messages = ref([])
const selectedModel = ref(null)
const inputText = ref('')
const sending = ref(false)
const messagesEndRef = ref(null)
const selectedFiles = ref([])
const fileInputRef = ref(null)
const isRecording = ref(false)
const mediaRecorderRef = ref(null)
const recordedBlob = ref(null)
const user = ref(null)
const billing = ref(null)
const showUserDropdown = ref(false)
const isAdmin = ref(false)
const errorText = ref('')
// Set when a reply was refused for lack of credits, to offer a way to buy more.
const outOfCredits = ref(false)
// Available credits (balance minus anything held for a reply in progress).
const credits = ref(null)
const activeReply = ref(null)

watch(messages, () => {
  setTimeout(() => messagesEndRef.value?.scrollIntoView({ behavior: 'smooth' }), 50)
}, { deep: true })

// Provider accent colors
const providerColors = {
  OpenAI: '#10a37f',
  Anthropic: '#d97757',
  Google: '#4285f4',
  DeepSeek: '#0d9488',
  Perplexity: '#20808d',
  xAI: '#8b949e',
  Grok: '#8b949e',
  Mistral: '#ff6b35',
  Meta: '#0866ff',
  Qwen: '#615ced',
  Moonshot: '#a371f7',
  'Z.ai': '#3fb950',
  MiniMax: '#f778ba',
}

function getProviderColor(provider) {
  return providerColors[provider] || '#58a6ff'
}

onMounted(async () => {
  if (!isAuthenticated()) {
    router.push('/signin')
    return
  }
  const [profileRes, billingRes] = await Promise.all([getProfile(), getBilling()])
  user.value = profileRes
  billing.value = billingRes
  credits.value = billingRes ? billingRes.credits.available : null
  isAdmin.value = await checkIsAdmin()
  await loadModels()
  await loadChats()
  selectedModel.value = models.value.find((m) => m.available) || null
  document.addEventListener('click', handleClickOutsideUser)
})
onUnmounted(() => {
  document.removeEventListener('click', handleClickOutsideUser)
})

function formatCredits(n) {
  return Number(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function getPlanLabel() {
  return billing.value?.plan?.name || 'Free'
}

function toggleUserDropdown(e) {
  e.stopPropagation()
  showUserDropdown.value = !showUserDropdown.value
}

function closeUserDropdown() {
  showUserDropdown.value = false
}

function handleUserMenuClick(path) {
  router.push(path)
  closeUserDropdown()
  sidebarOpen.value = false
}

function handleClickOutsideUser(e) {
  if (showUserDropdown.value && !e.target.closest('.sidebar-user-wrapper')) {
    closeUserDropdown()
  }
}

async function loadModels() {
  try {
    models.value = await getModels()
  } catch {
    models.value = []
  }
}

async function loadChats() {
  try {
    chats.value = await getChats({ limit: 30 })
  } catch {
    chats.value = []
  }
}

async function startNewChat() {
  sending.value = true
  try {
    const chat = await createChat({
      title: 'New chat',
      model_id: selectedModel.value?.id,
    })
    chats.value = [chat, ...chats.value]
    await selectChat(chat.id)
  } catch (err) {
    console.error(err)
  } finally {
    sending.value = false
  }
}

async function selectChat(chatId) {
  try {
    const chat = await getChat(chatId)
    currentChat.value = chat
    messages.value = chat.messages || []
    sidebarOpen.value = false
    errorText.value = ''
    if (chat.model_id) {
      const m = models.value.find((x) => x.id === chat.model_id)
      if (m?.available) selectedModel.value = m
    }
  } catch (err) {
    console.error(err)
  }
}

async function sendMessage() {
  const text = inputText.value.trim()
  const model = selectedModel.value
  if (!text || !model || sending.value) return
  if (!model.available) {
    errorText.value = `${model.name} isn’t available yet. Choose another model.`
    return
  }

  errorText.value = ''
  outOfCredits.value = false
  inputText.value = ''
  sending.value = true

  // A chat created just for this message is removed again if the message
  // never gets through, so failures don't leave empty chats in the sidebar.
  let createdChat = null
  if (!currentChat.value) {
    try {
      createdChat = await createChat({ title: 'New chat', model_id: model.id })
      chats.value = [createdChat, ...chats.value]
      currentChat.value = createdChat
      messages.value = []
    } catch (err) {
      errorText.value = err.message
      inputText.value = text
      sending.value = false
      return
    }
  }
  const chatId = currentChat.value.id

  const userMsg = { role: 'user', content: text }
  const reply = { role: 'assistant', content: '', model_name: model.name, streaming: true }
  messages.value.push(userMsg)
  // The reply is pushed first and then read back through the array, so Vue
  // tracks it and re-renders as each piece of text arrives.
  messages.value.push(reply)
  const replyIndex = messages.value.length - 1
  const live = () => messages.value[replyIndex]

  const controller = new AbortController()
  activeReply.value = controller
  let started = false

  try {
    await streamCompletion(
      chatId,
      { content: text, model_id: model.id },
      {
        signal: controller.signal,
        onEvent(event) {
          if (event.type === 'start') {
            started = true
            Object.assign(userMsg, event.user_message)
            const listed = chats.value.find((c) => c.id === chatId)
            if (listed && event.chat?.title) listed.title = event.chat.title
          } else if (event.type === 'delta') {
            live().content += event.text
          } else if (event.type === 'done' || event.type === 'error') {
            if (event.credits) credits.value = event.credits.balance
            if (event.type === 'error') errorText.value = event.error
          }
        },
      }
    )
  } catch (err) {
    errorText.value = err.message
    outOfCredits.value = err.code === 'INSUFFICIENT_CREDITS'
  } finally {
    live().streaming = false
    // Nothing reached the server: put the text back so it can be resent.
    if (!started) {
      messages.value.splice(messages.value.length - 2, 2)
      inputText.value = text
      if (createdChat) {
        deleteChat(createdChat.id).catch(() => {})
        chats.value = chats.value.filter((c) => c.id !== createdChat.id)
        currentChat.value = null
      }
    } else if (!live().content) {
      messages.value.splice(replyIndex, 1)
    }
    activeReply.value = null
    sending.value = false
  }
}

function stopReply() {
  activeReply.value?.abort()
}

function toggleSidebar() {
  sidebarOpen.value = !sidebarOpen.value
}

function goHome() {
  router.push('/')
}

function triggerFileSelect() {
  fileInputRef.value?.click()
}

function onFileChange(e) {
  const files = Array.from(e.target.files || [])
  for (const f of files) {
    if (!selectedFiles.value.some((x) => x.name === f.name && x.size === f.size)) {
      selectedFiles.value.push(f)
    }
  }
  e.target.value = ''
}

function removeFile(index) {
  selectedFiles.value.splice(index, 1)
}

async function startRecording() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    const mediaRecorder = new MediaRecorder(stream)
    const chunks = []
    mediaRecorder.ondataavailable = (e) => e.data.size && chunks.push(e.data)
    mediaRecorder.onstop = () => {
      stream.getTracks().forEach((t) => t.stop())
      recordedBlob.value = new Blob(chunks, { type: 'audio/webm' })
    }
    mediaRecorder.start()
    mediaRecorderRef.value = mediaRecorder
    isRecording.value = true
  } catch (err) {
    console.error('Mic access denied:', err)
  }
}

function stopRecording() {
  if (mediaRecorderRef.value?.state === 'recording') {
    mediaRecorderRef.value.stop()
    mediaRecorderRef.value = null
  }
  isRecording.value = false
}

function cancelRecording() {
  stopRecording()
  recordedBlob.value = null
}

function clearRecordedVoice() {
  recordedBlob.value = null
}
</script>

<template>
  <div class="chat-page">
    <!-- Sidebar -->
    <aside class="sidebar" :class="{ open: sidebarOpen }">
      <div class="sidebar-header">
        <button class="sidebar-new" @click="startNewChat" :disabled="sending">
          + New chat
        </button>
        <button class="sidebar-close" @click="sidebarOpen = false" aria-label="Close">×</button>
      </div>
      <div class="chat-list">
        <button
          v-for="chat in chats"
          :key="chat.id"
          class="chat-item"
          :class="{ active: currentChat?.id === chat.id }"
          @click="selectChat(chat.id)"
        >
          <span class="chat-item-title">{{ chat.title || 'New chat' }}</span>
          <span class="chat-item-model" v-if="chat.model_name">{{ chat.model_name }}</span>
        </button>
        <p v-if="chats.length === 0" class="chat-list-empty">No conversations yet</p>
      </div>
      <div class="sidebar-user-wrapper">
        <button class="sidebar-user" @click="toggleUserDropdown">
          <img
            v-if="user?.avatar_url"
            :src="user.avatar_url"
            alt=""
            class="sidebar-user-avatar"
          />
          <div v-else class="sidebar-user-avatar sidebar-user-avatar-placeholder">
            {{ (user?.name || user?.email || 'U').charAt(0).toUpperCase() }}
          </div>
          <div class="sidebar-user-info">
            <span class="sidebar-user-name">{{ user?.name || 'User' }}</span>
            <span class="sidebar-user-plan">
              {{ getPlanLabel() }}<template v-if="credits !== null"> · {{ formatCredits(credits) }} credits</template>
            </span>
          </div>
        </button>
        <div v-show="showUserDropdown" class="sidebar-user-dropdown">
          <button class="sidebar-user-dropdown-item" @click="handleUserMenuClick('/profile')">
            Profile
          </button>
          <button class="sidebar-user-dropdown-item" @click="handleUserMenuClick('/upgrade')">
            Upgrade plan
          </button>
          <button class="sidebar-user-dropdown-item" @click="handleUserMenuClick('/models')">
            Models
          </button>
          <button class="sidebar-user-dropdown-item" @click="handleUserMenuClick('/settings')">
            Settings
          </button>
          <button v-if="isAdmin" class="sidebar-user-dropdown-item" @click="handleUserMenuClick('/admin')">
            Admin
          </button>
        </div>
      </div>
    </aside>

    <!-- Overlay (mobile) -->
    <div v-if="sidebarOpen" class="sidebar-overlay" @click="sidebarOpen = false"></div>

    <!-- Main -->
    <main class="chat-main">
      <header class="chat-header">
        <button class="menu-btn" @click="toggleSidebar" aria-label="Menu">☰</button>
        <button class="back-btn" @click="goHome">← Home</button>
        <div class="model-selector">
          <button
            v-for="model in models"
            :key="model.id"
            class="model-pill"
            :class="{ active: selectedModel?.id === model.id, unavailable: !model.available }"
            :style="{ '--pill-color': getProviderColor(model.provider) }"
            :disabled="!model.available || sending"
            :title="model.available ? model.name : `${model.name}: coming soon`"
            @click="selectedModel = model"
          >
            <span class="model-pill-provider">{{ model.provider }}</span>
            <span class="model-pill-name">{{ model.name }}</span>
          </button>
        </div>
      </header>

      <div class="messages-area">
        <div v-if="!currentChat && messages.length === 0" class="welcome">
          <h2>Start a conversation</h2>
          <p>Choose a model above and type your first message.</p>
          <p class="welcome-models">
            Models from OpenAI (GPT-4), Anthropic (Claude), Google (Gemini), and more.
          </p>
        </div>
        <template v-for="(msg, i) in messages" :key="i">
          <div class="message" :class="msg.role">
          <div class="message-avatar">
            <span v-if="msg.role === 'user'">U</span>
            <span v-else class="avatar-model">{{ msg.model_name?.[0] || 'A' }}</span>
          </div>
          <div class="message-content">
            <div v-if="msg.role === 'assistant' && msg.model_name" class="message-label">
              {{ msg.model_name }}
            </div>
            <div v-if="msg.streaming && !msg.content" class="message-text message-thinking">Thinking…</div>
            <div v-else class="message-text">{{ msg.content }}</div>
          </div>
          </div>
        </template>
        <div ref="messagesEndRef"></div>
      </div>

      <div class="input-area">
        <input
          ref="fileInputRef"
          type="file"
          multiple
          class="file-input-hidden"
          @change="onFileChange"
        />
        <div v-if="selectedFiles.length > 0 || recordedBlob" class="attachments-bar">
          <div v-for="(file, i) in selectedFiles" :key="`file-${i}`" class="attachment-chip">
            <span class="attachment-name">{{ file.name }}</span>
            <button type="button" class="attachment-remove" @click="removeFile(i)" aria-label="Remove">×</button>
          </div>
          <div v-if="recordedBlob" class="attachment-chip attachment-voice">
            <span class="attachment-name">Voice recording</span>
            <button type="button" class="attachment-remove" @click="clearRecordedVoice" aria-label="Remove">×</button>
          </div>
        </div>
        <div v-if="isRecording" class="recording-bar">
          <span class="recording-dot"></span>
          <span>Recording...</span>
          <button type="button" class="recording-stop" @click="stopRecording">Stop</button>
          <button type="button" class="recording-cancel" @click="cancelRecording">Cancel</button>
        </div>
        <div class="input-wrap">
          <!-- Disabled until files and audio are really sent to the model (roadmap B5, B6). -->
          <button
            class="input-icon-btn"
            @click="triggerFileSelect"
            type="button"
            disabled
            title="Attaching files is coming soon"
            aria-label="Attach files (coming soon)"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
            </svg>
          </button>
          <button
            v-if="!isRecording"
            class="input-icon-btn"
            @click="startRecording"
            type="button"
            disabled
            title="Voice messages are coming soon"
            aria-label="Record voice (coming soon)"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z" />
              <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
              <line x1="12" y1="19" x2="12" y2="23" />
              <line x1="8" y1="23" x2="16" y2="23" />
            </svg>
          </button>
          <button
            v-else
            class="input-icon-btn input-icon-btn-recording"
            @click="stopRecording"
            type="button"
            title="Stop recording"
            aria-label="Stop recording"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
              <rect x="6" y="6" width="12" height="12" rx="2" />
            </svg>
          </button>
          <textarea
            v-model="inputText"
            placeholder="Message..."
            rows="1"
            @keydown.enter.exact.prevent="sendMessage"
          />
          <button v-if="sending" class="send-btn stop-btn" @click="stopReply" type="button">
            Stop
          </button>
          <button
            v-else
            class="send-btn"
            @click="sendMessage"
            :disabled="!inputText.trim() || !selectedModel"
          >
            Send
          </button>
        </div>
        <p v-if="errorText" class="input-error" role="alert">
          {{ errorText }}
          <router-link v-if="outOfCredits" to="/upgrade" class="input-error-link">Buy credits</router-link>
        </p>
        <p v-else-if="!models.some((m) => m.available)" class="input-error">
          No AI models are connected yet.
        </p>
        <p v-else class="input-hint">Press Enter to send, Shift+Enter for a new line.</p>
      </div>
    </main>
  </div>
</template>

<style scoped>
.chat-page {
  display: flex;
  /* Fixed to the window so the chat list and messages scroll inside it,
     instead of the whole page growing with the number of chats. */
  height: 100vh;
  height: 100dvh;
  overflow: hidden;
  background: #0d1117;
}

.sidebar {
  width: 260px;
  flex-shrink: 0;
  background: #161b22;
  border-right: 1px solid #21262d;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.sidebar-header {
  padding: 1rem;
  display: flex;
  gap: 0.5rem;
  border-bottom: 1px solid #21262d;
}

.sidebar-new {
  flex: 1;
  padding: 0.5rem 1rem;
  background: #58a6ff;
  color: #0d1117;
  border: none;
  border-radius: 6px;
  font-weight: 600;
  cursor: pointer;
}

.sidebar-new:hover:not(:disabled) {
  background: #79b8ff;
}

.sidebar-new:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.sidebar-close {
  display: none;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  color: #8b949e;
  font-size: 1.5rem;
  cursor: pointer;
}

.chat-list {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
}

.chat-item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  width: 100%;
  padding: 0.75rem 1rem;
  background: none;
  border: none;
  border-radius: 8px;
  color: #c9d1d9;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s;
}

.chat-item:hover {
  background: #21262d;
}

.chat-item.active {
  background: #21262d;
  color: #58a6ff;
}

.chat-item-title {
  font-size: 0.9375rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 100%;
}

.chat-item-model {
  font-size: 0.75rem;
  color: #8b949e;
  margin-top: 0.25rem;
}

.chat-list-empty {
  padding: 2rem 1rem;
  color: #8b949e;
  font-size: 0.875rem;
}

.sidebar-user-wrapper {
  position: relative;
  border-top: 1px solid #21262d;
  background: #0d1117;
}

.sidebar-user {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 1rem;
  background: none;
  border: none;
  cursor: pointer;
  text-align: left;
  transition: background 0.2s;
}

.sidebar-user:hover {
  background: rgba(255, 255, 255, 0.05);
}

.sidebar-user-dropdown {
  position: absolute;
  bottom: 100%;
  left: 0;
  right: 0;
  margin-bottom: 0.25rem;
  padding: 0.25rem;
  background: #161b22;
  border: 1px solid #21262d;
  border-radius: 8px;
  box-shadow: 0 -4px 20px rgba(0, 0, 0, 0.4);
}

.sidebar-user-dropdown-item {
  display: block;
  width: 100%;
  padding: 0.5rem 1rem;
  background: none;
  border: none;
  border-radius: 6px;
  color: #c9d1d9;
  font-size: 0.9375rem;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s;
}

.sidebar-user-dropdown-item:hover {
  background: #21262d;
}

.sidebar-user-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  object-fit: cover;
  flex-shrink: 0;
}

.sidebar-user-avatar-placeholder {
  display: flex;
  align-items: center;
  justify-content: center;
  background: #58a6ff;
  color: #0d1117;
  font-size: 1rem;
  font-weight: 600;
}

.sidebar-user-info {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.sidebar-user-name {
  font-size: 0.9375rem;
  font-weight: 500;
  color: #c9d1d9;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sidebar-user-plan {
  font-size: 0.75rem;
  color: #8b949e;
}

.chat-main {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
}

.chat-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem 1rem;
  background: #161b22;
  border-bottom: 1px solid #21262d;
}

.menu-btn {
  display: none;
  width: 40px;
  height: 40px;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  color: #c9d1d9;
  font-size: 1.25rem;
  cursor: pointer;
}

.back-btn {
  padding: 0.5rem 0.75rem;
  background: transparent;
  border: 1px solid #21262d;
  border-radius: 6px;
  color: #c9d1d9;
  font-size: 0.875rem;
  cursor: pointer;
}

.back-btn:hover {
  border-color: #8b949e;
}

.model-selector {
  flex: 1;
  display: flex;
  gap: 0.5rem;
  overflow-x: auto;
  padding: 0.25rem 0;
  scrollbar-width: thin;
}

.model-pill {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.875rem;
  background: #21262d;
  border: 1px solid transparent;
  border-radius: 20px;
  color: #c9d1d9;
  font-size: 0.8125rem;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s;
}

.model-pill:hover {
  background: #30363d;
}

.model-pill.active {
  border-color: var(--pill-color);
  color: var(--pill-color);
}

.model-pill-provider {
  font-weight: 600;
}

.model-pill-name {
  opacity: 0.9;
}

.messages-area {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 1.5rem;
  max-width: 48rem;
  margin: 0 auto;
  width: 100%;
  display: flex;
  flex-direction: column;
}

.welcome {
  text-align: center;
  padding: 4rem 2rem;
}

.welcome h2 {
  font-size: 1.5rem;
  color: #c9d1d9;
  margin-bottom: 0.5rem;
}

.welcome p {
  color: #8b949e;
  font-size: 0.9375rem;
}

.welcome-models {
  margin-top: 1rem;
  font-size: 0.8125rem;
}

.message {
  display: flex;
  gap: 1rem;
  margin-bottom: 1.5rem;
  max-width: 85%;
}

.message.assistant {
  align-self: flex-start;
}

.message.user {
  align-self: flex-end;
  flex-direction: row-reverse;
}

.message-avatar {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: #21262d;
  border-radius: 50%;
  font-size: 0.875rem;
  font-weight: 600;
  color: #58a6ff;
}

.message.user .message-avatar {
  background: #58a6ff;
  color: #0d1117;
}

.avatar-model {
  font-size: 0.75rem;
}

.message-content {
  flex: 1;
  min-width: 0;
}

.message.user .message-content {
  text-align: right;
}

.message.user .message-text {
  background: #21262d;
  padding: 0.75rem 1rem;
  border-radius: 12px 12px 4px 12px;
}

.message.assistant .message-text {
  background: rgba(88, 166, 255, 0.08);
  padding: 0.75rem 1rem;
  border-radius: 12px 12px 12px 4px;
}

.message-label {
  font-size: 0.75rem;
  color: #8b949e;
  margin-bottom: 0.25rem;
}

.message-text {
  font-size: 0.9375rem;
  line-height: 1.6;
  color: #c9d1d9;
  white-space: pre-wrap;
  word-break: break-word;
}

.file-input-hidden {
  position: absolute;
  width: 0;
  height: 0;
  opacity: 0;
  pointer-events: none;
}

.attachments-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  max-width: 48rem;
  margin: 0 auto 0.5rem;
}

.attachment-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.35rem 0.75rem;
  background: #21262d;
  border: 1px solid #30363d;
  border-radius: 8px;
  font-size: 0.8125rem;
  color: #c9d1d9;
}

.attachment-name {
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attachment-remove {
  padding: 0 0.15rem;
  background: none;
  border: none;
  color: #8b949e;
  font-size: 1.1rem;
  cursor: pointer;
  line-height: 1;
}

.attachment-remove:hover {
  color: #f87171;
}

.attachment-voice {
  border-color: #58a6ff;
  color: #58a6ff;
}

.recording-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  max-width: 48rem;
  margin: 0 auto 0.5rem;
  padding: 0.5rem 1rem;
  background: rgba(239, 68, 68, 0.15);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: 8px;
  color: #fca5a5;
  font-size: 0.875rem;
}

.recording-dot {
  width: 8px;
  height: 8px;
  background: #ef4444;
  border-radius: 50%;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}

.recording-stop {
  padding: 0.25rem 0.75rem;
  background: #ef4444;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 0.8125rem;
  cursor: pointer;
}

.recording-stop:hover {
  background: #dc2626;
}

.recording-cancel {
  padding: 0.25rem 0.75rem;
  background: transparent;
  border: 1px solid rgba(239, 68, 68, 0.5);
  border-radius: 6px;
  color: #fca5a5;
  font-size: 0.8125rem;
  cursor: pointer;
}

.recording-cancel:hover {
  background: rgba(239, 68, 68, 0.2);
}

.input-area {
  padding: 1rem 1.5rem 2rem;
  background: #161b22;
  border-top: 1px solid #21262d;
}

.input-wrap {
  display: flex;
  align-items: flex-end;
  gap: 0.5rem;
  max-width: 48rem;
  margin: 0 auto;
  background: #21262d;
  border: 1px solid #30363d;
  border-radius: 12px;
  padding: 0.5rem 0.75rem 0.5rem 1rem;
}

.input-icon-btn {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  border-radius: 8px;
  color: #8b949e;
  cursor: pointer;
  transition: color 0.2s, background 0.2s;
}

.input-icon-btn:hover {
  color: #58a6ff;
  background: rgba(88, 166, 255, 0.1);
}

.input-icon-btn-recording {
  color: #ef4444;
  background: rgba(239, 68, 68, 0.15);
}

.input-icon-btn-recording:hover {
  color: #f87171;
  background: rgba(239, 68, 68, 0.25);
}

.input-wrap textarea {
  flex: 1;
  min-height: 36px;
  max-height: 200px;
  padding: 0.4rem 0;
  background: none;
  border: none;
  color: #c9d1d9;
  font-size: 0.9375rem;
  font-family: inherit;
  resize: none;
  outline: none;
}

.input-wrap textarea::placeholder {
  color: #8b949e;
}

.send-btn {
  flex-shrink: 0;
  padding: 0.5rem 1.25rem;
  background: #58a6ff;
  color: #0d1117;
  border: none;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  cursor: pointer;
}

.send-btn:hover:not(:disabled) {
  background: #79b8ff;
}

.send-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.model-pill.unavailable,
.model-pill:disabled:not(.active) {
  opacity: 0.4;
  cursor: not-allowed;
}

.input-icon-btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}

.stop-btn {
  background: #30363d;
  color: #f0f6fc;
}

.send-btn.stop-btn:hover:not(:disabled) {
  background: #484f58;
}

.message-thinking {
  color: #8b949e;
  font-style: italic;
}

.input-error-link {
  color: #a5b4fc;
  margin-left: 0.375rem;
  font-weight: 500;
}

.input-error {
  margin: 0.5rem 0 0;
  font-size: 0.8rem;
  color: #f85149;
  text-align: center;
}

.input-hint {
  font-size: 0.75rem;
  color: #8b949e;
  text-align: center;
  margin-top: 0.5rem;
}

.sidebar-overlay {
  display: none;
}

@media (max-width: 768px) {
  .sidebar {
    position: fixed;
    left: 0;
    top: 0;
    bottom: 0;
    z-index: 100;
    transform: translateX(-100%);
    transition: transform 0.2s;
  }

  .sidebar.open {
    transform: translateX(0);
  }

  .sidebar-close {
    display: flex;
  }

  .menu-btn {
    display: flex;
  }

  .sidebar-overlay {
    display: block;
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 99;
  }

  .model-selector {
    padding-bottom: 0.5rem;
  }
}
</style>
