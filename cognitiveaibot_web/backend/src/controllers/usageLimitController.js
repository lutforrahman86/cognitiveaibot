const UsageLimit = require('../models/UsageLimit');

async function get(req, res) {
  try {
    const limit = await UsageLimit.findByUserId(req.user.id);
    res.json({
      limit_amount: parseFloat(limit.limit_amount || 16),
      limit_period: limit.limit_period || 'monthly',
    });
  } catch (err) {
    console.error('get usage limit:', err);
    res.status(500).json({ error: 'Failed to fetch usage limit' });
  }
}

async function update(req, res) {
  try {
    const { limit_amount, limit_period } = req.body;
    const limit = await UsageLimit.upsert(req.user.id, { limit_amount, limit_period });
    res.json({
      limit_amount: parseFloat(limit.limit_amount),
      limit_period: limit.limit_period,
    });
  } catch (err) {
    console.error('update usage limit:', err);
    res.status(500).json({ error: 'Failed to update usage limit' });
  }
}

module.exports = { get, update };
