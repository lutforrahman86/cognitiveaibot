const AIModel = require('../models/AIModel');
const { availability } = require('../gateway');
const { getProvider, PROVIDER_NAMES } = require('../gateway/providers');
const { cached } = require('../services/cache');

// The public model list changes only when an admin edits a model (which
// clears this cache) or a provider key changes (a restart).
const MODEL_LIST_TTL_SECONDS = 60;

async function list(req, res) {
  try {
    // Chat models by default; ?kind=image (embedding, speech, transcription,
    // video) or ?kind=all for the others.
    const { category, provider, search, kind = 'chat' } = req.query;
    // Which provider keys are set decides availability, so it's part of the key.
    const keysSet = PROVIDER_NAMES.filter((name) => getProvider(name).apiKey).join(',');
    const key = `models:${JSON.stringify([category, provider, search, kind, keysSet])}`;
    const body = await cached(key, MODEL_LIST_TTL_SECONDS, async () => {
      const models = await AIModel.findAll({ category, provider, search, apiKind: kind === 'all' ? undefined : kind });
      // `available` tells clients which models can be called right now.
      // The reason stays server-side: it reveals which provider keys are set.
      return { models: models.map((m) => ({ ...m, available: availability(m).available })) };
    });
    res.json(body);
  } catch (err) {
    console.error('list models:', err);
    res.status(500).json({ error: 'Failed to fetch models' });
  }
}

async function getById(req, res) {
  try {
    const model = await AIModel.findById(req.params.id);
    if (!model) {
      return res.status(404).json({ error: 'Model not found' });
    }
    res.json({ model });
  } catch (err) {
    console.error('getById:', err);
    res.status(500).json({ error: 'Failed to fetch model' });
  }
}

async function getBySlug(req, res) {
  try {
    const model = await AIModel.findBySlug(req.params.slug);
    if (!model) {
      return res.status(404).json({ error: 'Model not found' });
    }
    res.json({ model });
  } catch (err) {
    console.error('getBySlug:', err);
    res.status(500).json({ error: 'Failed to fetch model' });
  }
}

module.exports = { list, getById, getBySlug };
