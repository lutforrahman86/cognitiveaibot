/**
 * The plan catalog (roadmap D1). Plans live in the database and are edited by
 * admins; no client hardcodes them. A plan is never deleted, only
 * deactivated, because subscriptions and past purchases point at it.
 *
 * Checkout charges the plan's price as stored here, unless the plan names a
 * `stripe_price_id`. A price change therefore applies to new checkouts only:
 * existing Stripe subscriptions keep the price they started on.
 */
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');

const COLUMNS = `id, slug, name, description, kind, billing_interval, price_cents, currency, credits,
  includes_api, stripe_price_id, active, sort_order, created_at, updated_at`;

/** What any visitor may see about a plan. */
function toPublic(plan) {
  return {
    id: plan.id,
    slug: plan.slug,
    name: plan.name,
    description: plan.description,
    kind: plan.kind,
    interval: plan.billing_interval,
    price_cents: plan.price_cents,
    currency: plan.currency,
    credits: plan.credits,
    includes_api: plan.includes_api,
  };
}

async function listPlans({ includeInactive = false } = {}) {
  return sequelize.query(
    `SELECT ${COLUMNS} FROM plans ${includeInactive ? '' : 'WHERE active'}
      ORDER BY kind, sort_order, price_cents`,
    { type: QueryTypes.SELECT }
  );
}

async function getPlan(id) {
  if (!/^[0-9a-f-]{36}$/i.test(String(id || ''))) return null;
  const [plan] = await sequelize.query(`SELECT ${COLUMNS} FROM plans WHERE id = :id`, {
    replacements: { id },
    type: QueryTypes.SELECT,
  });
  return plan || null;
}

const invalid = (message) => new GatewayError('INVALID_PLAN', message, { status: 400 });

/**
 * Checks admin input. With `existing`, only the given fields change, and the
 * result is validated as a whole (e.g. kind and interval must still agree).
 */
function validatePlan(body = {}, existing = null) {
  const editable = [
    'slug', 'name', 'description', 'kind', 'interval', 'price_cents', 'currency', 'credits',
    'includes_api', 'stripe_price_id', 'active', 'sort_order',
  ];
  const unknown = Object.keys(body).filter((k) => !editable.includes(k));
  if (unknown.length) throw invalid(`Unknown field: ${unknown.join(', ')}.`);

  const current = existing ? { ...existing, interval: existing.billing_interval } : {};
  const p = { ...current, ...body };
  if (existing && body.kind === 'topup' && !('interval' in body)) p.interval = null;

  const text = (v) => (typeof v === 'string' ? v.trim() : v);
  const plan = {
    slug: text(p.slug),
    name: text(p.name),
    description: text(p.description) || null,
    kind: p.kind,
    billing_interval: p.interval ?? null,
    price_cents: Number(p.price_cents),
    currency: String(p.currency || 'usd').toLowerCase(),
    credits: Number(p.credits),
    includes_api: Boolean(p.includes_api),
    stripe_price_id: text(p.stripe_price_id) || null,
    active: p.active === undefined ? true : Boolean(p.active),
    sort_order: Number(p.sort_order || 0),
  };

  if (!plan.slug || !/^[a-z0-9][a-z0-9-]{0,59}$/.test(plan.slug)) {
    throw invalid('The slug must be lowercase letters, numbers and dashes.');
  }
  if (!plan.name) throw invalid('Give the plan a name.');
  if (!['subscription', 'topup'].includes(plan.kind)) throw invalid('Kind must be "subscription" or "topup".');
  if (plan.kind === 'subscription' && !['month', 'year'].includes(plan.billing_interval)) {
    throw invalid('A subscription needs an interval: "month" or "year".');
  }
  if (plan.kind === 'topup' && plan.billing_interval) throw invalid('A top-up has no interval.');
  if (!Number.isInteger(plan.price_cents) || plan.price_cents < 50) {
    throw invalid('The price must be a whole number of cents, at least 50 (Stripe’s minimum).');
  }
  if (!/^[a-z]{3}$/.test(plan.currency)) throw invalid('The currency must be a 3-letter code, such as "usd".');
  if (!Number.isInteger(plan.credits) || plan.credits <= 0) throw invalid('Credits must be a positive whole number.');
  if (!Number.isInteger(plan.sort_order)) throw invalid('The sort order must be a whole number.');
  return plan;
}

async function createPlan(body) {
  const plan = validatePlan(body);
  try {
    const [row] = await sequelize.query(
      `INSERT INTO plans (slug, name, description, kind, billing_interval, price_cents, currency, credits,
                          includes_api, stripe_price_id, active, sort_order)
       VALUES (:slug, :name, :description, :kind, :billing_interval, :price_cents, :currency, :credits,
               :includes_api, :stripe_price_id, :active, :sort_order)
       RETURNING ${COLUMNS}`,
      { replacements: plan, type: QueryTypes.SELECT }
    );
    return row;
  } catch (err) {
    if (err.name === 'SequelizeUniqueConstraintError') throw invalid('A plan with that slug already exists.');
    throw err;
  }
}

async function updatePlan(id, body) {
  const existing = await getPlan(id);
  if (!existing) return null;
  const plan = validatePlan(body, existing);
  try {
    const [row] = await sequelize.query(
      `UPDATE plans SET slug = :slug, name = :name, description = :description, kind = :kind,
              billing_interval = :billing_interval, price_cents = :price_cents, currency = :currency,
              credits = :credits, includes_api = :includes_api, stripe_price_id = :stripe_price_id,
              active = :active, sort_order = :sort_order, updated_at = now()
        WHERE id = :id
        RETURNING ${COLUMNS}`,
      { replacements: { ...plan, id }, type: QueryTypes.SELECT }
    );
    return row;
  } catch (err) {
    if (err.name === 'SequelizeUniqueConstraintError') throw invalid('A plan with that slug already exists.');
    throw err;
  }
}

module.exports = { listPlans, getPlan, createPlan, updatePlan, toPublic };
