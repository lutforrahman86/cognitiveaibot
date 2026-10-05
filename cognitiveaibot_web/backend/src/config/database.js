const { Sequelize } = require('sequelize');

function getSequelizeConfig() {
  if (process.env.DATABASE_URL) {
    const url = process.env.DATABASE_URL.replace(/^postgresql:/, 'postgres:');
    return { url };
  }
  return {
    dialect: 'postgres',
    host: process.env.DB_HOST || process.env.PGHOST || 'localhost',
    port: process.env.DB_PORT || process.env.PGPORT || 5432,
    database: process.env.DB_DATABASE || process.env.PGDATABASE || 'cognitiveaibot',
    username: process.env.DB_USERNAME || process.env.PGUSER || 'postgres',
    password: process.env.DB_PASSWORD ?? process.env.PGPASSWORD ?? '',
    dialectOptions: {
      connectTimeout: 10000,
    },
  };
}

const config = getSequelizeConfig();
const sequelize = config.url
  ? new Sequelize(config.url, {
      dialect: 'postgres',
      dialectOptions: { connectTimeout: 10000 },
      logging: false,
    })
  : new Sequelize(config.database, config.username, config.password, {
      host: config.host,
      port: config.port,
      dialect: 'postgres',
      dialectOptions: config.dialectOptions,
      logging: false,
    });

sequelize.authenticate().catch((err) => {
  console.error('Database connection error:', err.message);
});

module.exports = { sequelize, Sequelize };
