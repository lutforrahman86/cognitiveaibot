/**
 * What a user has bought, and how they buy more (roadmap D2).
 *
 * Payment never grants credits directly. Checkout only sends the user to
 * Stripe; credits arrive when Stripe's signed webhook confirms the money
 * (see webhooks.js), through the same ledger every reply is charged against.
 */
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const { requireStripe, getStripe } = require('./stripe');
const { getPlan, toPublic } = require('./plans');

// Stripe keeps a subscription 'past_due' while it retries a failed renewal.
// The plan stays usable during those retries; it ends when Stripe gives up
// and the subscription becomes 'canceled' or 'unpaid'.
const ENTITLED_STATUSES = ['active', 'trialing', 'past_due'];

const frontendUrl = () => (process.env.FRONTEND_URL || 'http://localhost:5173').replace(/\/$/, '');

/** The subscription that currently gives the user a plan, or null. */
async function currentSubscription(userId) {
  const [row] = await sequelize.query(
    `SELECT s.id, s.plan_id, s.source, s.status, s.expires_at, s.cancel_at_period_end
       FROM subscriptions s
      WHERE s.user_id = :userId AND s.status IN (:statuses)
        AND (s.source = 'stripe' OR s.expires_at IS NULL OR s.expires_at > now())
      ORDER BY s.expires_at DESC NULLS FIRST
      LIMIT 1`,
    { replacements: { userId, statuses: ENTITLED_STATUSES }, type: QueryTypes.SELECT }
  );
  return row || null;
}

/**
 * The highest model tier the user's plan unlocks. No plan, or a plan
 * without tiers, unlocks tier 0, which every model starts at.
 */
async function modelTierFor(userId) {
  const sub = await currentSubscription(userId);
  const plan = sub?.plan_id ? await getPlan(sub.plan_id) : null;
  return plan?.model_tier || 0;
}

/** Refuses a model above the caller's tier. */
function requireTier(model, userTier) {
  if ((model.tier || 0) > userTier) {
    throw new GatewayError('MODEL_REQUIRES_PLAN', `${model.name} is available on higher plans. Upgrade to use it.`, {
      status: 403,
    });
  }
}

/** The user's plan and subscription state, as clients show it. */
async function getEntitlement(userId) {
  const sub = await currentSubscription(userId);
  const plan = sub?.plan_id ? await getPlan(sub.plan_id) : null;
  return {
    plan: plan ? toPublic(plan) : null,
    subscription: sub
      ? {
          status: sub.status,
          source: sub.source,
          current_period_end: sub.expires_at,
          cancel_at_period_end: sub.cancel_at_period_end,
          payment_failed: sub.status === 'past_due',
        }
      : null,
    payments_enabled: Boolean(getStripe()),
  };
}

/** The user's Stripe customer, created on first checkout. */
async function ensureCustomer(stripe, userId) {
  const [user] = await sequelize.query('SELECT id, email, name, stripe_customer_id FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (user.stripe_customer_id) return user.stripe_customer_id;

  // The idempotency key makes two simultaneous first checkouts share one customer.
  const customer = await stripe.customers.create(
    { email: user.email, name: user.name || undefined, metadata: { user_id: user.id } },
    { idempotencyKey: `customer-${user.id}` }
  );
  const [saved] = await sequelize.query(
    `UPDATE users SET stripe_customer_id = COALESCE(stripe_customer_id, :customerId)
      WHERE id = :userId RETURNING stripe_customer_id`,
    { replacements: { userId, customerId: customer.id }, type: QueryTypes.SELECT }
  );
  return saved.stripe_customer_id;
}

/**
 * Opens a Stripe Checkout page for a plan and returns its URL. The plan's
 * credits are copied into the payment's metadata, so the user gets what they
 * were shown even if an admin edits the plan before the payment completes,
 * and a subscription keeps its terms for as long as it runs.
 */
async function startCheckout(userId, planId) {
  const stripe = requireStripe();
  const plan = await getPlan(planId);
  if (!plan || !plan.active) {
    throw new GatewayError('PLAN_NOT_FOUND', 'That plan isn’t available.', { status: 404 });
  }
  const isSubscription = plan.kind === 'subscription';
  if (isSubscription && (await currentSubscription(userId))) {
    throw new GatewayError(
      'ALREADY_SUBSCRIBED',
      'You already have a plan. Change or cancel it from Manage billing.',
      { status: 409 }
    );
  }

  const customer = await ensureCustomer(stripe, userId);
  const metadata = { user_id: userId, plan_id: plan.id, credits: String(plan.credits) };
  const lineItem = plan.stripe_price_id
    ? { price: plan.stripe_price_id, quantity: 1 }
    : {
        quantity: 1,
        price_data: {
          currency: plan.currency,
          unit_amount: plan.price_cents,
          product_data: {
            name: plan.name,
            ...(plan.description ? { description: plan.description } : {}),
          },
          ...(isSubscription ? { recurring: { interval: plan.billing_interval } } : {}),
        },
      };

  const session = await stripe.checkout.sessions.create({
    mode: isSubscription ? 'subscription' : 'payment',
    customer,
    client_reference_id: userId,
    line_items: [lineItem],
    metadata,
    ...(isSubscription ? { subscription_data: { metadata } } : { payment_intent_data: { metadata } }),
    success_url: `${frontendUrl()}/upgrade?checkout=success`,
    cancel_url: `${frontendUrl()}/upgrade?checkout=cancelled`,
  });
  return { url: session.url };
}

/** Opens Stripe's billing portal, where users change card, cancel, or see invoices. */
async function openPortal(userId) {
  const stripe = requireStripe();
  const [user] = await sequelize.query('SELECT stripe_customer_id FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (!user?.stripe_customer_id) {
    throw new GatewayError('NO_BILLING_ACCOUNT', 'You haven’t bought anything yet.', { status: 400 });
  }
  const session = await stripe.billingPortal.sessions.create({
    customer: user.stripe_customer_id,
    return_url: `${frontendUrl()}/upgrade`,
  });
  return { url: session.url };
}

/** The user's Stripe invoices, newest first (subscription periods; top-up receipts are emailed by Stripe). */
async function listInvoices(userId) {
  const stripe = getStripe();
  const [user] = await sequelize.query('SELECT stripe_customer_id FROM users WHERE id = :userId', {
    replacements: { userId },
    type: QueryTypes.SELECT,
  });
  if (!stripe || !user?.stripe_customer_id) return [];
  const invoices = await stripe.invoices.list({ customer: user.stripe_customer_id, limit: 24 });
  return invoices.data
    .filter((i) => i.status !== 'draft')
    .map((i) => ({
      id: i.id,
      number: i.number,
      created: new Date(i.created * 1000).toISOString(),
      amount_cents: i.total,
      currency: i.currency,
      status: i.status,
      url: i.hosted_invoice_url,
      pdf: i.invoice_pdf,
    }));
}

module.exports = {
  listInvoices,
  getEntitlement,
  currentSubscription,
  modelTierFor,
  requireTier,
  startCheckout,
  openPortal,
  ENTITLED_STATUSES,
};
