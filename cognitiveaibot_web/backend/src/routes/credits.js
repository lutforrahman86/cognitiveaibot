const express = require('express');
const { QueryTypes } = require('sequelize');
const { authMiddleware } = require('../middleware/auth');
const { sequelize } = require('../config/database');
const { getBalance, toCredits } = require('../gateway/metering');

const router = express.Router();
router.use(authMiddleware);

/** GET /api/credits — the caller's balance and recent credit movements. */
router.get('/', async (req, res) => {
  try {
    const balance = await getBalance(req.user.id);
    const rows = await sequelize.query(
      `SELECT id, type, amount_micros, balance_after_micros, reason, created_at
         FROM credit_transactions WHERE user_id = :userId
        ORDER BY created_at DESC LIMIT 20`,
      { replacements: { userId: req.user.id }, type: QueryTypes.SELECT }
    );
    res.json({
      ...balance,
      transactions: rows.map((t) => ({
        id: t.id,
        type: t.type,
        amount: toCredits(t.amount_micros),
        balance_after: toCredits(t.balance_after_micros),
        reason: t.reason,
        created_at: t.created_at,
      })),
    });
  } catch (err) {
    console.error('credits:', err);
    res.status(500).json({ error: 'Failed to fetch credits' });
  }
});

module.exports = router;
