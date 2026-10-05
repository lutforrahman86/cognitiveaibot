const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase, startApp, api, registerUser } = require('./helpers');
const { startMockStripe } = require('./mockStripe');

const WEBHOOK_SECRET = 'whsec_test_secret';

let sequelize;
let metering;
let server;
let stripeMock;
let Stripe;
let admin;
let monthly;
let topup;

let seq = 0;
const now = () => Math.floor(Date.now() / 1000);
const event = (type, object, { created } = {}) => {
  seq += 1;
  return { id: `evt_${seq}`, object: 'event', type, created: created ?? now() + seq, data: { object } };
};
async function deliver(evt, { secret = WEBHOOK_SECRET, signature } = {}) {
  const payload = JSON.stringify(evt);
  const res = await fetch(`${server.baseUrl}/api/billing/webhook`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Stripe-Signature': signature ?? Stripe.webhooks.generateTestHeaderString({ payload, secret }),
    },
    body: payload,
  });
  return { status: res.status, body: await res.json() };
}
const subscription = (id, { user, plan, status = 'active', periodEnd = now() + 30 * 86400, credits }) => ({
  id,
  object: 'subscription',
  customer: user.customer || null,
  status,
  cancel_at_period_end: false,
  start_date: now(),
  metadata: { user_id: user.user.id, plan_id: plan.id, credits: String(credits ?? plan.credits) },
  items: { data: [{ current_period_end: periodEnd }] },
});
const invoice = (id, { subId, reason, metadata = {}, customer = null, periodEnd = now() + 30 * 86400 }) => ({
  id,
  object: 'invoice',
  customer,
  billing_reason: reason,
  parent: { type: 'subscription_details', subscription_details: { subscription: subId, metadata } },
  lines: { data: [{ period: { start: periodEnd - 30 * 86400, end: periodEnd } }] },
});
const billing = async (u) => (await api(server.baseUrl, 'GET', '/api/billing', { token: u.token })).body;
const purchases = async (userId) =>
  (
    await sequelize.query(
      "SELECT amount_micros, reason, external_ref FROM credit_transactions WHERE user_id = :userId AND type = 'purchase' ORDER BY created_at",
      { replacements: { userId } }
    )
  )[0];

before(async () => {
  sequelize = await resetDatabase();
  stripeMock = await startMockStripe();
  Stripe = require('stripe');
  metering = require('../src/gateway/metering');
  server = await startApp();
  admin = await registerUser(server.baseUrl, 'Admin');
  await sequelize.query("UPDATE users SET type = 'admin' WHERE id = :id", { replacements: { id: admin.user.id } });
  const create = async (body) => (await api(server.baseUrl, 'POST', '/api/admin/plans', { token: admin.token, body })).body.plan;
  monthly = await create({ slug: 'pro-monthly', name: 'Pro', kind: 'subscription', interval: 'month', price_cents: 2000, credits: 1800 });
  topup = await create({ slug: 'topup-10', name: '1,000 credits', kind: 'topup', price_cents: 1000, credits: 900 });
});

beforeEach(() => {
  stripeMock.requests.length = 0;
  process.env.STRIPE_SECRET_KEY = 'sk_test_mock';
  process.env.STRIPE_API_BASE = stripeMock.baseUrl;
  process.env.STRIPE_WEBHOOK_SECRET = WEBHOOK_SECRET;
  delete process.env.SIGNUP_TRIAL_CREDITS;
});

after(async () => {
  await server.close();
  await stripeMock.close();
  await sequelize.close();
});

