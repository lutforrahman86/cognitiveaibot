const Subscription = require('../models/Subscription');

async function get(req, res) {
  try {
    const subscription = await Subscription.findByUserId(req.user.id);
    res.json({
      subscription: subscription
        ? {
            product_id: subscription.product_id,
            status: subscription.status,
            started_at: subscription.started_at,
            expires_at: subscription.expires_at,
          }
        : null,
      hasPro: await Subscription.hasProAccess(req.user.id),
    });
  } catch (err) {
    console.error('get subscription:', err);
    res.status(500).json({ error: 'Failed to fetch subscription' });
  }
}

async function checkPro(req, res) {
  try {
    const hasPro = await Subscription.hasProAccess(req.user.id);
    res.json({ hasPro });
  } catch (err) {
    console.error('checkPro:', err);
    res.status(500).json({ error: 'Failed to check Pro status' });
  }
}

module.exports = { get, checkPro };
