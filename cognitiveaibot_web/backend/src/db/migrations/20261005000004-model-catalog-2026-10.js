/**
 * Replaces the original 13-model catalog with 46 current text/code models,
 * priced (see src/db/data/model-catalog-2026-10-05.json for sources and the
 * credit-price assumptions). Six of the original models are no longer offered
 * by their providers and are deactivated, not deleted, so old chats keep
 * their model name.
 *
 * The snapshot file is frozen: later catalog changes get a new snapshot and a
 * new migration (or, later, admin-approved catalog sync — roadmap A11).
 */
const { applyCatalog } = require('../catalog');
const catalog = require('../data/model-catalog-2026-10-05.json');

async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) => applyCatalog(sequelize, catalog, { transaction }));
}

async function down() {
  // Prices and routes are data; rolling them back would only restore stale ids.
}

module.exports = { up, down };
