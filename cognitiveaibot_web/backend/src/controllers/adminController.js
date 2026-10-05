const User = require('../models/User');
const AIModel = require('../models/AIModel');
const Subscription = require('../models/Subscription');
const UsageRecord = require('../models/UsageRecord');
const { checkForNewModels } = require('../services/modelChecker');
const plans = require('../billing/plans');
const { logAdminAction, listAdminActions } = require('../admin/audit');
const modelAdmin = require('../admin/models');
const { invalidate } = require('../services/cache');
const reports = require('../admin/reports');
const alerts = require('../admin/alerts');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { availability, metering, GatewayError, CREDIT_USD_VALUE } = require('../gateway');

const micros = (v) => metering.toCredits(v || 0);

async function checkAdmin(req, res) {
  res.json({ isAdmin: req.user?.type === 'admin' });
}

async function getDashboard(req, res) {
  try {
    const [userCount, subCount, usageTotals, models, subscriptions] = await Promise.all([
      User.getCount(),
      Subscription.count(),
      UsageRecord.getAdminTotals(30),
      AIModel.findAll({ includeInactive: true }),
      Subscription.findAllWithUsers({ limit: 10 }),
    ]);

    const dashboard = {
      users: {
        total: userCount,
      },
      subscriptions: {
        total: subCount ?? 0,
        recent: subscriptions,
      },
      usage: {
        total_cost: parseFloat(usageTotals.total_cost || 0),
        total_tokens: parseInt(usageTotals.total_tokens || 0, 10),
      },
      models: models.length,
      modelsList: models,
    };

    res.json(dashboard);
  } catch (err) {
    console.error('admin dashboard:', err);
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
}

async function getUsers(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const offset = parseInt(req.query.offset, 10) || 0;
    const [users, total] = await Promise.all([
      User.findAll({ limit, offset }),
      User.getCount(),
    ]);
    const balances = users.length
      ? await sequelize.query(
          'SELECT user_id, balance_micros, held_micros FROM credit_accounts WHERE user_id IN (:ids)',
          { replacements: { ids: users.map((u) => u.id) }, type: QueryTypes.SELECT }
        )
      : [];
    const byUser = new Map(balances.map((b) => [b.user_id, b]));
    res.json({
      users: users.map((u) => {
        const b = byUser.get(u.id);
        return { ...u, credits: b ? micros(b.balance_micros) : 0, credits_held: b ? micros(b.held_micros) : 0 };
      }),
      total,
    });
  } catch (err) {
    console.error('admin users:', err);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
}

async function getSubscriptions(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
    const subscriptions = await Subscription.findAllWithUsers({ limit });
    res.json({ subscriptions });
  } catch (err) {
    console.error('admin subscriptions:', err);
    res.status(500).json({ error: 'Failed to fetch subscriptions' });
  }
}

