const { sequelize } = require('../../config/database');
const { applyCatalog } = require('../catalog');
// The newest catalog snapshot. Migrations already apply it; seeding only adds
// models that are missing, so admins' edits in the Models tab are kept.
const catalog = require('../data/model-catalog-2026-10-05.json');
const mediaCatalog = require('../data/model-catalog-media-2026-10-05.json');

async function seed() {
  const count =
    (await applyCatalog(sequelize, catalog, { onlyMissing: true })) +
    (await applyCatalog(sequelize, mediaCatalog, { onlyMissing: true }));
  console.log(`AI models: ${count} in the catalog, missing ones added`);
}

module.exports = { seed };
