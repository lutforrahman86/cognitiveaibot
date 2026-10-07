/**
 * RevenueCat webhooks (roadmap D3): App Store purchases made in the mobile
 * app, into the same subscriptions and credit ledger as Stripe.
 *
 * Contract with the app: after sign-in it calls Purchases.logIn(<our user
 * id>), so `app_user_id` is our user id. A plan is matched to the store
 * product by plans.revenuecat_product_id.
 *
 * RevenueCat sends the Authorization header configured in its dashboard;
 * it must equal REVENUECAT_WEBHOOK_AUTH. Events are deduplicated by id,
 * credits by store transaction id, and a subscription only moves forward in
 * time (synced_at). A handler that throws answers 500 and RevenueCat retries.
 *
 * Events used:
 *   INITIAL_PURCHASE, RENEWAL        → subscription active, plan credits for the period
 *   NON_RENEWING_PURCHASE            → top-up credits
 *   CANCELLATION                     → won't renew; a refund (cancel_reason
 *                                      CUSTOMER_SUPPORT) also ends it and takes
 *                                      back the refunded period's credits
 *   UNCANCELLATION                   → renews again
 *   BILLING_ISSUE                    → past_due (still usable while Apple retries)
 *   EXPIRATION                       → ended
 * Free-trial periods grant no credits.
 */
