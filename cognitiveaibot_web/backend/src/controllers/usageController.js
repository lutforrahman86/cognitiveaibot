const UsageRecord = require('../models/UsageRecord');
const UsageLimit = require('../models/UsageLimit');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { toCredits } = require('../gateway/metering');

function getDefaultDateRange(days = 30) {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - days);
  return {
    startDate: start.toISOString().slice(0, 10),
    endDate: end.toISOString().slice(0, 10),
  };
}

async function getDashboard(req, res) {
  try {
    const { startDate, endDate, days = 30 } = req.query;
    const range = startDate && endDate
      ? { startDate, endDate }
      : getDefaultDateRange(parseInt(days, 10));
    const userId = req.user.id;

    const [totals, dailyTotals, modelBreakdown, limit] = await Promise.all([
      UsageRecord.getTotals(userId, range.startDate, range.endDate),
      UsageRecord.getDailyTotals(userId, 7),
      UsageRecord.getModelBreakdown(userId, 30),
      UsageLimit.findByUserId(userId),
    ]);

    const totalCost = parseFloat(totals.total_cost || 0);
    const limitAmount = parseFloat(limit.limit_amount || 16);
    const limitPercent = limitAmount > 0 ? Math.min(100, Math.round((totalCost / limitAmount) * 100)) : 0;

    res.json({
      totals: {
        cost: totalCost,
        tokens: Number(totals.total_tokens || 0),
        limit_amount: limitAmount,
        limit_percent: limitPercent,
      },
      daily: dailyTotals.map((d) => ({
        date: d.record_date,
        tokens: Number(d.tokens || 0),
        cost: parseFloat(d.cost || 0),
      })),
      modelBreakdown: modelBreakdown.map((m) => ({
        name: m.name,
        provider: m.provider,
        total_cost: parseFloat(m.total_cost || 0),
        total_tokens: Number(m.total_tokens || 0),
      })),
    });
  } catch (err) {
    console.error('getDashboard:', err);
    res.status(500).json({ error: 'Failed to fetch usage dashboard' });
  }
}

/**
 * GET /api/usage/summary?days=30 — what the user's calls cost in credits,
 * from the request log (app and API together): totals, by day and by model.
 */
async function getSummary(req, res) {
  try {
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 90);
    const replacements = { userId: req.user.id, days };
    const where = `r.user_id = :userId AND r.status <> 'in_progress' AND r.created_at >= now() - (:days * interval '1 day')`;
    const totals = `count(*)::int AS requests,
                    count(*) FILTER (WHERE r.source = 'api')::int AS api_requests,
                    COALESCE(sum(r.input_tokens), 0)::bigint AS input_tokens,
                    COALESCE(sum(r.output_tokens), 0)::bigint AS output_tokens,
                    COALESCE(sum(r.charged_micros), 0)::bigint AS charged_micros`;
    const q = (sql) => sequelize.query(sql, { replacements, type: QueryTypes.SELECT });
    const [[summary], byDay, byModel] = await Promise.all([
      q(`SELECT ${totals} FROM request_logs r WHERE ${where}`),
      q(`SELECT to_char(date_trunc('day', r.created_at), 'YYYY-MM-DD') AS day, ${totals}
           FROM request_logs r WHERE ${where} GROUP BY 1 ORDER BY 1 DESC`),
      q(`SELECT m.slug AS model, m.name, m.provider, m.api_kind, ${totals}
           FROM request_logs r LEFT JOIN ai_models m ON m.id = r.model_id
          WHERE ${where} GROUP BY m.slug, m.name, m.provider, m.api_kind ORDER BY charged_micros DESC`),
    ]);
    const shape = ({ charged_micros: charged, input_tokens: input, output_tokens: output, ...rest }) => ({
      ...rest,
      input_tokens: Number(input),
      output_tokens: Number(output),
      credits: toCredits(charged),
    });
    res.json({ days, totals: shape(summary), by_day: byDay.map(shape), by_model: byModel.map(shape) });
  } catch (err) {
    console.error('usage summary:', err);
    res.status(500).json({ error: 'Failed to load usage' });
  }
}

async function getRecords(req, res) {
  try {
    const { startDate, endDate, limit } = req.query;
    const records = await UsageRecord.findByUserId(req.user.id, {
      startDate,
      endDate,
      limit: limit ? parseInt(limit, 10) : 30,
    });
    res.json({ records });
  } catch (err) {
    console.error('getRecords:', err);
    res.status(500).json({ error: 'Failed to fetch usage records' });
  }
}

module.exports = { getDashboard, getRecords, getSummary };