test('admins manage the plan catalog; the public list shows only active plans', async () => {
  const bob = await registerUser(server.baseUrl, 'Bob');
  const create = (token, body) => api(server.baseUrl, 'POST', '/api/admin/plans', { token, body });

  assert.equal((await create(bob.token, { slug: 'x' })).status, 403);
  const invalid = [
    { slug: 'a', name: 'A', kind: 'subscription', price_cents: 500, credits: 10 }, // no interval
    { slug: 'b', name: 'B', kind: 'topup', interval: 'month', price_cents: 500, credits: 10 },
    { slug: 'c', name: 'C', kind: 'topup', price_cents: 10, credits: 10 }, // below Stripe's minimum
    { slug: 'd', name: 'D', kind: 'topup', price_cents: 500, credits: 0 },
    { slug: 'Bad Slug', name: 'E', kind: 'topup', price_cents: 500, credits: 10 },
    { slug: 'pro-monthly', name: 'Dup', kind: 'topup', price_cents: 500, credits: 10 },
    { slug: 'f', name: 'F', kind: 'topup', price_cents: 500, credits: 10, owner: 'me' },
  ];
  for (const body of invalid) {
    const res = await create(admin.token, body);
    assert.equal(res.status, 400, `should reject ${JSON.stringify(body)}`);
    assert.equal(res.body.code, 'INVALID_PLAN');
  }

  const legacy = (await create(admin.token, { slug: 'legacy', name: 'Legacy', kind: 'topup', price_cents: 500, credits: 400 })).body.plan;
  const patched = await api(server.baseUrl, 'PATCH', `/api/admin/plans/${legacy.id}`, {
    token: admin.token,
    body: { active: false, credits: 450 },
  });
  assert.equal(patched.status, 200);
  assert.equal(patched.body.plan.credits, 450);
  assert.equal(patched.body.plan.active, false);
  assert.equal((await api(server.baseUrl, 'PATCH', `/api/admin/plans/${legacy.id}`, { token: admin.token, body: { interval: 'month' } })).status, 400);

  const pub = (await api(server.baseUrl, 'GET', '/api/plans')).body.plans;
  assert.deepEqual(pub.map((p) => p.slug).sort(), ['pro-monthly', 'topup-10']);
  assert.ok(!('stripe_price_id' in pub[0]), 'internal fields stay out of the public list');
  const all = (await api(server.baseUrl, 'GET', '/api/admin/plans', { token: admin.token })).body.plans;
  assert.ok(all.some((p) => p.slug === 'legacy'));
});

test('without a Stripe key, checkout is refused with a clear code and nothing is called', async () => {
  delete process.env.STRIPE_SECRET_KEY;
  const ana = await registerUser(server.baseUrl, 'Ana');
  const res = await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: ana.token, body: { plan_id: topup.id } });
  assert.equal(res.status, 503);
  assert.equal(res.body.code, 'PAYMENTS_NOT_CONFIGURED');
  assert.equal((await billing(ana)).payments_enabled, false);
  assert.equal(stripeMock.requests.length, 0);
});

test('checkout sends the stored price and credits to Stripe and reuses one customer per user', async () => {
  const cy = await registerUser(server.baseUrl, 'Cy');
  const checkout = (plan_id) => api(server.baseUrl, 'POST', '/api/billing/checkout', { token: cy.token, body: { plan_id } });

  const first = await checkout(topup.id);
  assert.equal(first.status, 200);
  assert.match(first.body.url, /^https:\/\/checkout\.stripe\.test\//);
  const s1 = stripeMock.calls('/v1/checkout/sessions')[0].body;
  assert.equal(s1.mode, 'payment');
  assert.equal(s1['line_items[0][price_data][unit_amount]'], '1000');
  assert.equal(s1['line_items[0][price_data][currency]'], 'usd');
  assert.equal(s1['metadata[credits]'], '900');
  assert.equal(s1['metadata[user_id]'], cy.user.id);
  assert.equal(s1['payment_intent_data[metadata][plan_id]'], topup.id);
  assert.match(s1.success_url, /\/upgrade\?checkout=success$/);

  const second = await checkout(monthly.id);
  assert.equal(second.status, 200);
  const s2 = stripeMock.calls('/v1/checkout/sessions')[1].body;
  assert.equal(s2.mode, 'subscription');
  assert.equal(s2['line_items[0][price_data][recurring][interval]'], 'month');
  assert.equal(s2['subscription_data[metadata][credits]'], '1800');
  assert.equal(s1.customer, s2.customer);
  assert.equal(stripeMock.calls('/v1/customers').length, 1, 'one Stripe customer per user');

  assert.equal((await checkout('00000000-0000-0000-0000-000000000000')).status, 404);
  assert.equal((await checkout('not-a-uuid')).status, 404);
});

test('a paid top-up grants its credits exactly once, however often Stripe delivers it', async () => {
  const dee = await registerUser(server.baseUrl, 'Dee');
  const session = {
    id: 'cs_test_topup_1',
    object: 'checkout.session',
    mode: 'payment',
    payment_status: 'paid',
    customer: null,
    client_reference_id: dee.user.id,
    metadata: { user_id: dee.user.id, plan_id: topup.id, credits: '900' },
  };
  const completed = event('checkout.session.completed', session);

  assert.equal((await deliver(completed)).status, 200);
  assert.equal((await deliver(completed)).body.duplicate, true);
  // A different event about the same payment still can't grant twice.
  assert.equal((await deliver(event('checkout.session.async_payment_succeeded', session))).status, 200);

  assert.equal((await billing(dee)).credits.balance, 900);
  const rows = await purchases(dee.user.id);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].external_ref, 'stripe:checkout:cs_test_topup_1');

  // A delayed payment method that hasn't cleared grants nothing yet.
  await deliver(event('checkout.session.completed', { ...session, id: 'cs_test_unpaid', payment_status: 'unpaid' }));
  assert.equal((await billing(dee)).credits.balance, 900);
});

