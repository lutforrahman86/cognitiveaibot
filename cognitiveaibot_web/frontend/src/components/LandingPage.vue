<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { isAuthenticated, clearToken, getMe } from '../api/auth'
import { checkIsAdmin } from '../api/admin'

const router = useRouter()
const loggedIn = ref(false)
const showUserMenu = ref(false)
const user = ref(null)
const isAdmin = ref(false)

function goToSignIn() {
  router.push('/signin')
}

function signOut() {
  clearToken()
  user.value = null
  loggedIn.value = false
  showUserMenu.value = false
}

async function toggleUserMenu() {
  showUserMenu.value = !showUserMenu.value
  if (showUserMenu.value && loggedIn.value && !user.value) {
    user.value = await getMe()
    isAdmin.value = await checkIsAdmin()
  }
}

function closeUserMenu() {
  showUserMenu.value = false
}

function handleClickOutside(e) {
  if (showUserMenu.value && !e.target.closest('.user-menu-wrapper')) {
    closeUserMenu()
  }
}

function navigateAndClose(path) {
  router.push(path)
  closeUserMenu()
}

onMounted(async () => {
  loggedIn.value = isAuthenticated()
  if (loggedIn.value) {
    user.value = await getMe()
    isAdmin.value = await checkIsAdmin()
  }
  document.addEventListener('click', handleClickOutside)
})
onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})
</script>

