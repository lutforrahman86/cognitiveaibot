const fs = require('fs');
const path = require('path');

/**
 * The schema as it existed before migrations were introduced, when every
 * startup ran sequelize.sync({ alter: true }).
 *
 * Existing database: `users` is already there, so this does nothing and the
 * later migrations bring it up to date. Fresh database: creates every table
 * from the baseline SQL.
 */
async function up({ context: { sequelize } }) {
  const [[row]] = await sequelize.query("SELECT to_regclass('public.users') AS existing");
  if (row.existing) return;

  const sql = fs.readFileSync(path.join(__dirname, '00000000000000-baseline.sql'), 'utf8');
  await sequelize.transaction((transaction) => sequelize.query(sql, { transaction }));
}

async function down() {
  // Undoing the baseline means dropping every table, which is never what
  // someone running a migration rollback expects.
  throw new Error('The baseline migration cannot be undone. Drop the database instead.');
}

module.exports = { up, down };
