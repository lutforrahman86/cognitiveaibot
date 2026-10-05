const bcrypt = require('bcrypt');
const { User } = require('../../models');

const DEMO_USER = {
  email: 'demo@cognitiveaibot.com',
  password: 'demo123456',
  name: 'Demo User',
};

async function getOrCreateDemoUser() {
  let row = await User.findOne({
    where: { email: DEMO_USER.email },
    attributes: ['id'],
    raw: true,
  });
  if (row?.id) {
    await User.update({ type: 'admin' }, { where: { email: DEMO_USER.email } });
    return row.id;
  }
  try {
    const passwordHash = await bcrypt.hash(DEMO_USER.password, 10);
    await User.create({
      email: DEMO_USER.email,
      password_hash: passwordHash,
      name: DEMO_USER.name,
      type: 'admin',
    });
    console.log('Created demo user:', DEMO_USER.email);
  } catch (err) {
    if (err.name !== 'SequelizeUniqueConstraintError') throw err;
  }
  row = await User.findOne({
    where: { email: DEMO_USER.email },
    attributes: ['id'],
    raw: true,
  });
  if (!row?.id) throw new Error('Failed to get demo user id');
  return row.id;
}

module.exports = { getOrCreateDemoUser, DEMO_USER };
