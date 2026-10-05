/**
 * Prompt moderation (roadmap E5), with OpenAI's free moderation model,
 * called directly with OpenAI's key like every other model.
 *
 * Two policies:
 *   - chat (app and API): blocks only sexual content involving minors; the
 *     chat models apply their own safety rules to everything else.
 *   - media (image and video prompts): also blocks sexual content, graphic
 *     violence, hateful threats, self-harm instructions and violent wrongdoing,
 *     since generated images and video are what app stores scrutinise.
 * A prompt touching minors is always reported to admins as an alert.
 *
 * If moderation can't run (no OpenAI key, or OpenAI is down), chat goes
 * ahead and media is refused: a missed check on an image or video is the
 * costlier mistake. MODERATION=off disables it entirely (e.g. for tests).
 */
const { getProvider } = require('./providers');
const { GatewayError } = require('./errors');

const MODEL = 'omni-moderation-latest';
const BLOCKED = {
  chat: ['sexual/minors'],
  media: ['sexual/minors', 'sexual', 'violence/graphic', 'hate/threatening', 'self-harm/instructions', 'illicit/violent'],
};

async function classify(text) {
  const provider = getProvider('OpenAI');
  if (!provider?.apiKey) return null;
  const res = await fetch(`${provider.baseUrl}/moderations`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${provider.apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: MODEL, input: text.slice(0, 100_000) }),
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`moderation HTTP ${res.status}`);
  const [result] = (await res.json()).results;
  return Object.entries(result.categories || {}).filter(([, on]) => on).map(([name]) => name);
}

/**
 * Checks a prompt under `policy` ('chat' or 'media'). Throws CONTENT_BLOCKED
 * (400) when it breaks the policy. `onSerious` is called for anything an
 * admin must see.
 */
async function checkPrompt(text, policy, { onSerious } = {}) {
  if (process.env.MODERATION === 'off' || !text) return;
  let flagged;
  try {
    flagged = await classify(text);
  } catch (err) {
    console.error('[moderation] unavailable:', err.message);
    flagged = null;
  }
  if (flagged === null) {
    if (policy === 'media') {
      throw new GatewayError('MODERATION_UNAVAILABLE', 'Image and video requests are paused for a moment. Try again shortly.', {
        status: 503,
      });
    }
    return;
  }
  if (flagged.includes('sexual/minors') && onSerious) {
    await Promise.resolve(onSerious(flagged)).catch((err) => console.error('[moderation] alert failed:', err.message));
  }
  const hits = flagged.filter((c) => BLOCKED[policy].includes(c));
  if (hits.length) {
    const err = new GatewayError('CONTENT_BLOCKED', 'This request breaks the content rules, so it wasn’t sent.', { status: 400 });
    err.categories = hits;
    throw err;
  }
}

module.exports = { checkPrompt, BLOCKED };
