/**
 * Renders a model's reply as Markdown: headings, lists, tables, links and
 * code blocks with syntax highlighting and a Copy button.
 *
 * Model output is untrusted, so the HTML always goes through DOMPurify:
 * scripts, event handlers, iframes and javascript: links are removed, and
 * links open in a new tab without access to this page.
 */
import { Marked } from 'marked'
import DOMPurify from 'dompurify'
import hljs from 'highlight.js/lib/common'

const escapeHtml = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')

const marked = new Marked({
  gfm: true,
  breaks: true,
  renderer: {
    code({ text, lang }) {
      const language = (lang || '').trim().split(/\s+/)[0]
      const known = language && hljs.getLanguage(language)
      const body = known
        ? hljs.highlight(text, { language, ignoreIllegals: true }).value
        : escapeHtml(text)
      return (
        '<div class="code-block">' +
        `<div class="code-head"><span>${escapeHtml(known ? language : language || 'text')}</span>` +
        '<button type="button" class="code-copy">Copy</button></div>' +
        `<pre><code class="hljs">${body}</code></pre></div>`
      )
    },
  },
})

let hooked = false
function sanitize(html) {
  if (!hooked) {
    DOMPurify.addHook('afterSanitizeAttributes', (node) => {
      if (node.tagName === 'A') {
        node.setAttribute('target', '_blank')
        node.setAttribute('rel', 'noopener noreferrer nofollow')
      }
    })
    hooked = true
  }
  return DOMPurify.sanitize(html, { FORBID_TAGS: ['style', 'form', 'input'], FORBID_ATTR: ['style'] })
}

/** Safe HTML for a reply. Unfinished Markdown while streaming renders as far as it goes. */
export function renderMarkdown(text) {
  return sanitize(marked.parse(text || ''))
}
