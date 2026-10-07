import { createRouter, createWebHistory } from 'vue-router'
import { isAuthenticated, getMe } from '../api/auth'
import LandingPage from '../components/LandingPage.vue'
import SignIn from '../views/SignIn.vue'
import SignUp from '../views/SignUp.vue'
import AuthCallback from '../views/AuthCallback.vue'
import Chat from '../views/Chat.vue'
import Models from '../views/Models.vue'
import Settings from '../views/Settings.vue'
import Profile from '../views/Profile.vue'
import Upgrade from '../views/Upgrade.vue'
import AdminDashboard from '../views/AdminDashboard.vue'
import Developers from '../views/Developers.vue'
import ApiDocs from '../views/ApiDocs.vue'
import Usage from '../views/Usage.vue'

const routes = [
  { path: '/', name: 'Home', component: LandingPage },
  { path: '/signin', name: 'SignIn', component: SignIn },
  { path: '/signup', name: 'SignUp', component: SignUp },
  { path: '/auth/callback', name: 'AuthCallback', component: AuthCallback },
  { path: '/chat', name: 'Chat', component: Chat },
  { path: '/models', name: 'Models', component: Models },
  { path: '/settings', name: 'Settings', component: Settings },
  { path: '/profile', name: 'Profile', component: Profile },
  { path: '/upgrade', name: 'Upgrade', component: Upgrade },
  { path: '/admin', name: 'Admin', component: AdminDashboard },
  { path: '/developers', name: 'Developers', component: Developers },
  { path: '/docs/api', name: 'ApiDocs', component: ApiDocs },
  { path: '/usage', name: 'Usage', component: Usage },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (to.path === '/' && isAuthenticated()) {
    const user = await getMe()
    if (user?.type === 'admin') {
      return '/admin'
    }
  }
})

export default router