test('an unsigned or wrongly signed webhook is rejected and changes nothing', async () => {
  const eve = await registerUser(server.baseUrl, 'Eve');
  const forged = event('checkout.session.completed', {
    id: 'cs_forged',
    mode: 'payment',
    payment_status: 'paid',
    metadata: { user_id: eve.user.id, plan_id: topup.id, credits: '100000' },
  });
  assert.equal((await deliver(forged, { secret: 'whsec_wrong' })).status, 400);
  assert.equal((await deliver(forged, { signature: '' })).body.code, 'INVALID_SIGNATURE');
  delete process.env.STRIPE_WEBHOOK_SECRET;
  assert.equal((await deliver(forged)).status, 503);
  assert.equal((await billing(eve)).credits.balance, 0);
  assert.equal((await purchases(eve.user.id)).length, 0);
});

test('a subscription grants its credits each paid period, replaces unused ones, and keeps its terms', async () => {
  const fay = await registerUser(server.baseUrl, 'Fay');
  const sub = subscription('sub_fay', { user: fay, plan: monthly });
  const meta = sub.metadata;

  const periodEnd = now() + 30 * 86400;
  await deliver(event('customer.subscription.created', sub));
  await deliver(event('invoice.paid', invoice('in_fay_1', { subId: sub.id, reason: 'subscription_create', metadata: meta, periodEnd })));
  let b = await billing(fay);
  assert.equal(b.plan.slug, 'pro-monthly');
  assert.equal(b.subscription.status, 'active');
  assert.equal(b.credits.balance, 1800);
  assert.equal(b.credits.expiring.credits, 1800);
  // They last for the period paid for, plus a day's grace for the renewal to clear.
  assert.equal(new Date(b.credits.expiring.at).getTime(), (periodEnd + 86400) * 1000);

  // Already subscribed: a second subscription checkout is refused.
  const again = await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: fay.token, body: { plan_id: monthly.id } });
  assert.equal(again.status, 409);
  assert.equal(again.body.code, 'ALREADY_SUBSCRIBED');

  // An admin cuts the plan's credits; Fay's running subscription keeps hers.
  await api(server.baseUrl, 'PATCH', `/api/admin/plans/${monthly.id}`, { token: admin.token, body: { credits: 1500 } });
  await deliver(event('invoice.paid', invoice('in_fay_2', { subId: sub.id, reason: 'subscription_cycle', metadata: meta })));
  await deliver(event('invoice.paid', invoice('in_fay_2', { subId: sub.id, reason: 'subscription_cycle', metadata: meta })));
  // A mid-period change invoice grants nothing.
  await deliver(event('invoice.paid', invoice('in_fay_x', { subId: sub.id, reason: 'subscription_update', metadata: meta })));
  b = await billing(fay);
  // The unused 1,800 from the first period expired and the renewal's 1,800 replaced them.
  assert.equal(b.credits.balance, 1800);
  assert.deepEqual((await purchases(fay.user.id)).map((r) => r.reason), ['Pro (first period)', 'Pro (renewal)']);
  const [expiries] = await sequelize.query(
    "SELECT amount_micros FROM credit_transactions WHERE user_id = :id AND type = 'expiry'",
    { replacements: { id: fay.user.id } }
  );
  assert.deepEqual(expiries.map((r) => Number(r.amount_micros) / 1e6), [-1800]);
  await api(server.baseUrl, 'PATCH', `/api/admin/plans/${monthly.id}`, { token: admin.token, body: { credits: 1800 } });
});

