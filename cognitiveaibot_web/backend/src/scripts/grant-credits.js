#!/usr/bin/env node
// Usage: npm run credits:grant -- <email> <credits> [reason]
//
// Adds (or, with a negative number, removes) credits for one user, recorded
// in credit_transactions like an admin adjustment. For development and
// support; admins can do the same from the admin panel.
require('dotenv').config();
const { sequelize } = require('../config/database');
const User = require('../models/User');
const { addCredits } = require('../gateway/metering');

async function run() {
  const [email, amount, ...reasonWords] = process.argv.slice(2);
  const credits = Number(amount);
  if (!email || !Number.isFinite(credits) || credits === 0) {
    console.error('Usage: npm run credits:grant -- <email> <credits> [reason]');
    process.exitCode = 1;
    return;
  }
  const user = await User.findOne({ where: { email: email.trim().toLowerCase() }, attributes: ['id'] });
  if (!user) {
    console.error(`No user with email ${email}`);
    process.exitCode = 1;
    return;
  }
  const { balance } = await addCredits(user.id, credits, {
    type: credits > 0 ? 'grant' : 'adjustment',
    reason: reasonWords.join(' ') || 'Granted from the command line',
  });
  console.log(`${email}: ${credits > 0 ? '+' : ''}${credits} credits, balance now ${balance.toFixed(2)}`);
}

run()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => sequelize.close());
