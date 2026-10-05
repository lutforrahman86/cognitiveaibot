/**
 * Loads a model catalog snapshot (src/db/data/model-catalog-*.json) into
 * ai_models: adds new models, updates known ones by slug, and deactivates
 * retired ones. Idempotent, so both the migration and `npm run seed` use it.
 */
const COLUMNS = [
  'name',
  'provider',
  'category',
  'display_order',
  'provider_model_id',
  'aggregator_model_id',
  'context_window',
  'max_output_tokens',
  'input_cost_per_mtok',
  'output_cost_per_mtok',
  'input_credits_per_mtok',
  'output_credits_per_mtok',
];

async function applyCatalog(sequelize, catalog, { transaction } = {}) {
  for (const model of catalog.models) {
    const values = Object.fromEntries(COLUMNS.map((c) => [c, model[c] ?? null]));
    await sequelize.query(
      `INSERT INTO ai_models (id, slug, ${COLUMNS.join(', ')}, is_active, created_at, updated_at)
       VALUES (gen_random_uuid(), :slug, ${COLUMNS.map((c) => `:${c}`).join(', ')}, true, now(), now())
       ON CONFLICT (slug) DO UPDATE SET
         ${COLUMNS.map((c) => `${c} = EXCLUDED.${c}`).join(', ')},
         is_active = true,
         updated_at = now()`,
      { replacements: { slug: model.slug, ...values }, transaction }
    );
  }
  if (catalog.retired_slugs?.length) {
    await sequelize.query(
      `UPDATE ai_models SET is_active = false, provider_model_id = NULL, aggregator_model_id = NULL,
              updated_at = now()
        WHERE slug IN (:slugs)`,
      { replacements: { slugs: catalog.retired_slugs }, transaction }
    );
  }
  return catalog.models.length;
}

module.exports = { applyCatalog };
