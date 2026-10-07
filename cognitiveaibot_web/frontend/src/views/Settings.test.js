import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'

const api = vi.hoisted(() => ({
  getSettings: vi.fn(),
  updateSettings: vi.fn(),
}))
vi.mock('../api/chat', () => api)
vi.mock('../api/auth', () => ({ isAuthenticated: () => true }))
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }))

import Settings from './Settings.vue'

const saved = {
  font_size: 'medium',
  enter_to_send: true,
  show_timestamps: true,
  system_prompt: 'Be brief.',
  temperature: null,
}

const mountPage = async () => {
  const wrapper = mount(Settings, { global: { stubs: { 'router-link': true } } })
  await flushPromises()
  return wrapper
}

describe('Settings page', () => {
  beforeEach(() => {
    api.getSettings.mockResolvedValue({ ...saved })
    api.updateSettings.mockImplementation(async (changes) => ({ ...saved, ...changes }))
  })

  it('shows the saved settings, with an unset temperature as empty (the model’s default)', async () => {
    const wrapper = await mountPage()
    expect(wrapper.find('textarea').element.value).toBe('Be brief.')
    expect(wrapper.find('input[type="number"]').element.value).toBe('')
    expect(wrapper.find('select').element.value).toBe('medium')
  })

  it('saves only the settings it shows, sending no temperature unless one is set', async () => {
    const wrapper = await mountPage()
    await wrapper.find('select').setValue('large')
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(api.updateSettings).toHaveBeenCalledWith({
      font_size: 'large',
      enter_to_send: true,
      show_timestamps: true,
      system_prompt: 'Be brief.',
      temperature: null,
    })
    expect(wrapper.text()).toContain('Saved.')

    await wrapper.find('input[type="number"]').setValue('0.4')
    await wrapper.find('textarea').setValue('   ')
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(api.updateSettings).toHaveBeenLastCalledWith(expect.objectContaining({ temperature: 0.4, system_prompt: null }))
  })

  it('shows the server’s error when a save is refused', async () => {
    api.updateSettings.mockRejectedValueOnce(new Error('temperature must be from 0 to 2'))
    const wrapper = await mountPage()
    await wrapper.find('form').trigger('submit')
    await flushPromises()
    expect(wrapper.find('[role="alert"]').text()).toContain('temperature must be from 0 to 2')
  })
})
