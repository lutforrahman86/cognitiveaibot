const AIModel = require('../models/AIModel');

function toSlug(str) {
  if (!str || typeof str !== 'string') return '';
  return str
    .toLowerCase()
    .replace(/^models\//, '')
    .replace(/\./g, '-')
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '');
}

async function fetchOpenAIModels() {
  const key = process.env.OPENAI_API_KEY;
  if (!key) return { provider: 'OpenAI', models: [], error: 'OPENAI_API_KEY not configured' };

  try {
    const res = await fetch('https://api.openai.com/v1/models', {
      headers: { Authorization: `Bearer ${key}` },
    });
    if (!res.ok) {
      const err = await res.text();
      return { provider: 'OpenAI', models: [], error: `API error: ${res.status} ${err}` };
    }
    const data = await res.json();
    const models = (data.data || [])
      .filter((m) => m.id && !m.id.startsWith('gpt-3.5'))
      .map((m) => ({
        provider: 'OpenAI',
        id: m.id,
        slug: toSlug(m.id),
        name: m.id,
      }));
    return { provider: 'OpenAI', models };
  } catch (err) {
    return { provider: 'OpenAI', models: [], error: err.message };
  }
}

async function fetchGeminiModels() {
  const key = process.env.GEMINI_API_KEY || process.env.GOOGLE_AI_API_KEY;
  if (!key) return { provider: 'Google', models: [], error: 'GEMINI_API_KEY not configured' };

  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${key}&pageSize=100`
    );
    if (!res.ok) {
      const err = await res.text();
      return { provider: 'Google', models: [], error: `API error: ${res.status} ${err}` };
    }
    const data = await res.json();
    const models = (data.models || [])
      .filter((m) => m.name && m.name.startsWith('models/'))
      .map((m) => ({
        provider: 'Google',
        id: m.name,
        slug: toSlug(m.name.replace(/^models\//, '')),
        name: m.displayName || m.name.replace(/^models\//, ''),
      }));
    return { provider: 'Google', models };
  } catch (err) {
    return { provider: 'Google', models: [], error: err.message };
  }
}

async function checkForNewModels() {
  const dbModels = await AIModel.findAll({ includeInactive: true });
  const existingSlugs = new Set(dbModels.map((m) => m.slug?.toLowerCase()));

  const [openaiResult, geminiResult] = await Promise.all([
    fetchOpenAIModels(),
    // fetchGeminiModels(),
  ]);

  const results = [openaiResult, geminiResult].filter(Boolean);
  const newModels = [];
  const checkedProviders = [];
  const errors = [];

  for (const r of results) {
    if (!r) continue;
    if (r.error) {
      errors.push({ provider: r.provider, message: r.error });
    } else {
      checkedProviders.push(r.provider);
      for (const m of r.models) {
        const slug = m.slug?.toLowerCase();
        if (slug && !existingSlugs.has(slug)) {
          newModels.push({
            provider: m.provider,
            id: m.id,
            slug: m.slug,
            name: m.name,
          });
          existingSlugs.add(slug);
        }
      }
    }
  }

  return {
    newModels,
    checkedProviders,
    errors,
    totalNew: newModels.length,
  };
}

module.exports = { checkForNewModels };