test('an invoice without our metadata is matched through the saved subscription', async () => {
  const gus = await registerUser(server.baseUrl, 'Gus');
  await deliver(event('customer.subscription.created', subscription('sub_gus', { user: gus, plan: monthly })));
  await deliver(event('invoice.paid', invoice('in_gus_1', { subId: 'sub_gus', reason: 'subscription_cycle' })));
  assert.equal((await billing(gus)).credits.balance, 1800);
});

test('a failed renewal grants nothing, then ends the plan when Stripe gives up', async () => {
  const hal = await registerUser(server.baseUrl, 'Hal');
  const sub = subscription('sub_hal', { user: hal, plan: monthly });
  await deliver(event('customer.subscription.created', sub, { created: now() - 100 }));
  await deliver(event('invoice.paid', invoice('in_hal_1', { subId: sub.id, reason: 'subscription_create', metadata: sub.metadata })));
  assert.equal((await billing(hal)).credits.balance, 1800);

  // The renewal charge fails: Stripe marks the subscription past_due and retries.
  await deliver(event('invoice.payment_failed', invoice('in_hal_2', { subId: sub.id, reason: 'subscription_cycle', metadata: sub.metadata })));
  await deliver(event('customer.subscription.updated', { ...sub, status: 'past_due' }, { created: now() - 50 }));
  let b = await billing(hal);
  assert.equal(b.plan.slug, 'pro-monthly', 'the plan stays usable while Stripe retries');
  assert.equal(b.subscription.payment_failed, true);
  assert.equal(b.credits.balance, 1800, 'no credits for an unpaid period');

  // Retries exhausted: the subscription is canceled and the account is back on no plan.
  await deliver(event('customer.subscription.deleted', { ...sub, status: 'canceled' }, { created: now() - 10 }));
  b = await billing(hal);
  assert.equal(b.plan, null);
  assert.equal(b.subscription, null);
  assert.equal(b.credits.balance, 1800, 'credits already paid for last until their period ends');

  // A late, older event can't bring the subscription back.
  await deliver(event('customer.subscription.updated', { ...sub, status: 'active' }, { created: now() - 40 }));
  assert.equal((await billing(hal)).plan, null);
  const [[row]] = await sequelize.query("SELECT status FROM subscriptions WHERE stripe_subscription_id = 'sub_hal'");
  assert.equal(row.status, 'canceled');

  // With no plan, Hal can subscribe again.
  const res = await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: hal.token, body: { plan_id: monthly.id } });
  assert.equal(res.status, 200);
});

test('the billing portal opens only for users who have bought something', async () => {
  const ivy = await registerUser(server.baseUrl, 'Ivy');
  const portal = () => api(server.baseUrl, 'POST', '/api/billing/portal', { token: ivy.token });
  assert.equal((await portal()).body.code, 'NO_BILLING_ACCOUNT');
  await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: ivy.token, body: { plan_id: topup.id } });
  const res = await portal();
  assert.equal(res.status, 200);
  assert.equal(res.body.url, 'https://billing.stripe.test/p');
  assert.match(stripeMock.calls('/v1/billing_portal/sessions')[0].body.return_url, /\/upgrade$/);
});

