const { sequelize } = require('../config/database');
const { createMigrator } = require('./migrator');

/**
 * Connects and applies any pending migrations. The schema is never
 * auto-synced from the model definitions: change it with a new file in
 * src/db/migrations.
 *
 * Set DB_AUTO_MIGRATE=false when migrations run as a separate deploy step
 * (`npm run db:migrate`), e.g. with several server instances starting at once.
 */
async function initDatabase({ logger } = {}) {
  await sequelize.authenticate();
  console.log('Database connected');

  require('../models');
  if (process.env.DB_AUTO_MIGRATE === 'false') return;

  const applied = await createMigrator({ logger }).up();
  console.log(
    applied.length
      ? `Applied ${applied.length} migration(s): ${applied.map((m) => m.name).join(', ')}`
      : 'Database schema up to date'
  );
}

module.exports = { initDatabase };