async function getUsage(req, res) {
  try {
    const days = Math.min(parseInt(req.query.days, 10) || 30, 90);
    const [totals, daily, byModel, margin, marginByModel] = await Promise.all([
      UsageRecord.getAdminTotals(days),
      UsageRecord.getAdminDailyTotals(Math.min(days, 14)),
      UsageRecord.getAdminModelBreakdown(days),
      sequelize.query(
        `SELECT count(*)::int AS requests,
                count(*) FILTER (WHERE status = 'succeeded')::int AS succeeded,
                count(*) FILTER (WHERE status = 'failed')::int AS failed,
                count(*) FILTER (WHERE status = 'cancelled')::int AS cancelled,
                count(*) FILTER (WHERE usage_estimated)::int AS estimated,
                COALESCE(sum(cost_usd_micros), 0) AS cost_usd_micros,
                COALESCE(sum(charged_micros), 0) AS charged_micros,
                COALESCE(sum(unbilled_micros), 0) AS unbilled_micros
           FROM request_logs WHERE created_at >= now() - (:days * interval '1 day')`,
        { replacements: { days }, type: QueryTypes.SELECT }
      ),
      sequelize.query(
        `SELECT m.name, m.provider, r.route, count(*)::int AS requests,
                COALESCE(sum(r.cost_usd_micros), 0) AS cost_usd_micros,
                COALESCE(sum(r.charged_micros), 0) AS charged_micros,
                COALESCE(sum(r.unbilled_micros), 0) AS unbilled_micros
           FROM request_logs r LEFT JOIN ai_models m ON m.id = r.model_id
          WHERE r.created_at >= now() - (:days * interval '1 day')
          GROUP BY m.name, m.provider, r.route ORDER BY sum(r.charged_micros) DESC NULLS LAST`,
        { replacements: { days }, type: QueryTypes.SELECT }
      ),
    ]);
    // Our provider cost against what users were charged, both in US dollars.
    // cost_usd_micros is micro-dollars; charged credits convert at CREDIT_USD_VALUE.
    const money = (row) => {
      const cost = Number(row.cost_usd_micros) / 1e6;
      const charged = micros(row.charged_micros) * CREDIT_USD_VALUE;
      return {
        provider_cost_usd: Number(cost.toFixed(6)),
        charged_credits: micros(row.charged_micros),
        charged_usd: Number(charged.toFixed(6)),
        unbilled_credits: micros(row.unbilled_micros),
        margin_usd: Number((charged - cost).toFixed(6)),
      };
    };
    const [m] = margin;
    res.json({
      totals: {
        cost: parseFloat(totals.total_cost || 0),
        tokens: parseInt(totals.total_tokens || 0, 10),
      },
      daily,
      byModel,
      margin: {
        credit_usd_value: CREDIT_USD_VALUE,
        requests: m.requests,
        succeeded: m.succeeded,
        failed: m.failed,
        cancelled: m.cancelled,
        estimated: m.estimated,
        ...money(m),
        by_model: marginByModel.map((r) => ({ name: r.name, provider: r.provider, route: r.route, requests: r.requests, ...money(r) })),
      },
    });
  } catch (err) {
    console.error('admin usage:', err);
    res.status(500).json({ error: 'Failed to fetch usage' });
  }
}

async function getModels(req, res) {
  try {
    const models = await AIModel.findAll({ includeInactive: true });
    res.json({
      models: models.map((m) => {
        const { available, reason } = availability(m);
        return { ...m, available, unavailable_reason: reason || null };
      }),
    });
  } catch (err) {
    console.error('admin models:', err);
    res.status(500).json({ error: 'Failed to fetch models' });
  }
}

async function getRequests(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 50, 200);
    const rows = await sequelize.query(
      `SELECT r.id, r.created_at, r.status, r.error_code, r.route, r.upstream_model, r.source, r.unit, r.units,
              EXISTS (SELECT 1 FROM credit_transactions t WHERE t.request_id = r.id AND t.type = 'refund') AS refunded,
              r.input_tokens, r.output_tokens, r.usage_estimated,
              r.held_micros, r.charged_micros, r.unbilled_micros, r.cost_usd_micros,
              r.first_token_ms, r.duration_ms, u.email, m.name AS model_name
         FROM request_logs r
         LEFT JOIN users u ON u.id = r.user_id
         LEFT JOIN ai_models m ON m.id = r.model_id
        ORDER BY r.created_at DESC LIMIT :limit`,
      { replacements: { limit }, type: QueryTypes.SELECT }
    );
    res.json({
      requests: rows.map((r) => ({
        ...r,
        held_micros: undefined,
        charged_micros: undefined,
        unbilled_micros: undefined,
        cost_usd_micros: undefined,
        held_credits: micros(r.held_micros),
        charged_credits: micros(r.charged_micros),
        unbilled_credits: micros(r.unbilled_micros),
        provider_cost_usd: Number(r.cost_usd_micros) / 1e6,
      })),
    });
  } catch (err) {
    console.error('admin requests:', err);
    res.status(500).json({ error: 'Failed to fetch requests' });
  }
}

