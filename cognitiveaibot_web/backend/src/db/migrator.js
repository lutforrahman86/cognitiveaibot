const path = require('path');
const { Umzug, SequelizeStorage } = require('umzug');
const { sequelize } = require('../config/database');

/**
 * Schema changes live in src/db/migrations and are applied in filename order.
 * Applied migrations are recorded in the "SequelizeMeta" table (the same table
 * sequelize-cli uses), so each one runs exactly once per database.
 */
function createMigrator({ logger } = {}) {
  return new Umzug({
    migrations: {
      glob: path.join(__dirname, 'migrations', '*.js').replace(/\\/g, '/'),
    },
    context: { sequelize, queryInterface: sequelize.getQueryInterface() },
    storage: new SequelizeStorage({ sequelize }),
    logger,
  });
}

module.exports = { createMigrator };
