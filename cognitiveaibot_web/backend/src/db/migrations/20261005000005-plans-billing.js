/**
 * Plans and billing (roadmap D1, D2).
 *
 * - plans: the catalog admins edit. A subscription plan grants `credits` each
 *   paid billing period; a top-up grants them once. Prices are integer cents.
 * - users.stripe_customer_id: one Stripe customer per user, created at the
 *   first checkout.
 * - subscriptions gain the plan, where they came from, and the Stripe
 *   subscription they mirror. `expires_at` holds the current period end.
 *   `stripe_synced_at` is the Stripe event time last applied, so a late,
 *   out-of-order webhook can't roll a subscription back to an older state.
 * - credit_transactions.external_ref: the payment a grant came from
 *   (e.g. "stripe:invoice:in_…"). Unique, so a webhook delivered twice can
 *   never grant twice. Paid credits get their own 'purchase' type.
 * - billing_events: every Stripe event processed, for idempotency and audit.
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      CREATE TABLE plans (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        slug varchar(60) NOT NULL UNIQUE,
        name varchar(100) NOT NULL,
        description text,
        kind varchar(20) NOT NULL CHECK (kind IN ('subscription', 'topup')),
        billing_interval varchar(10) CHECK (billing_interval IN ('month', 'year')),
        price_cents integer NOT NULL CHECK (price_cents > 0),
        currency varchar(3) NOT NULL DEFAULT 'usd',
        credits integer NOT NULL CHECK (credits > 0),
        includes_api boolean NOT NULL DEFAULT false,
        stripe_price_id varchar(100),
        active boolean NOT NULL DEFAULT true,
        sort_order integer NOT NULL DEFAULT 0,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT plans_interval_matches_kind CHECK (
          (kind = 'subscription' AND billing_interval IS NOT NULL) OR
          (kind = 'topup' AND billing_interval IS NULL)
        )
      );

      ALTER TABLE users ADD COLUMN stripe_customer_id varchar(100) UNIQUE;

      ALTER TABLE subscriptions
        ADD COLUMN plan_id uuid REFERENCES plans(id) ON DELETE RESTRICT,
        ADD COLUMN source varchar(20) NOT NULL DEFAULT 'revenuecat'
          CHECK (source IN ('stripe', 'revenuecat', 'admin')),
        ADD COLUMN stripe_subscription_id varchar(100) UNIQUE,
        ADD COLUMN cancel_at_period_end boolean NOT NULL DEFAULT false,
        ADD COLUMN stripe_synced_at timestamptz;
      ALTER TABLE subscriptions ALTER COLUMN created_at SET DEFAULT now();
      ALTER TABLE subscriptions ALTER COLUMN updated_at SET DEFAULT now();

      ALTER TABLE credit_transactions DROP CONSTRAINT credit_transactions_type_check;
      ALTER TABLE credit_transactions ADD CONSTRAINT credit_transactions_type_check
        CHECK (type IN ('grant', 'purchase', 'charge', 'adjustment', 'refund'));
      ALTER TABLE credit_transactions ADD COLUMN external_ref varchar(150) UNIQUE;

      CREATE TABLE billing_events (
        id varchar(100) PRIMARY KEY,
        type varchar(80) NOT NULL,
        processed_at timestamptz NOT NULL DEFAULT now()
      );
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP TABLE IF EXISTS billing_events;
    ALTER TABLE credit_transactions DROP COLUMN IF EXISTS external_ref;
    DELETE FROM credit_transactions WHERE type = 'purchase';
    ALTER TABLE credit_transactions DROP CONSTRAINT credit_transactions_type_check;
    ALTER TABLE credit_transactions ADD CONSTRAINT credit_transactions_type_check
      CHECK (type IN ('grant', 'charge', 'adjustment', 'refund'));
    ALTER TABLE subscriptions
      DROP COLUMN IF EXISTS plan_id,
      DROP COLUMN IF EXISTS source,
      DROP COLUMN IF EXISTS stripe_subscription_id,
      DROP COLUMN IF EXISTS cancel_at_period_end,
      DROP COLUMN IF EXISTS stripe_synced_at;
    ALTER TABLE users DROP COLUMN IF EXISTS stripe_customer_id;
    DROP TABLE IF EXISTS plans;
  `);
}

module.exports = { up, down };
