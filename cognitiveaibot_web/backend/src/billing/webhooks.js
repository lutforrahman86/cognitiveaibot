/**
 * Stripe webhooks: the only place money turns into credits.
 *
 * Every event is verified against STRIPE_WEBHOOK_SECRET before anything is
 * read from it. Stripe delivers at least once and in no guaranteed order, so:
 *   - each processed event id is recorded and skipped if seen again;
 *   - each grant carries the payment's id as its ledger `external_ref`, so the
 *     same payment can't grant twice even through two different events;
 *   - a subscription only moves forward in time (see stripe_synced_at), and a
 *     canceled one stays canceled.
 * A handler that throws answers 500, and Stripe retries the event later.
 *
 * Events used:
 *   checkout.session.completed / async_payment_succeeded → top-up credits
 *   customer.subscription.created / updated / deleted    → subscription state
 *   invoice.paid (first period or renewal)                → plan credits
 * A failed renewal needs no handler of its own: no invoice.paid means no
 * credits, and the status change arrives as customer.subscription.updated.
 */
const Stripe = require('stripe');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const metering = require('../gateway/metering');
const { getPlan } = require('./plans');

const idOf = (v) => (v && typeof v === 'object' ? v.id : v) || null;

/** The user a payment belongs to: from our metadata, else by Stripe customer. */
async function resolveUserId(metadataUserId, customer) {
  const find = (where, value) =>
    sequelize.query(`SELECT id FROM users WHERE ${where} = :value`, {
      replacements: { value },
      type: QueryTypes.SELECT,
    });
  if (metadataUserId) {
    const [byId] = await find('id::text', String(metadataUserId));
    if (byId) return byId.id;
  }
  if (idOf(customer)) {
    const [byCustomer] = await find('stripe_customer_id', idOf(customer));
    if (byCustomer) return byCustomer.id;
  }
  throw new Error(`No user for Stripe customer ${idOf(customer)}`);
}

/** Credits granted by a payment: the amount shown at checkout, else the plan's. */
function creditsFor(metadata, plan) {
  const fromMetadata = Number(metadata?.credits);
  if (Number.isInteger(fromMetadata) && fromMetadata > 0) return fromMetadata;
  if (plan) return plan.credits;
  throw new Error('Payment has neither credits in its metadata nor a known plan');
}

async function onCheckoutCompleted(session) {
  // Subscriptions are credited per invoice; only one-off top-ups here. A
  // delayed payment method completes unpaid and is credited on
  // checkout.session.async_payment_succeeded instead.
  if (session.mode !== 'payment' || session.payment_status !== 'paid') return;
  const userId = await resolveUserId(session.metadata?.user_id || session.client_reference_id, session.customer);
  const plan = await getPlan(session.metadata?.plan_id);
  await metering.addCredits(userId, creditsFor(session.metadata, plan), {
    type: 'purchase',
    reason: plan ? `${plan.name} (top-up)` : 'Credit top-up',
    externalRef: `stripe:checkout:${session.id}`,
  });
}

