/**
 * Launch readiness: account recovery and safety (roadmap B18, E4, E5).
 *
 * - users.email_verified_at: set when the user follows the emailed link (or
 *   signs in with Google/GitHub). Existing accounts are treated as verified.
 * - users.password_changed_at: sessions issued before it are rejected, so
 *   resetting a password signs every other device out.
 * - auth_tokens: single-use, expiring email links (password reset, email
 *   verification). Only a SHA-256 hash of each token is stored.
 * - content_reports: replies users flag for review.
 * - admin_alerts: things an admin should look at (e.g. a spending spike).
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      ALTER TABLE users
        ADD COLUMN email_verified_at timestamptz,
        ADD COLUMN password_changed_at timestamptz;
      UPDATE users SET email_verified_at = created_at;

      CREATE TABLE auth_tokens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        purpose varchar(20) NOT NULL CHECK (purpose IN ('password_reset', 'verify_email')),
        token_hash char(64) NOT NULL UNIQUE,
        expires_at timestamptz NOT NULL,
        used_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_auth_tokens_user ON auth_tokens (user_id, purpose);

      CREATE TABLE content_reports (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        reporter_id uuid REFERENCES users(id) ON DELETE SET NULL,
        message_id uuid,
        chat_id uuid,
        model_name varchar(150),
        reason varchar(30) NOT NULL CHECK (reason IN ('harmful', 'sexual', 'hateful', 'violent', 'illegal', 'inaccurate', 'other')),
        details text,
        content_excerpt text,
        status varchar(20) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'actioned', 'dismissed')),
        reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
        reviewed_at timestamptz,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_content_reports_status ON content_reports (status, created_at DESC);

      CREATE TABLE admin_alerts (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        kind varchar(40) NOT NULL,
        user_id uuid REFERENCES users(id) ON DELETE CASCADE,
        details jsonb NOT NULL DEFAULT '{}',
        dedupe_key varchar(150) UNIQUE,
        resolved_at timestamptz,
        resolved_by uuid REFERENCES users(id) ON DELETE SET NULL,
        created_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE INDEX idx_admin_alerts_open ON admin_alerts (created_at DESC) WHERE resolved_at IS NULL;
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP TABLE IF EXISTS admin_alerts;
    DROP TABLE IF EXISTS content_reports;
    DROP TABLE IF EXISTS auth_tokens;
    ALTER TABLE users DROP COLUMN IF EXISTS email_verified_at, DROP COLUMN IF EXISTS password_changed_at;
  `);
}

module.exports = { up, down };
