/**
 * The money layer for model calls (roadmap A2, A4, A5).
 *
 * - ai_models gains routing (aggregator_model_id), limits, and two prices:
 *   what the provider charges us (USD per 1M tokens) and what we charge the
 *   user (credits per 1M tokens), so margin is always visible.
 * - credit_accounts / credit_transactions: the ledger. Amounts are integer
 *   micro-credits (1 credit = 1,000,000 micros) so no float ever touches a
 *   balance. A database CHECK keeps balances from going negative and holds
 *   from exceeding the balance, whatever the application code does.
 * - request_logs: one row per model call, with the hold, the charge, our
 *   cost and the outcome.
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      ALTER TABLE ai_models
        ADD COLUMN aggregator_model_id varchar(150),
        ADD COLUMN context_window integer,
        ADD COLUMN max_output_tokens integer,
        ADD COLUMN input_cost_per_mtok numeric(14,4),
        ADD COLUMN output_cost_per_mtok numeric(14,4),
        ADD COLUMN input_credits_per_mtok numeric(14,4),
        ADD COLUMN output_credits_per_mtok numeric(14,4);

      CREATE TABLE credit_accounts (
        user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        balance_micros bigint NOT NULL DEFAULT 0,
        held_micros bigint NOT NULL DEFAULT 0,
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        CONSTRAINT credit_accounts_held_non_negative CHECK (held_micros >= 0),
        CONSTRAINT credit_accounts_hold_within_balance CHECK (held_micros <= balance_micros)
      );

      CREATE TABLE credit_transactions (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid REFERENCES users(id) ON DELETE SET NULL,
        type varchar(20) NOT NULL CHECK (type IN ('grant', 'charge', 'adjustment', 'refund')),
        amount_micros bigint NOT NULL,
        balance_after_micros bigint NOT NULL,
        request_id uuid,
        reason text,
        created_by uuid REFERENCES users(id) ON DELETE SET NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_credit_transactions_user ON credit_transactions (user_id, created_at DESC);
      -- At most one charge (or refund) per request: retries can't double-bill.
      CREATE UNIQUE INDEX uniq_credit_transactions_request
        ON credit_transactions (request_id, type) WHERE request_id IS NOT NULL;

      CREATE TABLE request_logs (
        id uuid PRIMARY KEY,
        user_id uuid REFERENCES users(id) ON DELETE SET NULL,
        chat_id uuid,
        model_id uuid REFERENCES ai_models(id) ON DELETE SET NULL,
        route varchar(30) NOT NULL,
        upstream_model varchar(150) NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'in_progress'
          CHECK (status IN ('in_progress', 'succeeded', 'failed', 'cancelled')),
        error_code varchar(60),
        input_tokens integer,
        output_tokens integer,
        usage_estimated boolean NOT NULL DEFAULT false,
        held_micros bigint NOT NULL DEFAULT 0,
        charged_micros bigint NOT NULL DEFAULT 0,
        unbilled_micros bigint NOT NULL DEFAULT 0,
        cost_usd_micros bigint NOT NULL DEFAULT 0,
        first_token_ms integer,
        duration_ms integer,
        created_at timestamptz NOT NULL DEFAULT now(),
        finished_at timestamptz
      );
      CREATE INDEX idx_request_logs_user ON request_logs (user_id, created_at DESC);
      CREATE INDEX idx_request_logs_in_progress ON request_logs (created_at) WHERE status = 'in_progress';
      CREATE INDEX idx_request_logs_created ON request_logs (created_at DESC);
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP TABLE IF EXISTS request_logs;
    DROP TABLE IF EXISTS credit_transactions;
    DROP TABLE IF EXISTS credit_accounts;
    ALTER TABLE ai_models
      DROP COLUMN IF EXISTS aggregator_model_id,
      DROP COLUMN IF EXISTS context_window,
      DROP COLUMN IF EXISTS max_output_tokens,
      DROP COLUMN IF EXISTS input_cost_per_mtok,
      DROP COLUMN IF EXISTS output_cost_per_mtok,
      DROP COLUMN IF EXISTS input_credits_per_mtok,
      DROP COLUMN IF EXISTS output_credits_per_mtok;
  `);
}

module.exports = { up, down };