/**
 * POST /api/admin/users/:id/credits  { credits, reason }
 * Positive grants, negative removes. The reason and acting admin are kept on
 * the credit transaction, which is the audit trail for credit changes.
 */
async function adjustCredits(req, res) {
  try {
    const credits = Number(req.body?.credits);
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : '';
    if (!reason) return res.status(400).json({ error: 'Give a reason for the change.', code: 'REASON_REQUIRED' });
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    const result = await metering.addCredits(user.id, credits, {
      type: credits > 0 ? 'grant' : 'adjustment',
      reason,
      createdBy: req.user.id,
    });
    await logAdminAction(req.user.id, 'credits.adjust', { targetType: 'user', targetId: user.id, details: { credits, reason } });
    res.json({ user_id: user.id, credits: result.balance });
  } catch (err) {
    if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
    console.error('admin adjust credits:', err);
    res.status(500).json({ error: 'Failed to adjust credits' });
  }
}

async function checkModelUpdates(req, res) {
  try {
    const result = await checkForNewModels();
    res.json(result);
  } catch (err) {
    console.error('admin check model updates:', err);
    res.status(500).json({ error: 'Failed to check for new models' });
  }
}

async function getPlans(req, res) {
  try {
    res.json({ plans: await plans.listPlans({ includeInactive: true }) });
  } catch (err) {
    console.error('admin plans:', err);
    res.status(500).json({ error: 'Failed to fetch plans' });
  }
}

async function createPlan(req, res) {
  try {
    const plan = await plans.createPlan(req.body);
    await invalidate('plans');
    await logAdminAction(req.user.id, 'plan.create', { targetType: 'plan', targetId: plan.id, details: req.body });
    res.status(201).json({ plan });
  } catch (err) {
    if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
    console.error('admin create plan:', err);
    res.status(500).json({ error: 'Failed to create plan' });
  }
}

async function updatePlan(req, res) {
  try {
    const plan = await plans.updatePlan(req.params.id, req.body);
    if (!plan) return res.status(404).json({ error: 'Plan not found' });
    await invalidate('plans');
    await logAdminAction(req.user.id, 'plan.update', { targetType: 'plan', targetId: plan.id, details: req.body });
    res.json({ plan });
  } catch (err) {
    if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
    console.error('admin update plan:', err);
    res.status(500).json({ error: 'Failed to update plan' });
  }
}

const sendError = (res, err, label) => {
  if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
  console.error(`admin ${label}:`, err);
  return res.status(500).json({ error: `Failed to ${label}` });
};

/** PATCH /api/admin/models/:id — switch on/off, prices, tier, status, capabilities, route. */
async function updateModel(req, res) {
  try {
    const result = await modelAdmin.updateModel(req.params.id, req.body);
    if (!result) return res.status(404).json({ error: 'Model not found' });
    if (Object.keys(result.after).length) {
      await invalidate('models');
      await logAdminAction(req.user.id, 'model.update', {
        targetType: 'model',
        targetId: result.model.id,
        details: { slug: result.model.slug, before: result.before, after: result.after },
      });
    }
    const { available, reason } = availability(result.model);
    res.json({ model: { ...result.model, available, unavailable_reason: reason || null }, changed: Object.keys(result.after) });
  } catch (err) {
    sendError(res, err, 'update model');
  }
}