async function onSubscriptionChanged(sub, eventCreated, deleted) {
  const userId = await resolveUserId(sub.metadata?.user_id, sub.customer);
  const plan = await getPlan(sub.metadata?.plan_id);
  if (!plan) console.warn(`[billing] Stripe subscription ${sub.id} has no known plan; saved without one`);
  const periodEnd = Math.max(0, ...(sub.items?.data || []).map((i) => i.current_period_end || 0));

  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, stripe_subscription_id, product_id, status,
                                started_at, expires_at, cancel_at_period_end, stripe_synced_at)
     VALUES (:userId, :planId, 'stripe', :subId, :productId, :status,
             to_timestamp(:startedAt), to_timestamp(NULLIF(:periodEnd, 0)), :cancelAtPeriodEnd, to_timestamp(:syncedAt))
     ON CONFLICT (stripe_subscription_id) DO UPDATE SET
       status = EXCLUDED.status,
       plan_id = COALESCE(EXCLUDED.plan_id, subscriptions.plan_id),
       product_id = COALESCE(EXCLUDED.product_id, subscriptions.product_id),
       expires_at = COALESCE(EXCLUDED.expires_at, subscriptions.expires_at),
       cancel_at_period_end = EXCLUDED.cancel_at_period_end,
       stripe_synced_at = EXCLUDED.stripe_synced_at,
       updated_at = now()
     WHERE subscriptions.status <> 'canceled'
       AND (subscriptions.stripe_synced_at IS NULL OR subscriptions.stripe_synced_at <= EXCLUDED.stripe_synced_at)`,
    {
      replacements: {
        userId,
        planId: plan?.id || null,
        subId: sub.id,
        productId: plan?.slug || null,
        status: deleted ? 'canceled' : sub.status,
        startedAt: sub.start_date || sub.created || eventCreated,
        periodEnd,
        cancelAtPeriodEnd: Boolean(sub.cancel_at_period_end),
        syncedAt: eventCreated,
      },
    }
  );
}

const CREDITED_BILLING_REASONS = { subscription_create: 'first period', subscription_cycle: 'renewal' };

async function onInvoicePaid(invoice) {
  const details = invoice.parent?.subscription_details;
  const subId = idOf(details?.subscription);
  // Plan changes mid-period (subscription_update) and manual invoices grant nothing.
  const label = CREDITED_BILLING_REASONS[invoice.billing_reason];
  if (!subId || !label) return;

  let metadata = details.metadata || {};
  if (!metadata.plan_id || !metadata.user_id) {
    const [ours] = await sequelize.query(
      'SELECT user_id, plan_id FROM subscriptions WHERE stripe_subscription_id = :subId',
      { replacements: { subId }, type: QueryTypes.SELECT }
    );
    metadata = { user_id: ours?.user_id, plan_id: ours?.plan_id, ...metadata };
  }
  const userId = await resolveUserId(metadata.user_id, invoice.customer);
  const plan = await getPlan(metadata.plan_id);
  await metering.addCredits(userId, creditsFor(metadata, plan), {
    type: 'purchase',
    reason: `${plan ? plan.name : 'Subscription'} (${label})`,
    externalRef: `stripe:invoice:${invoice.id}`,
  });
}

const HANDLERS = {
  'checkout.session.completed': (e) => onCheckoutCompleted(e.data.object),
  'checkout.session.async_payment_succeeded': (e) => onCheckoutCompleted(e.data.object),
  'customer.subscription.created': (e) => onSubscriptionChanged(e.data.object, e.created, false),
  'customer.subscription.updated': (e) => onSubscriptionChanged(e.data.object, e.created, false),
  'customer.subscription.deleted': (e) => onSubscriptionChanged(e.data.object, e.created, true),
  'invoice.paid': (e) => onInvoicePaid(e.data.object),
};

/** Verifies and processes one webhook delivery. `rawBody` must be the exact bytes Stripe sent. */
async function handleWebhook(rawBody, signature) {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret) {
    throw new GatewayError('PAYMENTS_NOT_CONFIGURED', 'Stripe webhooks aren’t configured.', { status: 503 });
  }
  let event;
  try {
    event = Stripe.webhooks.constructEvent(rawBody, signature || '', secret);
  } catch {
    throw new GatewayError('INVALID_SIGNATURE', 'Webhook signature verification failed.', { status: 400 });
  }

  const [seen] = await sequelize.query('SELECT 1 FROM billing_events WHERE id = :id', {
    replacements: { id: event.id },
    type: QueryTypes.SELECT,
  });
  if (seen) return { received: true, duplicate: true };

  const handler = HANDLERS[event.type];
  if (handler) await handler(event);
  await sequelize.query(
    'INSERT INTO billing_events (id, type) VALUES (:id, :type) ON CONFLICT (id) DO NOTHING',
    { replacements: { id: event.id, type: event.type } }
  );
  return { received: true, handled: Boolean(handler) };
}

module.exports = { handleWebhook };
