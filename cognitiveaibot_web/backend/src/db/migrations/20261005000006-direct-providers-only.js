/**
 * Direct providers only (ROADMAP Decision 1, decided 2026-10-05): every model
 * is called with its own provider's key, never through an aggregator.
 *
 * - Drops ai_models.aggregator_model_id, the OpenRouter route.
 * - Retires gpt-oss-120b: OpenAI doesn't serve it through its API, so it has
 *   no direct route. Kept inactive, not deleted, so old chats keep its name.
 */
async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    sequelize.query(
      `
      UPDATE ai_models SET is_active = false, provider_model_id = NULL, updated_at = now()
       WHERE slug = 'gpt-oss-120b';
      ALTER TABLE ai_models DROP COLUMN aggregator_model_id;
      `,
      { transaction }
    )
  );
}

async function down({ context: { sequelize } }) {
  // The aggregator ids aren't restored: the route is not to be used again.
  await sequelize.query('ALTER TABLE ai_models ADD COLUMN aggregator_model_id varchar(150)');
}

module.exports = { up, down };
