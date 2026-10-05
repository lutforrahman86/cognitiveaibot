import { describe, it, expect } from 'vitest'
import { renderMarkdown } from './markdown'

const render = (md) => {
  const div = document.createElement('div')
  div.innerHTML = renderMarkdown(md)
  return div
}

describe('renderMarkdown', () => {
  it('renders Markdown: headings, lists, emphasis, tables and inline code', () => {
    const div = render('# Title\n\n- **one**\n- two\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nUse `npm test`.')
    expect(div.querySelector('h1').textContent).toBe('Title')
    expect(div.querySelectorAll('li')).toHaveLength(2)
    expect(div.querySelector('strong').textContent).toBe('one')
    expect(div.querySelector('table td').textContent).toBe('1')
    expect(div.querySelector('p code').textContent).toBe('npm test')
  })

  it('highlights code blocks and gives each a Copy button', () => {
    const div = render('```js\nconst x = 1\n```')
    const block = div.querySelector('.code-block')
    expect(block.querySelector('.code-head span').textContent).toBe('js')
    expect(block.querySelector('button.code-copy').textContent).toBe('Copy')
    expect(block.querySelector('pre code').textContent).toBe('const x = 1')
    expect(block.querySelector('pre code .hljs-keyword').textContent).toBe('const')
  })

  it('shows code in an unknown language as plain, escaped text', () => {
    const div = render('```nosuchlang\n<b>not bold</b>\n```')
    expect(div.querySelector('pre code').textContent).toBe('<b>not bold</b>')
    expect(div.querySelector('pre code b')).toBeNull()
  })

  it('removes anything that could run script, whatever the model writes', () => {
    const div = render(
      '<script>window.pwned = 1</script>\n\n<img src=x onerror="window.pwned = 1">\n\n' +
        '[click](javascript:window.pwned=1)\n\n<iframe src="https://evil.test"></iframe>\n\n<a href="#" onclick="x()">a</a>'
    )
    expect(div.querySelector('script')).toBeNull()
    expect(div.querySelector('iframe')).toBeNull()
    expect(div.querySelector('img').getAttribute('onerror')).toBeNull()
    expect(div.querySelector('a[onclick]')).toBeNull()
    for (const a of div.querySelectorAll('a')) expect(a.getAttribute('href') || '').not.toMatch(/^javascript:/i)
  })

  it('opens links in a new tab without access to this page', () => {
    const a = render('[docs](https://example.com)').querySelector('a')
    expect(a.getAttribute('href')).toBe('https://example.com')
    expect(a.getAttribute('target')).toBe('_blank')
    expect(a.getAttribute('rel')).toContain('noopener')
  })
})
