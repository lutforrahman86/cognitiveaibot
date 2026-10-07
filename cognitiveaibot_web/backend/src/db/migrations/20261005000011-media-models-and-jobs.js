/**
 * Images, audio, embeddings and video (roadmap A1, F4).
 *
 * - ai_models.api_kind says which endpoint a model serves: chat, embedding,
 *   image, speech, transcription or video. Chat surfaces only list chat models.
 * - ai_models.pricing_unit says what a model is billed by. 'token' and
 *   'character' use the per-1M-unit prices (input/output_*_per_mtok);
 *   'second' uses unit_cost_usd / unit_credits per second (transcription is
 *   billed per second of audio, video per second generated).
 * - request_logs record the units billed for non-token calls.
 * - media_jobs: long-running generations (video). A job keeps its credit
 *   hold until it finishes; workers claim jobs with FOR UPDATE SKIP LOCKED, so
 *   several server processes can share the queue without double work.
 * - The OpenAI media models are added from the media catalog snapshot.
 */
const { applyCatalog } = require('../catalog');
const catalog = require('../data/model-catalog-media-2026-10-05.json');

async function up({ context: { sequelize } }) {
  await sequelize.transaction(async (transaction) => {
    await sequelize.query(
      `
      ALTER TABLE ai_models
        ADD COLUMN api_kind varchar(20) NOT NULL DEFAULT 'chat'
          CHECK (api_kind IN ('chat', 'embedding', 'image', 'speech', 'transcription', 'video')),
        ADD COLUMN pricing_unit varchar(12) NOT NULL DEFAULT 'token'
          CHECK (pricing_unit IN ('token', 'character', 'second')),
        ADD COLUMN unit_cost_usd numeric(14,6),
        ADD COLUMN unit_credits numeric(14,6);

      ALTER TABLE request_logs
        ADD COLUMN unit varchar(12),
        ADD COLUMN units numeric(14,3);

      CREATE TABLE media_jobs (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id uuid REFERENCES users(id) ON DELETE CASCADE,
        api_key_id uuid REFERENCES api_keys(id) ON DELETE SET NULL,
        request_id uuid NOT NULL REFERENCES request_logs(id),
        model_id uuid REFERENCES ai_models(id) ON DELETE SET NULL,
        kind varchar(20) NOT NULL DEFAULT 'video',
        provider_job_id varchar(150) NOT NULL,
        status varchar(20) NOT NULL DEFAULT 'queued'
          CHECK (status IN ('queued', 'in_progress', 'completed', 'failed')),
        progress smallint NOT NULL DEFAULT 0,
        params jsonb NOT NULL DEFAULT '{}',
        output_path text,
        output_bytes bigint,
        error_code varchar(60),
        attempts integer NOT NULL DEFAULT 0,
        next_poll_at timestamptz NOT NULL DEFAULT now(),
        created_at timestamptz NOT NULL DEFAULT now(),
        updated_at timestamptz NOT NULL DEFAULT now(),
        completed_at timestamptz,
        expires_at timestamptz
      );
      CREATE INDEX idx_media_jobs_pending ON media_jobs (next_poll_at) WHERE status IN ('queued', 'in_progress');
      CREATE INDEX idx_media_jobs_user ON media_jobs (user_id, created_at DESC);
      `,
      { transaction }
    );
    await applyCatalog(sequelize, catalog, { transaction });
  });
}

async function down({ context: { sequelize } }) {
  await sequelize.query(`
    DROP TABLE IF EXISTS media_jobs;
    ALTER TABLE request_logs DROP COLUMN IF EXISTS unit, DROP COLUMN IF EXISTS units;
    DELETE FROM ai_models WHERE api_kind <> 'chat'
      AND NOT EXISTS (SELECT 1 FROM request_logs r WHERE r.model_id = ai_models.id);
    ALTER TABLE ai_models
      DROP COLUMN IF EXISTS api_kind, DROP COLUMN IF EXISTS pricing_unit,
      DROP COLUMN IF EXISTS unit_cost_usd, DROP COLUMN IF EXISTS unit_credits;
  `);
}

module.exports = { up, down };
