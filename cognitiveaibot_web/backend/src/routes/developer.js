/**
 * The developer dashboard's backend (roadmap C1, C4), for signed-in users:
 *
 *   GET    /api/developer             API access, base URL and keys
 *   POST   /api/developer/keys        { name } → the new key, shown once
 *   DELETE /api/developer/keys/:id    revoke a key
 *   GET    /api/developer/usage       API usage by day, model and key
 */
const express = require('express');
const { QueryTypes } = require('sequelize');
const { authMiddleware } = require('../middleware/auth');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const { toCredits } = require('../gateway/metering');
const keys = require('../api/keys');

const router = express.Router();
router.use(authMiddleware);

function respond(label, fn) {
  return async (req, res) => {
    try {
      res.json(await fn(req, res));
    } catch (err) {
      if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
      console.error(`developer ${label}:`, err);
      res.status(500).json({ error: `Failed to ${label}` });
    }
  };
}

const baseUrl = (req) => `${(process.env.API_URL || `${req.protocol}://${req.get('host')}`).replace(/\/$/, '')}/v1`;

router.get(
  '/',
  respond('load the developer dashboard', async (req) => {
    const access = await keys.apiAccess(req.user.id);
    return {
      access: access
        ? {
            plan: access.plan.name,
            requests_per_minute: access.limits.requestsPerMinute,
            tokens_per_minute: access.limits.tokensPerMinute,
          }
        : null,
      base_url: baseUrl(req),
      keys: await keys.listKeys(req.user.id),
    };
  })
);

router.post(
  '/keys',
  respond('create the key', async (req, res) => {
    res.status(201);
    return { key: await keys.createKey(req.user.id, req.body?.name) };
  })
);

router.delete(
  '/keys/:id',
  respond('revoke the key', async (req, res) => {
    if (!(await keys.revokeKey(req.user.id, req.params.id))) {
      throw new GatewayError('KEY_NOT_FOUND', 'Key not found.', { status: 404 });
    }
    return { revoked: true };
  })
);

router.get(
  '/usage',
  respond('load API usage', async (req) => {
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 90);
    const replacements = { userId: req.user.id, days };
    const where = `r.user_id = :userId AND r.source = 'api' AND r.created_at >= now() - (:days * interval '1 day')`;
    const totals = `count(*)::int AS requests,
                    count(*) FILTER (WHERE r.status = 'failed')::int AS failed,
                    COALESCE(sum(r.input_tokens), 0)::bigint AS input_tokens,
                    COALESCE(sum(r.output_tokens), 0)::bigint AS output_tokens,
                    COALESCE(sum(r.charged_micros), 0)::bigint AS charged_micros`;
    const q = (sql) => sequelize.query(sql, { replacements, type: QueryTypes.SELECT });
    const [[summary], byDay, byModel, byKey] = await Promise.all([
      q(`SELECT ${totals} FROM request_logs r WHERE ${where}`),
      q(`SELECT to_char(date_trunc('day', r.created_at), 'YYYY-MM-DD') AS day, ${totals}
           FROM request_logs r WHERE ${where} GROUP BY 1 ORDER BY 1 DESC`),
      q(`SELECT m.slug AS model, m.name, ${totals}
           FROM request_logs r LEFT JOIN ai_models m ON m.id = r.model_id
          WHERE ${where} GROUP BY m.slug, m.name ORDER BY charged_micros DESC`),
      q(`SELECT k.id, k.name, k.prefix, k.revoked_at, ${totals}
           FROM request_logs r LEFT JOIN api_keys k ON k.id = r.api_key_id
          WHERE ${where} GROUP BY k.id, k.name, k.prefix, k.revoked_at ORDER BY charged_micros DESC`),
    ]);
    const shape = ({ charged_micros: charged, input_tokens: input, output_tokens: output, ...rest }) => ({
      ...rest,
      input_tokens: Number(input),
      output_tokens: Number(output),
      credits: toCredits(charged),
    });
    return {
      days,
      totals: shape(summary),
      by_day: byDay.map(shape),
      by_model: byModel.map(shape),
      by_key: byKey.map(shape),
    };
  })
);

module.exports = router;
