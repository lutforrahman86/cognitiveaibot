/**
 * The plan catalog: the four plans approved on 2026-10-05. Admins change it
 * from the admin Plans tab; existing plans are left alone here, so
 * re-seeding never undoes an admin's edits.
 *
 * At 1 credit = US$0.01 each plan gives ~10% fewer credits than its price,
 * which covers Stripe's fee. Model usage itself carries a 30% markup.
 * Subscription credits reset each period; top-up credits never expire.
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
  console.log(`Plans: ${PLANS.length} plans ensured`);
}

module.exports = { seed };
