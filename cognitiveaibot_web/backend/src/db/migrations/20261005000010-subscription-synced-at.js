/**
 * subscriptions.stripe_synced_at becomes synced_at: the time of the store
 * event last applied, now used for RevenueCat (App Store) events as well as
 * Stripe's, so neither can roll a subscription back with a late event.
 */
async function up({ context: { sequelize } }) {
  await sequelize.query('ALTER TABLE subscriptions RENAME COLUMN stripe_synced_at TO synced_at');
}

async function down({ context: { sequelize } }) {
  await sequelize.query('ALTER TABLE subscriptions RENAME COLUMN synced_at TO stripe_synced_at');
}

module.exports = { up, down };