test('plan credits are spent first and lapse when their period ends; top-ups never expire', async () => {
  const jo = await registerUser(server.baseUrl, 'Jo');
  await deliver(event('checkout.session.completed', {
    id: 'cs_test_jo',
    mode: 'payment',
    payment_status: 'paid',
    metadata: { user_id: jo.user.id, plan_id: topup.id, credits: '900' },
  }));
  const sub = subscription('sub_jo', { user: jo, plan: monthly });
  await deliver(event('customer.subscription.created', sub));
  await deliver(event('invoice.paid', invoice('in_jo_1', { subId: sub.id, reason: 'subscription_create', metadata: sub.metadata })));
  let b = await billing(jo);
  assert.equal(b.credits.balance, 2700);
  assert.equal(b.credits.expiring.credits, 1800);

  // A reply costing 300 credits is paid from the plan credits, which would lapse anyway.
  const model = { id: null, name: 'Test model', input_credits_per_mtok: 1e6, output_credits_per_mtok: 1e6 };
  const reply = { userId: jo.user.id, chatId: null, model, route: 'test', upstreamModel: 'test', messages: [{ content: 'hi' }] };
  const meter = await metering.start({ ...reply, maxOutputTokens: 1000 });
  await meter.finish({ status: 'succeeded', inputTokens: 100, outputTokens: 200 });
  b = await billing(jo);
  assert.equal(b.credits.balance, 2400);
  assert.equal(b.credits.expiring.credits, 1500);

  // Before the period ends, the sweep changes nothing.
  await metering.expireSubscriptionCredits();
  assert.equal((await billing(jo)).credits.balance, 2400);

  // The period ends with no renewal while a reply is holding 2,000 credits:
  // only what isn't held can expire now.
  await sequelize.query("UPDATE credit_accounts SET subscription_expires_at = now() - interval '1 minute' WHERE user_id = :id", {
    replacements: { id: jo.user.id },
  });
  // 21 estimated input tokens + 1,979 output tokens, at 1 credit per token.
  const inFlight = await metering.start({ ...reply, maxOutputTokens: 1979 });
  assert.equal(inFlight.holdMicros, 2000 * 1e6);
  await metering.expireSubscriptionCredits();
  b = await billing(jo);
  assert.equal(b.credits.balance, 2000);
  assert.equal(b.credits.expiring.credits, 1100);

  // The reply fails (costing nothing); the next sweep expires the rest. The top-up stays.
  await inFlight.finish({ status: 'failed', errorCode: 'PROVIDER_ERROR' });
  await metering.expireSubscriptionCredits();
  b = await billing(jo);
  assert.equal(b.credits.balance, 900);
  assert.equal(b.credits.expiring, null);
  const [rows] = await sequelize.query(
    "SELECT amount_micros FROM credit_transactions WHERE user_id = :id AND type = 'expiry' ORDER BY created_at",
    { replacements: { id: jo.user.id } }
  );
  assert.deepEqual(rows.map((r) => Number(r.amount_micros) / 1e6), [-400, -1100]);
});

test('a Stripe refund takes back the refunded share of that payment’s credits, once', async () => {
  const kai = await registerUser(server.baseUrl, 'Kai');
  await deliver(event('checkout.session.completed', {
    id: 'cs_test_kai',
    mode: 'payment',
    payment_status: 'paid',
    payment_intent: 'pi_kai',
    metadata: { user_id: kai.user.id, plan_id: topup.id, credits: '900' },
  }));
  stripeMock.fixtures.sessions.push({ id: 'cs_test_kai', payment_intent: 'pi_kai' });
  stripeMock.fixtures.paymentIntents.push({ id: 'pi_kai', amount: 1000, amount_received: 1000 });

  // A half refund ($5 of $10) takes back 450 credits; delivered twice, it counts once.
  const half = event('refund.created', { id: 're_kai_1', object: 'refund', status: 'succeeded', amount: 500, payment_intent: 'pi_kai' });
  await deliver(half);
  await deliver(event('refund.updated', half.data.object));
  assert.equal((await billing(kai)).credits.balance, 450);

  // A pending refund changes nothing until it succeeds.
  await deliver(event('refund.created', { id: 're_kai_2', status: 'pending', amount: 500, payment_intent: 'pi_kai' }));
  assert.equal((await billing(kai)).credits.balance, 450);
  await deliver(event('refund.updated', { id: 're_kai_2', status: 'succeeded', amount: 500, payment_intent: 'pi_kai' }));
  assert.equal((await billing(kai)).credits.balance, 0);
  const [rows] = await sequelize.query(
    "SELECT amount_micros, reason FROM credit_transactions WHERE user_id = :id AND type = 'adjustment' ORDER BY created_at",
    { replacements: { id: kai.user.id } }
  );
  assert.deepEqual(rows.map((r) => [Number(r.amount_micros) / 1e6, r.reason]), [
    [-450, 'Payment partly refunded'],
    [-450, 'Payment partly refunded'],
  ]);
});

