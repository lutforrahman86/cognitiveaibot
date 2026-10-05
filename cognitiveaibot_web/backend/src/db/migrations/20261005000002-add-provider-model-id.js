/**
 * The id the provider's API expects (e.g. "gemini-2.0-flash"), which is not
 * always our slug ("gemini-2-flash"). A model with no provider_model_id is
 * listed but cannot be called.
 *
 * Only models whose provider has an adapter (src/gateway/providers.js) are
 * mapped here. These ids were current when written; run
 * `npm run models:verify` with a valid key to check them against the
 * provider's live model list.
 */
const PROVIDER_MODEL_IDS = {
  'gpt-4o': 'gpt-4o',
  'gpt-4o-mini': 'gpt-4o-mini',
  'gpt-4-turbo': 'gpt-4-turbo',
  'gemini-2-flash': 'gemini-2.0-flash',
};

async function up({ context: { sequelize, queryInterface } }) {
  const { DataTypes } = require('sequelize');
  await sequelize.transaction(async (transaction) => {
    await queryInterface.addColumn(
      'ai_models',
      'provider_model_id',
      { type: DataTypes.STRING(150), allowNull: true },
      { transaction }
    );
    for (const [slug, providerModelId] of Object.entries(PROVIDER_MODEL_IDS)) {
      await sequelize.query(
        'UPDATE ai_models SET provider_model_id = :providerModelId WHERE slug = :slug',
        { replacements: { slug, providerModelId }, transaction }
      );
    }
  });
}

async function down({ context: { queryInterface } }) {
  await queryInterface.removeColumn('ai_models', 'provider_model_id');
}

module.exports = { up, down, PROVIDER_MODEL_IDS };
