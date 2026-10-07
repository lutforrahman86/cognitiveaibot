import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

const auth = vi.hoisted(() => ({ resetPassword: vi.fn(), clearToken: vi.fn() }))
const route = vi.hoisted(() => ({ query: { token: 'tok_123' } }))
vi.mock('../api/auth', () => auth)
vi.mock('vue-router', () => ({ useRoute: () => route }))

import ResetPassword from './ResetPassword.vue'

const mountPage = () => mount(ResetPassword, { global: { stubs: { 'router-link': { template: '<a><slot /></a>' } } } })

describe('Reset password page', () => {
  beforeEach(() => {
    auth.resetPassword.mockReset()
    auth.clearToken.mockReset()
    route.query = { token: 'tok_123' }
  })

  it('refuses two different passwords without calling the server', async () => {
    const wrapper = mountPage()
    const [a, b] = wrapper.findAll('input')
    await a.setValue('first-password')
    await b.setValue('second-password')
    await wrapper.find('form').trigger('submit')
    expect(wrapper.find('[role="alert"]').text()).toContain('don’t match')
    expect(auth.resetPassword).not.toHaveBeenCalled()
  })

  it('sets the password with the link’s token, then signs this browser out', async () => {
    auth.resetPassword.mockResolvedValue({ ok: true })
    const wrapper = mountPage()
    for (const input of wrapper.findAll('input')) await input.setValue('a-good-password')
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(auth.resetPassword).toHaveBeenCalledWith('tok_123', 'a-good-password')
    expect(auth.clearToken).toHaveBeenCalled()
    expect(wrapper.text()).toContain('signed out everywhere')
  })

  it('offers a new link when the token has expired', async () => {
    auth.resetPassword.mockRejectedValue(new Error('This reset link is invalid or has expired. Ask for a new one.'))
    const wrapper = mountPage()
    for (const input of wrapper.findAll('input')) await input.setValue('a-good-password')
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(wrapper.find('[role="alert"]').text()).toContain('Send a new link')
  })

  it('explains a link with no token instead of showing the form', () => {
    route.query = {}
    const wrapper = mountPage()
    expect(wrapper.find('form').exists()).toBe(false)
    expect(wrapper.text()).toContain('missing its code')
  })
})