const crypto = require('crypto');
const { QueryTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { GatewayError } = require('../gateway/errors');
const metering = require('../gateway/metering');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function authorized(header) {
  const expected = process.env.REVENUECAT_WEBHOOK_AUTH;
  if (!expected) {
    throw new GatewayError('PAYMENTS_NOT_CONFIGURED', 'RevenueCat webhooks aren’t configured.', { status: 503 });
  }
  const a = Buffer.from(String(header || ''));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

async function resolveUserId(event) {
  const candidates = [event.app_user_id, event.original_app_user_id, ...(event.aliases || [])].filter(
    (id) => typeof id === 'string' && UUID.test(id)
  );
  for (const id of new Set(candidates)) {
    const [user] = await sequelize.query('SELECT id FROM users WHERE id = :id', {
      replacements: { id },
      type: QueryTypes.SELECT,
    });
    if (user) return user.id;
  }
  throw new Error(`RevenueCat event ${event.id}: no user for app_user_id ${event.app_user_id}`);
}

async function planFor(event) {
  const [plan] = await sequelize.query('SELECT * FROM plans WHERE revenuecat_product_id = :productId', {
    replacements: { productId: event.product_id || '' },
    type: QueryTypes.SELECT,
  });
  if (!plan) throw new Error(`RevenueCat event ${event.id}: no plan has revenuecat_product_id "${event.product_id}"`);
  return plan;
}

const ms = (v) => (v ? new Date(Number(v)) : null);

/** Creates or moves forward the subscription this store purchase belongs to. */
async function syncSubscription(event, userId, plan, changes) {
  const subId = event.original_transaction_id || event.transaction_id;
  await sequelize.query(
    `INSERT INTO subscriptions (user_id, plan_id, source, revenuecat_subscription_id, revenuecat_customer_id, product_id,
                                status, started_at, expires_at, cancel_at_period_end, synced_at)
     VALUES (:userId, :planId, 'revenuecat', :subId, :customerId, :productId,
             :status, :startedAt, :expiresAt, :cancel, :syncedAt)
     ON CONFLICT (revenuecat_subscription_id) DO UPDATE SET
       plan_id = EXCLUDED.plan_id,
       product_id = EXCLUDED.product_id,
       status = EXCLUDED.status,
       expires_at = COALESCE(EXCLUDED.expires_at, subscriptions.expires_at),
       cancel_at_period_end = EXCLUDED.cancel_at_period_end,
       synced_at = EXCLUDED.synced_at,
       updated_at = now()
     WHERE subscriptions.synced_at IS NULL OR subscriptions.synced_at <= EXCLUDED.synced_at`,
    {
      replacements: {
        userId,
        planId: plan.id,
        subId,
        customerId: event.original_app_user_id || event.app_user_id,
        productId: plan.slug,
        status: changes.status,
        startedAt: ms(event.purchased_at_ms) || new Date(),
        expiresAt: changes.expiresAt === undefined ? ms(event.expiration_at_ms) : changes.expiresAt,
        cancel: Boolean(changes.cancelAtPeriodEnd),
        syncedAt: ms(event.event_timestamp_ms) || new Date(),
      },
    }
  );
}

const txnRef = (event) => `revenuecat:txn:${event.transaction_id}`;

const HANDLERS = {
  async INITIAL_PURCHASE(event, userId, plan) {
    await syncSubscription(event, userId, plan, { status: 'active' });
    if (event.period_type === 'TRIAL' || plan.kind !== 'subscription') return;
    await metering.grantSubscriptionCredits(userId, plan.credits, {
      periodEnd: ms(event.expiration_at_ms),
      reason: `${plan.name} (${event.type === 'RENEWAL' ? 'renewal' : 'first period'}, App Store)`,
      externalRef: txnRef(event),
    });
  },
  async RENEWAL(event, userId, plan) {
    await HANDLERS.INITIAL_PURCHASE(event, userId, plan);
  },
  async NON_RENEWING_PURCHASE(event, userId, plan) {
    if (plan.kind !== 'topup') throw new Error(`RevenueCat one-off purchase of non-top-up plan ${plan.slug}`);
    await metering.addCredits(userId, plan.credits, {
      type: 'purchase',
      reason: `${plan.name} (top-up, App Store)`,
      externalRef: txnRef(event),
    });
  },
  async CANCELLATION(event, userId, plan) {
    if (plan.kind !== 'subscription') {
      // A refunded top-up.
      if (event.cancel_reason === 'CUSTOMER_SUPPORT') {
        await metering.reverseGrant(txnRef(event), { refundRef: `revenuecat:refund:${event.id}`, reason: 'App Store refund' });
      }
      return;
    }
    if (event.cancel_reason === 'CUSTOMER_SUPPORT') {
      // Refunded by Apple: the subscription ends now and the period's credits go back.
      await syncSubscription(event, userId, plan, { status: 'canceled', expiresAt: new Date() });
      await metering.reverseGrant(txnRef(event), { refundRef: `revenuecat:refund:${event.id}`, reason: 'App Store refund' });
      return;
    }
    await syncSubscription(event, userId, plan, { status: 'active', cancelAtPeriodEnd: true });
  },
  async UNCANCELLATION(event, userId, plan) {
    await syncSubscription(event, userId, plan, { status: 'active' });
  },
  async BILLING_ISSUE(event, userId, plan) {
    await syncSubscription(event, userId, plan, { status: 'past_due' });
  },
  async EXPIRATION(event, userId, plan) {
    await syncSubscription(event, userId, plan, { status: 'canceled' });
  },
};

/** Verifies and processes one RevenueCat webhook delivery. */
async function handleRevenueCatWebhook(body, authorization) {
  if (!authorized(authorization)) {
    throw new GatewayError('UNAUTHORIZED', 'Webhook authorization failed.', { status: 401 });
  }
  const event = body?.event;
  if (!event?.id || !event.type) throw new GatewayError('INVALID_EVENT', 'No event in the request.', { status: 400 });

  const eventKey = `revenuecat:${event.id}`;
  const [seen] = await sequelize.query('SELECT 1 FROM billing_events WHERE id = :id', {
    replacements: { id: eventKey },
    type: QueryTypes.SELECT,
  });
  if (seen) return { received: true, duplicate: true };

  const handler = HANDLERS[event.type];
  if (handler) {
    const userId = await resolveUserId(event);
    await handler(event, userId, await planFor(event));
  }
  await sequelize.query('INSERT INTO billing_events (id, type) VALUES (:id, :type) ON CONFLICT (id) DO NOTHING', {
    replacements: { id: eventKey, type: `revenuecat.${event.type}` },
  });
  return { received: true, handled: Boolean(handler) };
}

module.exports = { handleRevenueCatWebhook };
