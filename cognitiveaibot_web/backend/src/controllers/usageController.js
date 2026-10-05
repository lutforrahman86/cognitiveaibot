const UsageRecord = require('../models/UsageRecord');
const UsageLimit = require('../models/UsageLimit');

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

module.exports = { getDashboard, getRecords };