<template>
  <div class="landing">
    <!-- Navigation -->
    <nav class="nav">
      <div class="nav-inner">
        <a href="#" class="logo">
          <span class="logo-icon">◇</span>
          <span class="logo-text">CognitiveAI Bot</span>
        </a>
        <div class="nav-links">
          <a href="#features">Features</a>
          <a href="#pricing">Pricing</a>
          <a href="#cta">Contact</a>
          <div v-if="loggedIn" class="user-menu-wrapper">
            <button class="user-icon-btn" @click="toggleUserMenu" aria-label="User menu">
              <svg class="user-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
                <circle cx="12" cy="7" r="4" />
              </svg>
            </button>
            <div v-show="showUserMenu" class="user-dropdown">
              <div class="user-dropdown-header">
                <div class="user-dropdown-name">{{ user?.name || 'User' }}</div>
                <div class="user-dropdown-email">{{ user?.email || '' }}</div>
              </div>
              <div class="user-dropdown-divider"></div>
              <button class="user-dropdown-item" @click="navigateAndClose('/chat')">
                Chat
              </button>
              <button class="user-dropdown-item" @click="navigateAndClose('/models')">
                Models
              </button>
              <button class="user-dropdown-item" @click="navigateAndClose('/settings')">
                Settings
              </button>
              <button v-if="isAdmin" class="user-dropdown-item" @click="navigateAndClose('/admin')">
                Admin
              </button>
              <div class="user-dropdown-divider"></div>
              <button class="user-dropdown-item user-dropdown-item-logout" @click="signOut">
                Logout
              </button>
            </div>
          </div>
          <button v-else class="nav-cta" @click="goToSignIn">Get Started</button>
        </div>
      </div>
    </nav>

    <!-- Hero Section -->
    <header class="hero">
      <div class="hero-bg">
        <div class="gradient-orb gradient-orb-1"></div>
        <div class="gradient-orb gradient-orb-2"></div>
        <div class="grid-pattern"></div>
      </div>
      <div class="hero-content">
        <span class="hero-badge">Intelligent Conversations</span>
        <h1 class="hero-title">
          AI that understands
          <span class="gradient-text">your context</span>
        </h1>
        <p class="hero-subtitle">
          CognitiveAI Bot brings natural, context-aware conversations to your applications.
          Powered by advanced language models for smarter, more relevant responses.
        </p>
        <div class="hero-actions">
          <button class="btn btn-primary" @click="goToSignIn">Start chatting</button>
          <button class="btn btn-secondary">See how it works</button>
        </div>
      </div>
    </header>

    <!-- Features Section -->
    <section id="features" class="features">
      <div class="section-header">
        <h2 class="section-title">Why CognitiveAI Bot</h2>
        <p class="section-subtitle">
          Built for developers who need intelligent, reliable AI interactions
        </p>
      </div>
      <div class="features-grid">
        <article class="feature-card">
          <div class="feature-icon">💬</div>
          <h3>Context-Aware</h3>
          <p>Maintains conversation context for natural, coherent multi-turn dialogues that feel human.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">⚡</div>
          <h3>Fast & Responsive</h3>
          <p>Optimized inference for low latency. Get answers in milliseconds, not seconds.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">🔒</div>
          <h3>Secure by Design</h3>
          <p>Your data stays yours. Enterprise-grade security with optional on-premise deployment.</p>
        </article>
        <article class="feature-card">
          <div class="feature-icon">🔌</div>
          <h3>Easy Integration</h3>
          <p>RESTful API and webhooks. Integrate into any stack with minimal code.</p>
        </article>
      </div>
    </section>

    <!-- Pricing Section -->
    <section id="pricing" class="pricing">
      <div class="section-header">
        <h2 class="section-title">Pricing</h2>
        <p class="section-subtitle">
          Simple, transparent pricing. Scale as you grow.
        </p>
      </div>
      <div class="pricing-grid">
        <article class="pricing-card">
          <h3>Starter</h3>
          <div class="price">
            <span class="price-amount">$0</span>
            <span class="price-period">/month</span>
          </div>
          <p class="pricing-desc">Perfect for trying out and small projects</p>
          <ul class="pricing-features">
            <li>1,000 messages/month</li>
            <li>Basic context window</li>
            <li>Community support</li>
          </ul>
          <button class="btn btn-secondary" @click="goToSignIn">Get started</button>
        </article>
        <article class="pricing-card pricing-card-featured">
          <span class="popular-badge">Most popular</span>
          <h3>Pro</h3>
          <div class="price">
            <span class="price-amount">$29</span>
            <span class="price-period">/month</span>
          </div>
          <p class="pricing-desc">For growing teams and production apps</p>
          <ul class="pricing-features">
            <li>50,000 messages/month</li>
            <li>Extended context</li>
            <li>Priority support</li>
            <li>Custom integrations</li>
          </ul>
          <button class="btn btn-primary" @click="goToSignIn">Start free trial</button>
        </article>
        <article class="pricing-card">
          <h3>Enterprise</h3>
          <div class="price">
            <span class="price-amount">Custom</span>
          </div>
          <p class="pricing-desc">For large teams with advanced needs</p>
          <ul class="pricing-features">
            <li>Unlimited messages</li>
            <li>On-premise deployment</li>
            <li>Dedicated support</li>
            <li>SLA & custom contracts</li>
          </ul>
          <button class="btn btn-secondary">Contact sales</button>
        </article>
      </div>
    </section>

    <!-- CTA Section -->
    <section id="cta" class="cta">
      <div class="cta-card">
        <h2>Ready to build something intelligent?</h2>
        <p>Join developers using CognitiveAI Bot to power their applications.</p>
        <button class="btn btn-primary btn-lg" @click="goToSignIn">Get started free</button>
      </div>
    </section>

    <!-- Footer -->
    <footer class="footer">
      <div class="footer-inner">
        <div class="footer-brand">
          <span class="logo-icon">◇</span>
          <span>CognitiveAI Bot</span>
        </div>
        <div class="footer-links">
          <a href="#">Documentation</a>
          <a href="#">API Reference</a>
          <a href="#">GitHub</a>
          <a href="#">Contact</a>
        </div>
        <p class="footer-copy">© 2025 CognitiveAI Bot. Built with Vue.js</p>
      </div>
    </footer>
  </div>
</template>

<style scoped>
.landing {
  min-height: 100vh;
}

/* Navigation */
.nav {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 100;
  padding: 1rem 2rem;
  background: rgba(15, 23, 42, 0.7);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(148, 163, 184, 0.08);
}

.nav-inner {
  max-width: 72rem;
  margin: 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.logo {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  text-decoration: none;
  color: #f1f5f9;
  font-weight: 600;
  font-size: 1.125rem;
}

.logo-icon {
  color: #6366f1;
  font-size: 1.25rem;
}

.nav-links {
  display: flex;
  align-items: center;
  gap: 2rem;
}

.nav-links a {
  color: #94a3b8;
  text-decoration: none;
  font-size: 0.9375rem;
  transition: color 0.2s;
}

.nav-links a:hover {
  color: #f1f5f9;
}

.nav-cta {
  padding: 0.5rem 1.25rem;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.9375rem;
  font-weight: 500;
  cursor: pointer;
  transition: opacity 0.2s;
}

.nav-cta:hover {
  opacity: 0.9;
}

.user-menu-wrapper {
  position: relative;
}

.user-icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  padding: 0;
  background: rgba(99, 102, 241, 0.2);
  border: 1px solid rgba(99, 102, 241, 0.4);
  border-radius: 50%;
  color: #a5b4fc;
  cursor: pointer;
  transition: background 0.2s, border-color 0.2s;
}

