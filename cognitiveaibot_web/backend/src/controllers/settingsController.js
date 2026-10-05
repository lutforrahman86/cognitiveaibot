const { UserSettings } = require('../models/UserSettings');

async function get(req, res) {
  try {
    const settings = await UserSettings.findByUserId(req.user.id);
    res.json({ settings });
  } catch (err) {
    console.error('get settings:', err);
    res.status(500).json({ error: 'Failed to fetch settings' });
  }
}

async function update(req, res) {
  try {
    const settings = await UserSettings.upsert(req.user.id, req.body);
    res.json({ settings });
  } catch (err) {
    console.error('update settings:', err);
    res.status(500).json({ error: 'Failed to update settings' });
  }
}

module.exports = { get, update };
