const AIModel = require('../models/AIModel');
const { availability } = require('../gateway');

async function list(req, res) {
  try {
    const { category, provider, search } = req.query;
    const models = await AIModel.findAll({ category, provider, search });
    // `available` tells clients which models can be chatted with right now.
    // The reason stays server-side: it reveals which provider keys are set.
    res.json({ models: models.map((m) => ({ ...m, available: availability(m).available })) });
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