.user-icon-btn:hover {
  background: rgba(99, 102, 241, 0.3);
  border-color: rgba(99, 102, 241, 0.5);
}

.user-icon {
  width: 22px;
  height: 22px;
}

.user-dropdown {
  position: absolute;
  top: calc(100% + 0.5rem);
  right: 0;
  min-width: 220px;
  padding: 0.5rem;
  background: rgba(30, 41, 59, 0.98);
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.4);
}

.user-dropdown-header {
  padding: 0.5rem 0.75rem 0.25rem;
}

.user-dropdown-name {
  font-size: 0.9375rem;
  font-weight: 600;
  color: #f1f5f9;
}

.user-dropdown-email {
  font-size: 0.8125rem;
  color: #94a3b8;
  margin-top: 0.125rem;
}

.user-dropdown-divider {
  height: 1px;
  margin: 0.375rem 0;
  background: rgba(148, 163, 184, 0.15);
}

.user-dropdown-item {
  display: block;
  width: 100%;
  padding: 0.5rem 0.75rem;
  background: none;
  border: none;
  border-radius: 6px;
  color: #e2e8f0;
  font-size: 0.9375rem;
  text-align: left;
  cursor: pointer;
  transition: background 0.2s;
}

.user-dropdown-item:hover {
  background: rgba(148, 163, 184, 0.15);
}

.user-dropdown-item-logout {
  color: #f87171;
}

.user-dropdown-item-logout:hover {
  background: rgba(239, 68, 68, 0.15);
}

/* Hero */
.hero {
  position: relative;
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8rem 2rem 4rem;
  overflow: hidden;
}

.hero-bg {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.gradient-orb {
  position: absolute;
  width: 600px;
  height: 600px;
  border-radius: 50%;
  filter: blur(120px);
  opacity: 0.25;
}

.gradient-orb-1 {
  top: -200px;
  right: -200px;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%);
}

.gradient-orb-2 {
  bottom: -200px;
  left: -200px;
  background: linear-gradient(315deg, #06b6d4 0%, #6366f1 50%);
}

.grid-pattern {
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(148, 163, 184, 0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(148, 163, 184, 0.03) 1px, transparent 1px);
  background-size: 60px 60px;
}

.hero-content {
  position: relative;
  max-width: 48rem;
  text-align: center;
}

.hero-badge {
  display: inline-block;
  padding: 0.375rem 0.875rem;
  background: rgba(99, 102, 241, 0.15);
  border: 1px solid rgba(99, 102, 241, 0.3);
  border-radius: 9999px;
  color: #a5b4fc;
  font-size: 0.8125rem;
  font-weight: 500;
  margin-bottom: 1.5rem;
  letter-spacing: 0.02em;
}

.hero-title {
  font-size: clamp(2.5rem, 5vw, 4rem);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.02em;
  color: #f1f5f9;
  margin: 0 0 1.5rem 0;
}

.gradient-text {
  background: linear-gradient(135deg, #6366f1 0%, #a78bfa 50%, #c084fc 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.hero-subtitle {
  font-size: 1.25rem;
  color: #94a3b8;
  line-height: 1.6;
  margin: 0 0 2rem 0;
  max-width: 36rem;
  margin-left: auto;
  margin-right: auto;
}

.hero-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
  flex-wrap: wrap;
}

.btn {
  padding: 0.875rem 1.75rem;
  border-radius: 10px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.btn-primary {
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  color: white;
}

.btn-primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 10px 40px -10px rgba(99, 102, 241, 0.5);
}

.btn-secondary {
  background: rgba(148, 163, 184, 0.1);
  color: #f1f5f9;
  border: 1px solid rgba(148, 163, 184, 0.2);
}

.btn-secondary:hover {
  background: rgba(148, 163, 184, 0.15);
  border-color: rgba(148, 163, 184, 0.3);
}

.btn-lg {
  padding: 1rem 2rem;
  font-size: 1.0625rem;
}

/* Features */
.features {
  padding: 6rem 2rem;
  max-width: 72rem;
  margin: 0 auto;
}

.section-header {
  text-align: center;
  margin-bottom: 4rem;
}

.section-title {
  font-size: 2.25rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 0.75rem 0;
  letter-spacing: -0.02em;
}

.section-subtitle {
  font-size: 1.125rem;
  color: #64748b;
  margin: 0;
}

.features-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
}

