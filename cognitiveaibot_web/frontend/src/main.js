import { createApp } from 'vue'
import './style.css'
// Colours for highlighted code in replies.
import 'highlight.js/styles/github-dark.css'
import App from './App.vue'
import router from './router'

createApp(App).use(router).mount('#app')
