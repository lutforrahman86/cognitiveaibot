/**
 * A chat temperature is now sent to the model only when a user sets one.
 * The old 0.7 default would be sent with every reply, and reasoning models
 * (GPT-5 and later) reject any temperature but their own. NULL means "the
 * model's default"; rows still at the untouched 0.7 default become NULL.
 */
async function up({ context: { sequelize } }) {
  await sequelize.query(`
    ALTER TABLE user_settings ALTER COLUMN temperature DROP DEFAULT;
    UPDATE user_settings SET temperature = NULL WHERE temperature = 0.7;
  `);
}

async function down({ context: { sequelize } }) {
  await sequelize.query('ALTER TABLE user_settings ALTER COLUMN temperature SET DEFAULT 0.7');
}

module.exports = { up, down };