test('refunding a subscription payment whose credits were partly spent takes back only what is left', async () => {
  const lia = await registerUser(server.baseUrl, 'Lia');
  const sub = subscription('sub_lia', { user: lia, plan: monthly });
  await deliver(event('customer.subscription.created', sub));
  await deliver(event('invoice.paid', invoice('in_lia_1', { subId: sub.id, reason: 'subscription_create', metadata: sub.metadata })));
  await metering.addCredits(lia.user.id, -1500, { type: 'adjustment', reason: 'spent (test)' });
  stripeMock.fixtures.invoicePayments.push({ invoice: 'in_lia_1', payment_intent: 'pi_lia' });
  stripeMock.fixtures.paymentIntents.push({ id: 'pi_lia', amount: 2000, amount_received: 2000 });

  await deliver(event('refund.created', { id: 're_lia', status: 'succeeded', amount: 2000, payment_intent: 'pi_lia' }));
  assert.equal((await billing(lia)).credits.balance, 0);
  const [[row]] = await sequelize.query("SELECT reason FROM credit_transactions WHERE external_ref = 'stripe:refund:re_lia'");
  assert.equal(row.reason, 'Payment refunded (1500 credits were already used)');
});

test('users see their Stripe invoices', async () => {
  const mo = await registerUser(server.baseUrl, 'Mo');
  assert.deepEqual((await api(server.baseUrl, 'GET', '/api/billing/invoices', { token: mo.token })).body.invoices, []);
  await api(server.baseUrl, 'POST', '/api/billing/checkout', { token: mo.token, body: { plan_id: topup.id } });
  const [[{ stripe_customer_id: customer }]] = await sequelize.query('SELECT stripe_customer_id FROM users WHERE id = :id', {
    replacements: { id: mo.user.id },
  });
  stripeMock.fixtures.invoices.push(
    { id: 'in_mo_1', customer, number: 'ABC-0001', created: 1790000000, total: 2500, currency: 'usd', status: 'paid', hosted_invoice_url: 'https://invoice.stripe.test/1', invoice_pdf: 'https://invoice.stripe.test/1.pdf' },
    { id: 'in_mo_draft', customer, number: null, created: 1790000001, total: 2500, currency: 'usd', status: 'draft' },
    { id: 'in_other', customer: 'cus_other', number: 'X', created: 1, total: 1, currency: 'usd', status: 'paid' }
  );
  const invoices = (await api(server.baseUrl, 'GET', '/api/billing/invoices', { token: mo.token })).body.invoices;
  assert.deepEqual(invoices.map((i) => [i.number, i.amount_cents, i.status, i.url]), [['ABC-0001', 2500, 'paid', 'https://invoice.stripe.test/1']]);
});

// --- RevenueCat (App Store purchases)

