/**
 * Loads a model catalog snapshot (src/db/data/model-catalog-*.json) into
 * ai_models: adds new models, updates known ones by slug, and deactivates
 * retired ones. Idempotent, so both the migration and `npm run seed` use it.
 *
 * With `onlyMissing`, models that already exist are left untouched, so
 * re-seeding never undoes an admin's edits (prices, tiers, on/off).
 */
const COLUMNS = [
  'name',
  'provider',
  'category',
  'display_order',
  'provider_model_id',
  'context_window',
  'max_output_tokens',
  'input_cost_per_mtok',
  'output_cost_per_mtok',
  'input_credits_per_mtok',
  'output_credits_per_mtok',
  'api_kind',
  'pricing_unit',
  'unit_cost_usd',
  'unit_credits',
  'input_modalities',
  'output_modalities',
  'supports_streaming',
];

async function applyCatalog(sequelize, catalog, { transaction, onlyMissing = false } = {}) {
  for (const model of catalog.models) {
    // Only the fields a snapshot gives; the rest keep their database defaults
    // (older snapshots predate later columns).
    const columns = COLUMNS.filter((c) => c in model);
    const values = Object.fromEntries(columns.map((c) => [c, model[c] ?? null]));
    const placeholder = (c) =>
      Array.isArray(values[c]) ? `CAST(ARRAY[${values[c].map((_, i) => `:${c}_${i}`).join(', ')}] AS text[])` : `:${c}`;
    for (const c of columns) {
      if (Array.isArray(values[c])) values[c].forEach((v, i) => (values[`${c}_${i}`] = v));
    }
    await sequelize.query(
      `INSERT INTO ai_models (id, slug, ${columns.join(', ')}, is_active, created_at, updated_at)
       VALUES (gen_random_uuid(), :slug, ${columns.map(placeholder).join(', ')}, true, now(), now())
       ON CONFLICT (slug) DO ${onlyMissing ? 'NOTHING' : `UPDATE SET
         ${columns.map((c) => `${c} = EXCLUDED.${c}`).join(', ')},
         is_active = true,
         updated_at = now()`}`,
      { replacements: { slug: model.slug, ...values }, transaction }
    );
  }
  if (catalog.retired_slugs?.length && !onlyMissing) {
    await sequelize.query(
      `UPDATE ai_models SET is_active = false, provider_model_id = NULL, updated_at = now()
        WHERE slug IN (:slugs)`,
      { replacements: { slugs: catalog.retired_slugs }, transaction }
    );
  }
  return catalog.models.length;
}

module.exports = { applyCatalog };
