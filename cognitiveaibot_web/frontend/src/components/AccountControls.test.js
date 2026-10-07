import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

const auth = vi.hoisted(() => ({ changePassword: vi.fn(), downloadMyData: vi.fn(), deleteAccount: vi.fn() }))
const push = vi.hoisted(() => vi.fn())
vi.mock('../api/auth', () => auth)
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }))

import AccountControls from './AccountControls.vue'

const mountIt = () => mount(AccountControls, { props: { email: 'me@example.test' } })
const button = (wrapper, text) => wrapper.findAll('button').find((b) => b.text().includes(text))

describe('Account controls', () => {
  beforeEach(() => vi.clearAllMocks())

  it('only deletes after the account is confirmed, then leaves the app', async () => {
    auth.deleteAccount.mockResolvedValue()
    const wrapper = mountIt()
    expect(wrapper.find('#confirm-delete').exists()).toBe(false)
    await button(wrapper, 'Delete my account…').trigger('click')
    await wrapper.find('#confirm-delete').setValue('my-password')
    await wrapper.find('#confirm-delete').element.form.dispatchEvent(new Event('submit'))
    await flushPromises()
    expect(auth.deleteAccount).toHaveBeenCalledWith('my-password')
    expect(push).toHaveBeenCalledWith('/?account=deleted')
  })

  it('keeps the user on the page when the confirmation is wrong', async () => {
    auth.deleteAccount.mockRejectedValue(new Error('That password isn’t right.'))
    const wrapper = mountIt()
    await button(wrapper, 'Delete my account…').trigger('click')
    await wrapper.find('#confirm-delete').setValue('nope')
    await wrapper.find('#confirm-delete').element.form.dispatchEvent(new Event('submit'))
    await flushPromises()
    expect(wrapper.text()).toContain('That password isn’t right.')
    expect(push).not.toHaveBeenCalled()
  })

  it('checks the new password is typed twice the same before changing it', async () => {
    const wrapper = mountIt()
    const [current, next, confirm] = wrapper.findAll('form')[0].findAll('input')
    await current.setValue('old-password')
    await next.setValue('new-password-1')
    await confirm.setValue('new-password-2')
    await wrapper.findAll('form')[0].trigger('submit')
    expect(auth.changePassword).not.toHaveBeenCalled()
    await confirm.setValue('new-password-1')
    auth.changePassword.mockResolvedValue({ ok: true })
    await wrapper.findAll('form')[0].trigger('submit')
    await flushPromises()
    expect(auth.changePassword).toHaveBeenCalledWith('old-password', 'new-password-1')
    expect(wrapper.text()).toContain('other devices have been signed out')
  })
})