const RC_AUTH = 'Bearer rc-test-secret';
let rcSeq = 0;
const rcEvent = (type, user, fields = {}) => {
  rcSeq += 1;
  return {
    api_version: '1.0',
    event: {
      id: `rc_evt_${rcSeq}`,
      type,
      app_user_id: user.user.id,
      original_app_user_id: user.user.id,
      aliases: [user.user.id],
      environment: 'SANDBOX',
      store: 'APP_STORE',
      period_type: 'NORMAL',
      event_timestamp_ms: Date.now() + rcSeq,
      ...fields,
    },
  };
};
const rcDeliver = (body, auth = RC_AUTH) =>
  fetch(`${server.baseUrl}/api/billing/revenuecat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: auth } : {}) },
    body: JSON.stringify(body),
  }).then(async (r) => ({ status: r.status, body: await r.json() }));

test('App Store purchases through RevenueCat grant plan and top-up credits, once, to the right user', async () => {
  process.env.REVENUECAT_WEBHOOK_AUTH = RC_AUTH;
  await api(server.baseUrl, 'PATCH', `/api/admin/plans/${monthly.id}`, { token: admin.token, body: { revenuecat_product_id: 'cog_pro_monthly' } });
  await api(server.baseUrl, 'PATCH', `/api/admin/plans/${topup.id}`, { token: admin.token, body: { revenuecat_product_id: 'cog_topup_10' } });
  const nia = await registerUser(server.baseUrl, 'Nia');
  const expires = Date.now() + 30 * 86400 * 1000;
  const purchase = rcEvent('INITIAL_PURCHASE', nia, {
    product_id: 'cog_pro_monthly', transaction_id: 'txn_1', original_transaction_id: 'otx_1', purchased_at_ms: Date.now(), expiration_at_ms: expires,
  });

  assert.equal((await rcDeliver(purchase, 'Bearer wrong')).status, 401);
  assert.equal((await rcDeliver(purchase, null)).status, 401);
  assert.equal((await rcDeliver(purchase)).status, 200);
  assert.equal((await rcDeliver(purchase)).body.duplicate, true);
  let b = await billing(nia);
  assert.equal(b.plan.slug, 'pro-monthly');
  assert.equal(b.subscription.source, 'revenuecat');
  assert.equal(b.credits.balance, 1800);
  assert.equal(new Date(b.credits.expiring.at).getTime(), expires + 86400 * 1000);

  // Renewal: the unused credits are replaced by the new period's.
  await rcDeliver(rcEvent('RENEWAL', nia, {
    product_id: 'cog_pro_monthly', transaction_id: 'txn_2', original_transaction_id: 'otx_1', expiration_at_ms: expires + 30 * 86400 * 1000,
  }));
  // A top-up bought in the app.
  await rcDeliver(rcEvent('NON_RENEWING_PURCHASE', nia, { product_id: 'cog_topup_10', transaction_id: 'txn_topup' }));
  b = await billing(nia);
  assert.equal(b.credits.balance, 1800 + 900);
  const [[{ subs }]] = await sequelize.query('SELECT count(*)::int AS subs FROM subscriptions WHERE user_id = :id', { replacements: { id: nia.user.id } });
  assert.equal(subs, 1, 'renewals update the same subscription');

  // Cancelled: keeps working until the period ends, marked as not renewing.
  await rcDeliver(rcEvent('CANCELLATION', nia, { product_id: 'cog_pro_monthly', transaction_id: 'txn_2', original_transaction_id: 'otx_1', cancel_reason: 'UNSUBSCRIBE', expiration_at_ms: expires + 30 * 86400 * 1000 }));
  b = await billing(nia);
  assert.equal(b.plan.slug, 'pro-monthly');
  assert.equal(b.subscription.cancel_at_period_end, true);

  // Expired: back to no plan; credits last until their period ends.
  await rcDeliver(rcEvent('EXPIRATION', nia, { product_id: 'cog_pro_monthly', transaction_id: 'txn_2', original_transaction_id: 'otx_1', expiration_at_ms: Date.now() - 1000 }));
  b = await billing(nia);
  assert.equal(b.plan, null);
  assert.equal(b.credits.balance, 2700);
});

test('an App Store refund ends the subscription and takes back that period’s credits', async () => {
  process.env.REVENUECAT_WEBHOOK_AUTH = RC_AUTH;
  const oli = await registerUser(server.baseUrl, 'Oli');
  const fields = { product_id: 'cog_pro_monthly', transaction_id: 'txn_oli', original_transaction_id: 'otx_oli', expiration_at_ms: Date.now() + 30 * 86400 * 1000 };
  await rcDeliver(rcEvent('INITIAL_PURCHASE', oli, fields));
  assert.equal((await billing(oli)).credits.balance, 1800);
  await rcDeliver(rcEvent('CANCELLATION', oli, { ...fields, cancel_reason: 'CUSTOMER_SUPPORT' }));
  const b = await billing(oli);
  assert.equal(b.plan, null);
  assert.equal(b.credits.balance, 0);

  // A free trial grants a plan but no credits.
  const pat = await registerUser(server.baseUrl, 'Pat');
  await rcDeliver(rcEvent('INITIAL_PURCHASE', pat, { ...fields, transaction_id: 'txn_pat', original_transaction_id: 'otx_pat', period_type: 'TRIAL' }));
  assert.equal((await billing(pat)).plan.slug, 'pro-monthly');
  assert.equal((await billing(pat)).credits.balance, 0);

  // Unknown products and users are errors RevenueCat retries, not silent successes.
  assert.equal((await rcDeliver(rcEvent('INITIAL_PURCHASE', pat, { ...fields, product_id: 'nope', transaction_id: 'x' }))).status, 500);
  assert.equal((await rcDeliver(rcEvent('INITIAL_PURCHASE', { user: { id: '$RCAnonymousID:abc' } }, { ...fields, transaction_id: 'y' }))).status, 500);
});
