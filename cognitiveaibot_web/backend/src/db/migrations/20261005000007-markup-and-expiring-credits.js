/**
 * Pricing decisions of 2026-10-05 (ROADMAP Decision 4).
 *
 * - Credit prices become provider cost + 30%: the catalog snapshot was
 *   repriced, and only the two credit-price columns are copied from it here,
 *   so nothing else an admin may have changed on a model is touched.
 * - Subscription credits expire at the end of each paid period; top-up
 *   credits never do. credit_accounts tracks how much of the balance is the
 *   current period's subscription credits and when they expire. Charges use
 *   those first. A database CHECK keeps that part within the balance.
 * - credit_transactions gains an 'expiry' type for credits that lapsed.
 */
const catalog = require('../data/model-catalog-2026-10-05.json');

async function up({ context: { sequelize } }) {
  await sequelize.transaction(async (transaction) => {
    for (const m of catalog.models) {
      await sequelize.query(
        `UPDATE ai_models SET input_credits_per_mtok = :input, output_credits_per_mtok = :output, updated_at = now()
          WHERE slug = :slug`,
        { replacements: { slug: m.slug, input: m.input_credits_per_mtok, output: m.output_credits_per_mtok }, transaction }
      );
    }
    await sequelize.query(
      `
      ALTER TABLE credit_accounts
        ADD COLUMN subscription_micros bigint NOT NULL DEFAULT 0,
        ADD COLUMN subscription_expires_at timestamptz,
        ADD CONSTRAINT credit_accounts_subscription_within_balance
          CHECK (subscription_micros >= 0 AND subscription_micros <= balance_micros);

      ALTER TABLE credit_transactions DROP CONSTRAINT credit_transactions_type_check;
      ALTER TABLE credit_transactions ADD CONSTRAINT credit_transactions_type_check
        CHECK (type IN ('grant', 'purchase', 'charge', 'adjustment', 'refund', 'expiry'));

      CREATE INDEX idx_credit_accounts_expiring ON credit_accounts (subscription_expires_at)
        WHERE subscription_micros > 0;
      `,
      { transaction }
    );
  });
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP INDEX IF EXISTS idx_credit_accounts_expiring;
    DELETE FROM credit_transactions WHERE type = 'expiry';
    ALTER TABLE credit_transactions DROP CONSTRAINT credit_transactions_type_check;
    ALTER TABLE credit_transactions ADD CONSTRAINT credit_transactions_type_check
      CHECK (type IN ('grant', 'purchase', 'charge', 'adjustment', 'refund'));
    ALTER TABLE credit_accounts
      DROP CONSTRAINT IF EXISTS credit_accounts_subscription_within_balance,
      DROP COLUMN IF EXISTS subscription_micros,
      DROP COLUMN IF EXISTS subscription_expires_at;
  `);
  // Credit prices are left as they are: they are data, not schema.
}

module.exports = { up, down };