.feature-card {
  padding: 2rem;
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(148, 163, 184, 0.08);
  border-radius: 16px;
  transition: all 0.2s;
}

.feature-card:hover {
  border-color: rgba(99, 102, 241, 0.2);
  background: rgba(30, 41, 59, 0.7);
  transform: translateY(-2px);
}

.feature-icon {
  font-size: 2rem;
  margin-bottom: 1rem;
}

.feature-card h3 {
  font-size: 1.25rem;
  font-weight: 600;
  color: #f1f5f9;
  margin: 0 0 0.5rem 0;
}

.feature-card p {
  font-size: 0.9375rem;
  color: #94a3b8;
  line-height: 1.6;
  margin: 0;
}

/* Pricing */
.pricing {
  padding: 6rem 2rem;
  max-width: 72rem;
  margin: 0 auto;
}

.pricing-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 1.5rem;
  align-items: stretch;
}

.pricing-card {
  position: relative;
  padding: 2rem;
  background: rgba(30, 41, 59, 0.5);
  border: 1px solid rgba(148, 163, 184, 0.08);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  transition: all 0.2s;
}

.pricing-card:hover {
  border-color: rgba(148, 163, 184, 0.15);
  transform: translateY(-2px);
}

.pricing-card-featured {
  border-color: rgba(99, 102, 241, 0.3);
  background: rgba(30, 41, 59, 0.7);
}

.pricing-card-featured:hover {
  border-color: rgba(99, 102, 241, 0.4);
}

.popular-badge {
  position: absolute;
  top: -10px;
  left: 50%;
  transform: translateX(-50%);
  padding: 0.25rem 0.75rem;
  background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 600;
  color: white;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.pricing-card h3 {
  font-size: 1.25rem;
  font-weight: 600;
  color: #f1f5f9;
  margin: 0 0 1rem 0;
}

.price {
  margin-bottom: 0.5rem;
}

.price-amount {
  font-size: 2rem;
  font-weight: 700;
  color: #f1f5f9;
}

.price-period {
  font-size: 1rem;
  font-weight: 400;
  color: #94a3b8;
}

.pricing-desc {
  font-size: 0.9375rem;
  color: #94a3b8;
  margin: 0 0 1.5rem 0;
  line-height: 1.5;
}

.pricing-features {
  list-style: none;
  margin: 0 0 1.5rem 0;
  padding: 0;
  flex: 1;
}

.pricing-features li {
  font-size: 0.9375rem;
  color: #cbd5e1;
  padding: 0.375rem 0;
  padding-left: 1.5rem;
  position: relative;
}

.pricing-features li::before {
  content: "✓";
  position: absolute;
  left: 0;
  color: #6366f1;
  font-weight: 600;
}

.pricing-card .btn {
  margin-top: auto;
  width: 100%;
}

/* CTA */
.cta {
  padding: 0 2rem 6rem;
}

.cta-card {
  max-width: 48rem;
  margin: 0 auto;
  padding: 4rem;
  background: linear-gradient(135deg, rgba(99, 102, 241, 0.15) 0%, rgba(139, 92, 246, 0.1) 100%);
  border: 1px solid rgba(99, 102, 241, 0.2);
  border-radius: 24px;
  text-align: center;
}

.cta-card h2 {
  font-size: 2rem;
  font-weight: 700;
  color: #f1f5f9;
  margin: 0 0 0.75rem 0;
}

.cta-card p {
  font-size: 1.125rem;
  color: #94a3b8;
  margin: 0 0 2rem 0;
}

/* Footer */
.footer {
  padding: 3rem 2rem;
  border-top: 1px solid rgba(148, 163, 184, 0.08);
}

.footer-inner {
  max-width: 72rem;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
  text-align: center;
}

.footer-brand {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #94a3b8;
  font-weight: 500;
}

.footer-brand .logo-icon {
  color: #6366f1;
}

.footer-links {
  display: flex;
  gap: 2rem;
}

.footer-links a {
  color: #64748b;
  text-decoration: none;
  font-size: 0.875rem;
  transition: color 0.2s;
}

.footer-links a:hover {
  color: #94a3b8;
}

.footer-copy {
  font-size: 0.8125rem;
  color: #475569;
  margin: 0;
}
</style>
