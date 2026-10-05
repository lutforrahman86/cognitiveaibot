/**
 * sequelize.sync({ alter: true }) adds a fresh UNIQUE constraint on every
 * `unique: true` column each time the server starts, so a long-lived dev
 * database ends up with dozens of identical constraints (users_email_key,
 * users_email_key1, users_email_key2, …). Each is a separate index that every
 * insert and update has to maintain.
 *
 * Keeps one constraint per (table, columns) and drops the rest. A database
 * built from the baseline has no duplicates, so there this is a no-op.
 */
async function dropDuplicateUniqueConstraints(sequelize, { transaction } = {}) {
  const { QueryTypes } = require('sequelize');
  const constraints = await sequelize.query(
    `SELECT c.conrelid::regclass::text AS table_name,
            c.conname AS name,
            array_to_string(array_agg(a.attname ORDER BY a.attname), ',') AS columns
       FROM pg_constraint c
       JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
      WHERE c.contype = 'u' AND c.connamespace = 'public'::regnamespace
      GROUP BY c.conrelid, c.conname`,
    { type: QueryTypes.SELECT, transaction }
  );

  const groups = new Map();
  for (const c of constraints) {
    const key = `${c.table_name}(${c.columns})`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(c);
  }

  const dropped = [];
  for (const group of groups.values()) {
    if (group.length < 2) continue;
    // Keep the un-numbered original (users_email_key) when it exists.
    group.sort((a, b) => a.name.length - b.name.length || a.name.localeCompare(b.name));
    for (const extra of group.slice(1)) {
      await sequelize.query(
        `ALTER TABLE ${extra.table_name} DROP CONSTRAINT "${extra.name}"`,
        { transaction }
      );
      dropped.push(extra.name);
    }
  }
  return dropped;
}

async function up({ context: { sequelize } }) {
  await sequelize.transaction((transaction) =>
    dropDuplicateUniqueConstraints(sequelize, { transaction })
  );
}

async function down() {
  // Recreating redundant constraints would restore the problem, not undo a change.
}

module.exports = { up, down, dropDuplicateUniqueConstraints };
