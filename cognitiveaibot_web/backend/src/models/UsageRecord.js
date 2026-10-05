const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
const { Op } = require('sequelize');

const UsageRecord = sequelize.define(
  'UsageRecord',
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
    model_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    record_date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    tokens_input: {
      type: DataTypes.BIGINT,
      defaultValue: 0,
    },
    tokens_output: {
      type: DataTypes.BIGINT,
      defaultValue: 0,
    },
    cost: {
      type: DataTypes.DECIMAL(12, 4),
      defaultValue: 0,
    },
  },
  {
    tableName: 'usage_records',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: false,
    indexes: [{ unique: true, fields: ['user_id', 'model_id', 'record_date'] }],
  }
);

UsageRecord.findByUserId = async function (userId, options = {}) {
  const { startDate, endDate, limit = 30 } = options;
  const AIModel = require('./AIModel');
  const where = { user_id: userId };
  if (startDate) where.record_date = { [Op.gte]: startDate };
  if (endDate) where.record_date = { ...where.record_date, [Op.lte]: endDate };
  const rows = await UsageRecord.findAll({
    where,
    include: [{ model: AIModel, attributes: ['name', 'provider'], required: false }],
    order: [['record_date', 'DESC']],
    limit,
    raw: true,
  });
  return rows.map((r) => ({
    ...r,
    model_name: r['AIModel.name'],
    provider: r['AIModel.provider'],
    'AIModel.name': undefined,
    'AIModel.provider': undefined,
  }));
};

UsageRecord.getDailyTotals = async function (userId, days = 7) {
  const { QueryTypes } = require('sequelize');
  return await sequelize.query(
    `SELECT record_date, SUM(tokens_input + tokens_output) as tokens, SUM(cost) as cost
     FROM usage_records
     WHERE user_id = :userId AND record_date >= CURRENT_DATE - INTERVAL '1 day' * :days
     GROUP BY record_date
     ORDER BY record_date ASC`,
    { replacements: { userId, days }, type: QueryTypes.SELECT }
  );
};

UsageRecord.getModelBreakdown = async function (userId, days = 30) {
  const { QueryTypes } = require('sequelize');
  return await sequelize.query(
    `SELECT am.name, am.provider, SUM(ur.cost) as total_cost, SUM(ur.tokens_input + ur.tokens_output) as total_tokens
     FROM usage_records ur
     LEFT JOIN ai_models am ON ur.model_id = am.id
     WHERE ur.user_id = :userId AND ur.record_date >= CURRENT_DATE - INTERVAL '1 day' * :days
     GROUP BY am.id, am.name, am.provider
     ORDER BY total_cost DESC`,
    { replacements: { userId, days }, type: QueryTypes.SELECT }
  );
};

UsageRecord.getTotals = async function (userId, startDate, endDate) {
  const { QueryTypes } = require('sequelize');
  const [row] = await sequelize.query(
    `SELECT 
       COALESCE(SUM(cost), 0)::decimal as total_cost,
       COALESCE(SUM(tokens_input + tokens_output), 0)::bigint as total_tokens
     FROM usage_records
     WHERE user_id = :userId AND record_date >= :startDate AND record_date <= :endDate`,
    {
      replacements: { userId, startDate, endDate },
      type: QueryTypes.SELECT,
    }
  );
  return row || { total_cost: 0, total_tokens: 0 };
};

UsageRecord.upsert = async function (userId, modelId, recordDate, data) {
  const { tokens_input = 0, tokens_output = 0, cost = 0 } = data;
  const [r, created] = await UsageRecord.findOrCreate({
    where: { user_id: userId, model_id: modelId, record_date: recordDate },
    defaults: { tokens_input, tokens_output, cost },
  });
  if (!created) {
    await r.increment({ tokens_input, tokens_output, cost });
    await r.reload();
  }
  return r.get({ plain: true });
};

UsageRecord.getAdminTotals = async function (days = 30) {
  const { QueryTypes } = require('sequelize');
  const [row] = await sequelize.query(
    `SELECT 
       COALESCE(SUM(cost), 0)::decimal as total_cost,
       COALESCE(SUM(tokens_input + tokens_output), 0)::bigint as total_tokens
     FROM usage_records
     WHERE record_date >= CURRENT_DATE - INTERVAL '1 day' * :days`,
    { replacements: { days }, type: QueryTypes.SELECT }
  );
  return row || { total_cost: 0, total_tokens: 0 };
};

UsageRecord.getAdminDailyTotals = async function (days = 14) {
  const { QueryTypes } = require('sequelize');
  return await sequelize.query(
    `SELECT record_date, 
       SUM(tokens_input + tokens_output) as tokens, 
       SUM(cost) as cost,
       COUNT(DISTINCT user_id) as active_users
     FROM usage_records
     WHERE record_date >= CURRENT_DATE - INTERVAL '1 day' * :days
     GROUP BY record_date
     ORDER BY record_date ASC`,
    { replacements: { days }, type: QueryTypes.SELECT }
  );
};

UsageRecord.getAdminModelBreakdown = async function (days = 30) {
  const { QueryTypes } = require('sequelize');
  return await sequelize.query(
    `SELECT am.name, am.provider, am.slug,
       SUM(ur.cost)::decimal as total_cost,
       SUM(ur.tokens_input + ur.tokens_output)::bigint as total_tokens,
       COUNT(DISTINCT ur.user_id) as user_count
     FROM usage_records ur
     LEFT JOIN ai_models am ON ur.model_id = am.id
     WHERE ur.record_date >= CURRENT_DATE - INTERVAL '1 day' * :days
     GROUP BY am.id, am.name, am.provider, am.slug
     ORDER BY total_cost DESC`,
    { replacements: { days }, type: QueryTypes.SELECT }
  );
};

module.exports = UsageRecord;
