const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { GatewayError } = require('../gateway/errors');
const { createReport } = require('../admin/reports');

const router = express.Router();
router.use(authMiddleware);

/** POST /api/reports { message_id, reason, details } — flag a model reply for review. */
router.post('/', async (req, res) => {
  try {
    res.status(201).json({ report: await createReport(req.user.id, req.body) });
  } catch (err) {
    if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
    console.error('report:', err);
    res.status(500).json({ error: 'Couldn’t send the report. Try again.' });
  }
});

module.exports = router;
