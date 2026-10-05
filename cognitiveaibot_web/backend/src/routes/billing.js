const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { GatewayError } = require('../gateway/errors');
const { getBalance } = require('../gateway/metering');
const { listPlans, toPublic } = require('../billing/plans');
const { getEntitlement, startCheckout, openPortal, listInvoices } = require('../billing/service');
const { handleWebhook } = require('../billing/webhooks');
const { cached } = require('../services/cache');
const { handleRevenueCatWebhook } = require('../billing/revenuecat');

function respond(label, fn) {
  return async (req, res) => {
    try {
      res.json(await fn(req));
    } catch (err) {
      if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
      console.error(`${label}:`, err);
      res.status(500).json({ error: `Failed to ${label}` });
    }
  };
}

/** GET /api/plans — the active plan catalog. Public: the pricing page needs it signed out. */
const plansRouter = express.Router();
plansRouter.get(
  '/',
  respond('list plans', () => cached('plans', 300, async () => ({ plans: (await listPlans()).map(toPublic) })))
);

/**
 * POST /api/billing/webhook — Stripe events. Mounted before express.json():
 * the signature covers the exact raw bytes.
 */
const webhookRouter = express.Router();
webhookRouter.post(
  '/',
  express.raw({ type: '*/*', limit: '1mb' }),
  respond('process webhook', (req) => handleWebhook(req.body, req.headers['stripe-signature']))
);

/** POST /api/billing/revenuecat — App Store purchases, authorized by RevenueCat's header. */
const revenueCatRouter = express.Router();
revenueCatRouter.post(
  '/',
  respond('process RevenueCat webhook', (req) => handleRevenueCatWebhook(req.body, req.headers.authorization))
);

const billingRouter = express.Router();
billingRouter.use(authMiddleware);

/** GET /api/billing — the caller's plan, subscription state and credit balance. */
billingRouter.get(
  '/',
  respond('fetch billing', async (req) => ({
    ...(await getEntitlement(req.user.id)),
    credits: await getBalance(req.user.id),
  }))
);

/** POST /api/billing/checkout { plan_id } — returns the Stripe Checkout URL to send the user to. */
billingRouter.post('/checkout', respond('start checkout', (req) => startCheckout(req.user.id, req.body?.plan_id)));

/** GET /api/billing/invoices — the caller's Stripe invoices. */
billingRouter.get('/invoices', respond('list invoices', async (req) => ({ invoices: await listInvoices(req.user.id) })));

/** POST /api/billing/portal — returns the Stripe billing portal URL. */
billingRouter.post('/portal', respond('open billing portal', (req) => openPortal(req.user.id)));

module.exports = { plansRouter, billingRouter, webhookRouter, revenueCatRouter };
