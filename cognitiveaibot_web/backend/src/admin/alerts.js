/**
 * Things an admin should look at (roadmap E4): a spending spike, or a prompt
 * moderation flagged as sexual content involving minors. Shown in the admin
 * Alerts tab and, with ADMIN_ALERT_EMAIL set, emailed.
 *
 * `dedupeKey` keeps one alert per incident (e.g. per user per hour).
 */
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { sendEmail } = require('../services/email');

// Credits one account may spend in an hour before admins are alerted.
const spendThreshold = () => Number(process.env.SPEND_ALERT_CREDITS_PER_HOUR) || 500;

const DESCRIPTIONS = {
  spend_spike: (d) => `spent ${d.credits} credits in the last hour (alert threshold ${d.threshold})`,
  moderation_minors: (d) => `sent a ${d.source} prompt flagged as sexual content involving minors; it was blocked`,
};

async function raiseAlert(kind, userId, details, dedupeKey) {
  const [row] = await sequelize.query(
    `INSERT INTO admin_alerts (kind, user_id, details, dedupe_key) VALUES (:kind, :userId, CAST(:details AS jsonb), :dedupeKey)
     ON CONFLICT (dedupe_key) DO NOTHING RETURNING id`,
    { replacements: { kind, userId, details: JSON.stringify(details), dedupeKey }, type: QueryTypes.SELECT }
  );
  if (!row) return null;
  const to = process.env.ADMIN_ALERT_EMAIL;
  if (to) {
    const [user] = await sequelize.query('SELECT email FROM users WHERE id = :userId', {
      replacements: { userId },
      type: QueryTypes.SELECT,
    });
    await sendEmail({
      to,
      subject: `[Alert] ${kind.replace('_', ' ')}: ${user?.email || userId}`,
      text: `${user?.email || userId} ${DESCRIPTIONS[kind]?.(details) || JSON.stringify(details)}.\n\nReview it in the admin Alerts tab.`,
    }).catch((err) => console.error('[alerts] email failed:', err.message));
  }
  return row.id;
}

/** Raises an alert for each account whose spend in the last hour is over the threshold. */
async function checkSpendSpikes() {
  const threshold = spendThreshold();
  const rows = await sequelize.query(
    `SELECT user_id, sum(charged_micros) / 1e6 AS credits FROM request_logs
      WHERE user_id IS NOT NULL AND created_at > now() - interval '1 hour'
      GROUP BY user_id HAVING sum(charged_micros) > :limit`,
    { replacements: { limit: threshold * 1e6 }, type: QueryTypes.SELECT }
  );
  const hour = new Date().toISOString().slice(0, 13);
  for (const r of rows) {
    await raiseAlert('spend_spike', r.user_id, { credits: Number(Number(r.credits).toFixed(2)), threshold }, `spend:${r.user_id}:${hour}`);
  }
  return rows.length;
}

async function listAlerts({ includeResolved = false, limit = 100 } = {}) {
  return sequelize.query(
    `SELECT a.id, a.kind, a.user_id, u.email, u.suspended_at, a.details, a.created_at, a.resolved_at, r.email AS resolved_by
       FROM admin_alerts a LEFT JOIN users u ON u.id = a.user_id LEFT JOIN users r ON r.id = a.resolved_by
      ${includeResolved ? '' : 'WHERE a.resolved_at IS NULL'}
      ORDER BY a.created_at DESC LIMIT :limit`,
    { replacements: { limit }, type: QueryTypes.SELECT }
  );
}

async function resolveAlert(id, adminId) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id))) return false;
  const rows = await sequelize.query(
    'UPDATE admin_alerts SET resolved_at = now(), resolved_by = :adminId WHERE id = :id AND resolved_at IS NULL RETURNING id',
    { replacements: { id, adminId }, type: QueryTypes.SELECT }
  );
  return rows.length > 0;
}

module.exports = { raiseAlert, checkSpendSpikes, listAlerts, resolveAlert, DESCRIPTIONS };
