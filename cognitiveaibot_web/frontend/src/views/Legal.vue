<script setup>
import { computed } from 'vue'
import { DOCUMENTS, UPDATED } from '../legal/documents'

const props = defineProps({ doc: { type: String, required: true } })
const document = computed(() => DOCUMENTS[props.doc])
</script>

<template>
  <div class="page">
    <router-link to="/" class="back-link">← CognitiveAI Bot</router-link>
    <p class="draft" role="note">Draft: not yet reviewed by a lawyer. Placeholders in [brackets] are still to be filled in.</p>
    <h1>{{ document.title }}</h1>
    <p class="updated">Last updated: {{ UPDATED }}</p>
    <section v-for="s in document.sections" :key="s.heading">
      <h2>{{ s.heading }}</h2>
      <template v-for="(p, i) in s.body" :key="i">
        <ul v-if="Array.isArray(p)">
          <li v-for="item in p" :key="item">{{ item }}</li>
        </ul>
        <p v-else>{{ p }}</p>
      </template>
    </section>
    <nav class="other">
      <router-link to="/terms">Terms of Service</router-link>
      <router-link to="/privacy">Privacy Policy</router-link>
      <router-link to="/acceptable-use">Acceptable Use Policy</router-link>
    </nav>
  </div>
</template>

<style scoped>
.page { min-height: 100vh; padding: 2.5rem 1rem 5rem; max-width: 46rem; margin: 0 auto; color: #cbd5e1; line-height: 1.65; }
.back-link { display: inline-block; color: #94a3b8; text-decoration: none; margin-bottom: 1.5rem; }
.draft {
  padding: 0.625rem 0.875rem;
  border-radius: 10px;
  background: rgba(245, 158, 11, 0.1);
  border: 1px solid rgba(245, 158, 11, 0.35);
  color: #fcd34d;
  font-size: 0.875rem;
  margin-bottom: 1.5rem;
}
h1 { font-size: 1.875rem; font-weight: 700; color: #f1f5f9; }
.updated { color: #64748b; font-size: 0.875rem; margin-bottom: 2rem; }
h2 { font-size: 1.125rem; font-weight: 600; color: #f1f5f9; margin: 1.75rem 0 0.5rem; }
p { margin-bottom: 0.75rem; }
ul { padding-left: 1.25rem; margin-bottom: 0.75rem; display: flex; flex-direction: column; gap: 0.375rem; }
.other { display: flex; gap: 1.25rem; flex-wrap: wrap; margin-top: 3rem; padding-top: 1rem; border-top: 1px solid rgba(148, 163, 184, 0.12); }
.other a { color: #a5b4fc; font-size: 0.9375rem; }
</style>
