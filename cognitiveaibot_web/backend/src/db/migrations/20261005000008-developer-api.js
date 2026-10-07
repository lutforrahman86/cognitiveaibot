/**
 * The developer API (roadmap C1–C4).
 *
 * - api_keys: keys look like "sk-cog-…" and are shown once. Only a SHA-256
 *   hash is stored (keys are 256-bit random, so a slow hash adds nothing),
 *   plus a short visible prefix so users can tell keys apart. Revoked keys
 *   are kept for the usage history.
 * - request_logs records where a call came from ('app' or 'api') and which
 *   key made it, for per-key usage.
 * - plans gain per-account API limits: requests and tokens per minute.
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      CREATE TABLE api_keys (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        name varchar(100) NOT NULL,
        key_hash char(64) NOT NULL UNIQUE,
        prefix varchar(20) NOT NULL,
        last_used_at timestamptz,
        revoked_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_api_keys_user ON api_keys (user_id, created_at DESC);

      ALTER TABLE request_logs
        ADD COLUMN source varchar(10) NOT NULL DEFAULT 'app' CHECK (source IN ('app', 'api')),
        ADD COLUMN api_key_id uuid REFERENCES api_keys(id) ON DELETE SET NULL;
      CREATE INDEX idx_request_logs_api ON request_logs (user_id, created_at DESC) WHERE source = 'api';

      ALTER TABLE plans
        ADD COLUMN api_requests_per_minute integer NOT NULL DEFAULT 60 CHECK (api_requests_per_minute > 0),
        ADD COLUMN api_tokens_per_minute integer NOT NULL DEFAULT 200000 CHECK (api_tokens_per_minute > 0);
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    ALTER TABLE plans DROP COLUMN IF EXISTS api_requests_per_minute, DROP COLUMN IF EXISTS api_tokens_per_minute;
    DROP INDEX IF EXISTS idx_request_logs_api;
    ALTER TABLE request_logs DROP COLUMN IF EXISTS api_key_id, DROP COLUMN IF EXISTS source;
    DROP TABLE IF EXISTS api_keys;
  `);
}

module.exports = { up, down };
