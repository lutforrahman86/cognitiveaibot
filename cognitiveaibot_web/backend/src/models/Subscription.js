const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Subscription = sequelize.define(
  'Subscription',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    user_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    revenuecat_customer_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    product_id: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    status: {
      type: DataTypes.STRING(50),
      defaultValue: 'active',
    },
    started_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    expires_at: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  },
  {
    tableName: 'subscriptions',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

Subscription.findByUserId = async function (userId) {
  const s = await Subscription.findOne({
    where: { user_id: userId, status: 'active' },
    order: [['expires_at', 'DESC NULLS FIRST']],
  });
  return s ? s.get({ plain: true }) : null;
};

Subscription.hasProAccess = async function (userId) {
  const sub = await Subscription.findByUserId(userId);
  if (!sub) return false;
  if (!sub.expires_at) return true;
  return new Date(sub.expires_at) > new Date();
};

const _baseCreate = Subscription.create.bind(Subscription);
Subscription.upsert = async function (userId, data) {
  const {
    revenuecat_customer_id,
    product_id,
    status = 'active',
    started_at,
    expires_at,
  } = data;
  const s = await _baseCreate({
    user_id: userId,
    revenuecat_customer_id: revenuecat_customer_id || null,
    product_id: product_id || null,
    status,
    started_at: started_at || new Date(),
    expires_at: expires_at || null,
  });
  return s.get({ plain: true });
};


Subscription.findAllWithUsers = async function (options = {}) {
  const { limit = 100 } = options;
  const User = require('./User');
  const rows = await Subscription.findAll({
    include: [{ model: User, attributes: ['email', 'name'], required: true }],
    order: [['created_at', 'DESC']],
    limit,
    raw: true,
    nest: true,
  });
  return rows.map((r) => ({
    ...r,
    email: r.User?.email,
    name: r.User?.name,
    User: undefined,
  }));
};

module.exports = Subscription;
