<script setup>
defineProps({ title: { type: String, required: true }, subtitle: { type: String, default: '' } })
</script>

<template>
  <div class="auth-page">
    <div class="auth-card">
      <router-link to="/" class="brand">CognitiveAI Bot</router-link>
      <h1>{{ title }}</h1>
      <p v-if="subtitle" class="subtitle">{{ subtitle }}</p>
      <slot />
    </div>
  </div>
</template>

<style scoped>
.auth-page { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 2rem 1rem; }
.auth-card {
  width: 100%;
  max-width: 26rem;
  padding: 2.25rem 2rem;
  background: rgba(30, 41, 59, 0.6);
  border: 1px solid rgba(148, 163, 184, 0.1);
  border-radius: 16px;
}
.brand { display: inline-block; color: #a5b4fc; text-decoration: none; font-weight: 600; margin-bottom: 1.25rem; }
h1 { font-size: 1.5rem; font-weight: 700; color: #f1f5f9; margin-bottom: 0.5rem; }
.subtitle { color: #94a3b8; font-size: 0.9375rem; line-height: 1.5; margin-bottom: 1.5rem; }
:slotted(form) { display: flex; flex-direction: column; gap: 1rem; }
:slotted(label) { display: flex; flex-direction: column; gap: 0.375rem; color: #cbd5e1; font-size: 0.875rem; }
:slotted(input) {
  padding: 0.7rem 0.875rem;
  background: rgba(15, 23, 42, 0.8);
  border: 1px solid rgba(148, 163, 184, 0.25);
  border-radius: 10px;
  color: #f1f5f9;
  font: inherit;
}
:slotted(.btn) {
  padding: 0.75rem 1rem;
  border: none;
  border-radius: 10px;
  background: #6366f1;
  color: white;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  text-align: center;
  text-decoration: none;
}
:slotted(.btn:disabled) { opacity: 0.6; cursor: not-allowed; }
:slotted(.ok) { color: #86efac; line-height: 1.5; }
:slotted(.err) { color: #fca5a5; line-height: 1.5; }
:slotted(.links) { margin-top: 1.25rem; font-size: 0.875rem; color: #94a3b8; }
:slotted(.links a) { color: #a5b4fc; }
</style>
