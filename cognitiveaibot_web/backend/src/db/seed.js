#!/usr/bin/env node
require('dotenv').config();
const { sequelize } = require('../config/database');
const { initDatabase } = require('./init');
const { seed: seedModels } = require('./seeds/01-ai-models');
const { getOrCreateDemoUser } = require('./seeds/02-demo-user');
const { seed: seedChatHistory } = require('./seeds/03-chat-history');
const { seed: seedUsage } = require('./seeds/04-usage-demo');
const { seed: seedUserSettings } = require('./seeds/05-user-settings');
const { seed: seedPlans } = require('./seeds/06-plans');

async function run() {
  if (!process.env.DATABASE_URL) {
    console.error('Error: DATABASE_URL is not set. Create a .env file from .env.example');
    process.exit(1);
  }
  try {
    await initDatabase();
    await seedModels();
    const userId = await getOrCreateDemoUser();
    await seedChatHistory(userId);
    await seedUsage(userId);
    await seedUserSettings(userId);
    await seedPlans();
    console.log('Seed completed successfully');
    process.exit(0);
  } catch (err) {
    console.error('Seed failed:', err);
    process.exit(1);
  } finally {
    await sequelize.close();
  }
}

run();
