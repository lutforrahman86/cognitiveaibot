#!/usr/bin/env node
// Usage: npm run db:migrate            apply pending migrations
//        npm run db:migrate -- status  list applied and pending migrations
require('dotenv').config();
const { sequelize } = require('../config/database');
const { createMigrator } = require('./migrator');

async function run() {
  const migrator = createMigrator({ logger: console });
  try {
    if (process.argv[2] === 'status') {
      const executed = await migrator.executed();
      const pending = await migrator.pending();
      for (const m of executed) console.log(`applied  ${m.name}`);
      for (const m of pending) console.log(`pending  ${m.name}`);
    } else {
      const applied = await migrator.up();
      console.log(applied.length ? `Applied ${applied.length} migration(s)` : 'Nothing to apply');
    }
  } catch (err) {
    console.error('Migration failed:', err.message);
    process.exitCode = 1;
  } finally {
    await sequelize.close();
  }
}

run();
