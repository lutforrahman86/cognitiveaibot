/**
 * Admin controls, model tiers and mobile purchases (roadmap A2, A5, C3, D1,
 * D3, E1, E2).
 *
 * - ai_models gain what the registry was missing: modalities, capability
 *   flags, a lifecycle status, and a `tier`. Plans gain `model_tier`, the
 *   highest tier they unlock. Everything starts at tier 0, open to everyone:
 *   tiers exist, but no model is restricted until an admin decides to.
 * - users can be suspended, with a reason.
 * - admin_actions: an audit log of every admin change (who, what, to what).
 * - plans.revenuecat_product_id links a plan to its App Store product, and
 *   subscriptions.revenuecat_subscription_id holds RevenueCat's original
 *   transaction id, so renewals find their subscription.
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      ALTER TABLE ai_models
        ADD COLUMN input_modalities text[] NOT NULL DEFAULT '{text}',
        ADD COLUMN output_modalities text[] NOT NULL DEFAULT '{text}',
        ADD COLUMN supports_streaming boolean NOT NULL DEFAULT true,
        ADD COLUMN supports_vision boolean NOT NULL DEFAULT false,
        ADD COLUMN supports_tools boolean NOT NULL DEFAULT false,
        ADD COLUMN supports_json boolean NOT NULL DEFAULT false,
        ADD COLUMN status varchar(12) NOT NULL DEFAULT 'active' CHECK (status IN ('beta', 'active', 'deprecated')),
        ADD COLUMN tier smallint NOT NULL DEFAULT 0 CHECK (tier BETWEEN 0 AND 9);

      ALTER TABLE plans
        ADD COLUMN model_tier smallint NOT NULL DEFAULT 0 CHECK (model_tier BETWEEN 0 AND 9),
        ADD COLUMN revenuecat_product_id varchar(150) UNIQUE;

      ALTER TABLE subscriptions ADD COLUMN revenuecat_subscription_id varchar(150) UNIQUE;

      ALTER TABLE users
        ADD COLUMN suspended_at timestamptz,
        ADD COLUMN suspended_reason text;

      CREATE TABLE admin_actions (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        admin_id uuid REFERENCES users(id) ON DELETE SET NULL,
        action varchar(60) NOT NULL,
        target_type varchar(30) NOT NULL,
        target_id varchar(100),
        details jsonb NOT NULL DEFAULT '{}',
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_admin_actions_created ON admin_actions (created_at DESC);
      CREATE INDEX idx_admin_actions_target ON admin_actions (target_type, target_id);
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP TABLE IF EXISTS admin_actions;
    ALTER TABLE users DROP COLUMN IF EXISTS suspended_at, DROP COLUMN IF EXISTS suspended_reason;
    ALTER TABLE subscriptions DROP COLUMN IF EXISTS revenuecat_subscription_id;
    ALTER TABLE plans DROP COLUMN IF EXISTS model_tier, DROP COLUMN IF EXISTS revenuecat_product_id;
    ALTER TABLE ai_models
      DROP COLUMN IF EXISTS input_modalities, DROP COLUMN IF EXISTS output_modalities,
      DROP COLUMN IF EXISTS supports_streaming, DROP COLUMN IF EXISTS supports_vision,
      DROP COLUMN IF EXISTS supports_tools, DROP COLUMN IF EXISTS supports_json,
      DROP COLUMN IF EXISTS status, DROP COLUMN IF EXISTS tier;
  `);
}

module.exports = { up, down };
