const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const UsageLimit = sequelize.define(
  'UsageLimit',
  {
    user_id: {
      type: DataTypes.UUID,
      primaryKey: true,
    },
    limit_amount: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 16,
    },
    limit_period: {
      type: DataTypes.STRING(20),
      defaultValue: 'monthly',
    },
  },
  {
    tableName: 'usage_limits',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

UsageLimit.findByUserId = async function (userId) {
  const u = await UsageLimit.findByPk(userId);
  return u
    ? u.get({ plain: true })
    : { user_id: userId, limit_amount: 16, limit_period: 'monthly' };
};

const _baseUpsert = UsageLimit.upsert.bind(UsageLimit);
UsageLimit.upsert = async function (userId, data) {
  const { limit_amount, limit_period } = data;
  const [u] = await _baseUpsert({
    user_id: userId,
    limit_amount: limit_amount ?? 16,
    limit_period: limit_period ?? 'monthly',
  });
  return u.get({ plain: true });
};

module.exports = UsageLimit;