/** POST /api/admin/users/:id/suspend { reason } and /unsuspend */
async function setSuspended(req, res, suspend) {
  try {
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : '';
    if (suspend && !reason) return res.status(400).json({ error: 'Give a reason for the suspension.', code: 'REASON_REQUIRED' });
    if (suspend && req.params.id === req.user.id) {
      return res.status(400).json({ error: 'You can’t suspend your own account.', code: 'CANNOT_SUSPEND_SELF' });
    }
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found' });
    await sequelize.transaction(async (transaction) => {
      await sequelize.query(
        `UPDATE users SET suspended_at = ${suspend ? 'COALESCE(suspended_at, now())' : 'NULL'},
                suspended_reason = :reason, updated_at = now() WHERE id = :id`,
        { replacements: { id: user.id, reason: suspend ? reason : null }, transaction }
      );
      await logAdminAction(
        req.user.id,
        suspend ? 'user.suspend' : 'user.unsuspend',
        { targetType: 'user', targetId: user.id, details: { email: user.email, ...(suspend ? { reason } : {}) } },
        { transaction }
      );
    });
    res.json({ user_id: user.id, suspended: suspend });
  } catch (err) {
    sendError(res, err, suspend ? 'suspend user' : 'unsuspend user');
  }
}
const suspendUser = (req, res) => setSuspended(req, res, true);
const unsuspendUser = (req, res) => setSuspended(req, res, false);

/** POST /api/admin/requests/:id/refund { reason } — returns one call's charge to the user. */
async function refundRequest(req, res) {
  try {
    const reason = typeof req.body?.reason === 'string' ? req.body.reason.trim() : '';
    if (!reason) return res.status(400).json({ error: 'Give a reason for the refund.', code: 'REASON_REQUIRED' });
    const result = await metering.refundCharge(req.params.id, { reason, createdBy: req.user.id });
    await logAdminAction(req.user.id, 'request.refund', {
      targetType: 'request',
      targetId: req.params.id,
      details: { user_id: result.userId, credits: result.refunded, reason },
    });
    res.json(result);
  } catch (err) {
    sendError(res, err, 'refund request');
  }
}

/** GET /api/admin/audit — the newest admin actions. */
async function getAuditLog(req, res) {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 100, 500);
    res.json({ actions: await listAdminActions({ limit, targetType: req.query.target_type, targetId: req.query.target_id }) });
  } catch (err) {
    sendError(res, err, 'load the audit log');
  }
}

/** GET /api/admin/reports?status=open|reviewed|actioned|dismissed|all */
async function getReports(req, res) {
  try {
    res.json({ reports: await reports.listReports({ status: req.query.status || 'open' }) });
  } catch (err) {
    sendError(res, err, 'load reports');
  }
}

/** PATCH /api/admin/reports/:id { status } */
async function updateReport(req, res) {
  try {
    const report = await reports.updateReport(req.params.id, req.body?.status, req.user.id);
    if (!report) return res.status(404).json({ error: 'Report not found' });
    await logAdminAction(req.user.id, 'report.review', { targetType: 'report', targetId: report.id, details: { status: report.status } });
    res.json({ report });
  } catch (err) {
    sendError(res, err, 'update the report');
  }
}

/** GET /api/admin/alerts?all=1 */
async function getAlerts(req, res) {
  try {
    res.json({ alerts: await alerts.listAlerts({ includeResolved: req.query.all === '1' }) });
  } catch (err) {
    sendError(res, err, 'load alerts');
  }
}

/** POST /api/admin/alerts/:id/resolve */
async function resolveAlert(req, res) {
  try {
    if (!(await alerts.resolveAlert(req.params.id, req.user.id))) return res.status(404).json({ error: 'Alert not found' });
    await logAdminAction(req.user.id, 'alert.resolve', { targetType: 'alert', targetId: req.params.id });
    res.json({ resolved: true });
  } catch (err) {
    sendError(res, err, 'resolve the alert');
  }
}

module.exports = {
  getReports,
  updateReport,
  getAlerts,
  resolveAlert,
  checkAdmin,
  getDashboard,
  getUsers,
  getSubscriptions,
  getUsage,
  getModels,
  getRequests,
  adjustCredits,
  checkModelUpdates,
  getPlans,
  createPlan,
  updatePlan,
  updateModel,
  suspendUser,
  unsuspendUser,
  refundRequest,
  getAuditLog,
};
