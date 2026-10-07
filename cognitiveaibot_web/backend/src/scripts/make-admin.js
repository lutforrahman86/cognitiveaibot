#!/usr/bin/env node
// Usage: npm run make-admin -- someone@example.com [--revoke]
//
// Makes an existing account an admin (or, with --revoke, a regular user
// again). This is how the first admin of a new installation is created: sign
// up normally, then run this on the server. The change is audit-logged.
require('dotenv').config();
const { sequelize } = require('../config/database');
const { logAdminAction } = require('../admin/audit');

async function main() {
  const email = (process.argv[2] || '').trim().toLowerCase();
  const revoke = process.argv.includes('--revoke');
  if (!email || email.startsWith('--')) {
    console.error('Usage: npm run make-admin -- someone@example.com [--revoke]');
    process.exit(1);
  }
  const [rows] = await sequelize.query('UPDATE users SET type = :type, updated_at = now() WHERE email = :email RETURNING id', {
    replacements: { email, type: revoke ? 'user' : 'admin' },
  });
  if (!rows.length) {
    console.error(`No account uses ${email}. Sign up first.`);
    process.exit(1);
  }
  await logAdminAction(null, revoke ? 'user.admin_revoke' : 'user.admin_grant', {
    targetType: 'user',
    targetId: rows[0].id,
    details: { email, via: 'make-admin script' },
  });
  console.log(`${email} is ${revoke ? 'no longer an admin' : 'now an admin'}.`);
}

main()
  .catch((err) => {
    console.error(err.message);
    process.exitCode = 1;
  })
  .finally(() => sequelize.close());
