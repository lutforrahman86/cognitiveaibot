/**
 * Placeholder plans for development, so the Upgrade page has something to
 * show. Prices and credit amounts are NOT decided (roadmap Decision 4): set
 * the real catalog from the admin Plans tab. Existing plans are left alone,
 * so re-seeding never undoes an admin's edits.
 *
 * At the placeholder 1 credit = US$0.01, each plan gives ~10% fewer credits
 * than its price buys at cost, which roughly covers Stripe's fee.
 */
const { sequelize } = require('../../config/database');

const PLANS = [
  { slug: 'starter-monthly', name: 'Starter', kind: 'subscription', billing_interval: 'month', price_cents: 1000, credits: 900, includes_api: false, sort_order: 1,
    description: 'For trying many models: 900 credits every month.' },
  { slug: 'pro-monthly', name: 'Pro', kind: 'subscription', billing_interval: 'month', price_cents: 2500, credits: 2250, includes_api: true, sort_order: 2,
    description: 'For daily work: 2,250 credits every month, plus API access.' },
  { slug: 'topup-500', name: '450 credits', kind: 'topup', billing_interval: null, price_cents: 500, credits: 450, includes_api: false, sort_order: 1,
    description: 'One-off top-up. Credits don’t expire.' },
  { slug: 'topup-2000', name: '1,800 credits', kind: 'topup', billing_interval: null, price_cents: 2000, credits: 1800, includes_api: false, sort_order: 2,
    description: 'One-off top-up. Credits don’t expire.' },
];

async function seed() {
  for (const plan of PLANS) {
    await sequelize.query(
      `INSERT INTO plans (slug, name, description, kind, billing_interval, price_cents, credits, includes_api, sort_order)
       VALUES (:slug, :name, :description, :kind, :billing_interval, :price_cents, :credits, :includes_api, :sort_order)
       ON CONFLICT (slug) DO NOTHING`,
      { replacements: plan }
    );
  }
  console.log(`Plans: ${PLANS.length} placeholder plans ensured`);
}

module.exports = { seed };
