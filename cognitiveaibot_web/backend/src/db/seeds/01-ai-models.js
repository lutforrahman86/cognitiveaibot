const { sequelize } = require('../../config/database');
const { applyCatalog } = require('../catalog');
// The newest catalog snapshot. Migrations already apply it; seeding again is
// harmless and restores any model data edited by hand in development.
const catalog = require('../data/model-catalog-2026-10-05.json');

async function seed() {
  const count = await applyCatalog(sequelize, catalog);
  console.log(`Seeded ${count} AI models`);
}

module.exports = { seed };
