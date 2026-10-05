const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { resetDatabase } = require('./helpers');

const { createMigrator } = require('../src/db/migrator');
const {
  dropDuplicateUniqueConstraints,
} = require('../src/db/migrations/20261005000001-drop-duplicate-unique-constraints');

let sequelize;

before(async () => {
  sequelize = await resetDatabase();
});

after(async () => {
  await sequelize.close();
});

async function uniqueConstraintsOn(table, column) {
  const rows = await sequelize.query(
    `SELECT c.conname FROM pg_constraint c
       JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
      WHERE c.contype = 'u' AND c.conrelid = :table::regclass AND a.attname = :column
        AND array_length(c.conkey, 1) = 1`,
    { replacements: { table, column }, type: require('sequelize').QueryTypes.SELECT }
  );
  return rows.map((r) => r.conname);
}

test('a fresh database is built entirely from migrations', async () => {
  const [tables] = await sequelize.query(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename"
  );
  assert.deepEqual(
    tables.map((t) => t.tablename),
    [
      'SequelizeMeta',
      'admin_actions',
      'ai_models',
      'api_keys',
      'billing_events',
      'chats',
      'credit_accounts',
      'credit_transactions',
      'media_jobs',
      'messages',
      'plans',
      'request_logs',
      'subscriptions',
      'usage_limits',
      'usage_records',
      'user_settings',
      'users',
    ]
  );
  const [[column]] = await sequelize.query(
    "SELECT data_type FROM information_schema.columns WHERE table_name = 'ai_models' AND column_name = 'provider_model_id'"
  );
  assert.equal(column.data_type, 'character varying');
});

test('the baseline has exactly one unique constraint per unique column', async () => {
  assert.deepEqual(await uniqueConstraintsOn('users', 'email'), ['users_email_key']);
  assert.deepEqual(await uniqueConstraintsOn('ai_models', 'slug'), ['ai_models_slug_key']);
});

test('nothing is pending after migrating, so a restart changes nothing', async () => {
  const pending = await createMigrator({ logger: undefined }).pending();
  assert.equal(pending.length, 0);
});

test('duplicate unique constraints left by sync({ alter: true }) are dropped, keeping the original', async () => {
  await sequelize.query('ALTER TABLE users ADD CONSTRAINT users_email_key1 UNIQUE (email)');
  await sequelize.query('ALTER TABLE users ADD CONSTRAINT users_email_key2 UNIQUE (email)');
  await sequelize.query('ALTER TABLE ai_models ADD CONSTRAINT ai_models_slug_key1 UNIQUE (slug)');

  const dropped = await dropDuplicateUniqueConstraints(sequelize);

  assert.deepEqual(dropped.sort(), ['ai_models_slug_key1', 'users_email_key1', 'users_email_key2']);
  assert.deepEqual(await uniqueConstraintsOn('users', 'email'), ['users_email_key']);
  assert.deepEqual(await uniqueConstraintsOn('ai_models', 'slug'), ['ai_models_slug_key']);
  // Emails are still unique afterwards.
  await sequelize.query(
    "INSERT INTO users (id, email, created_at, updated_at) VALUES (gen_random_uuid(), 'dup@example.test', now(), now())"
  );
  await assert.rejects(
    sequelize.query(
      "INSERT INTO users (id, email, created_at, updated_at) VALUES (gen_random_uuid(), 'dup@example.test', now(), now())"
    ),
    /unique/i
  );
});
