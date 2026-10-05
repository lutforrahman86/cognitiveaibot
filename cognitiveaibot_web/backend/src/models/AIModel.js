const { DataTypes, Op } = require('sequelize');
const { sequelize } = require('../config/database');

const AIModel = sequelize.define(
  'AIModel',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    provider: {
      type: DataTypes.STRING(50),
      allowNull: false,
    },
    name: {
      type: DataTypes.STRING(100),
      allowNull: false,
    },
    slug: {
      type: DataTypes.STRING(100),
      allowNull: false,
      unique: true,
    },
    category: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
    // The id the provider's own API expects (direct route). Null: no direct route.
    provider_model_id: {
      type: DataTypes.STRING(150),
      allowNull: true,
    },
    context_window: { type: DataTypes.INTEGER, allowNull: true },
    max_output_tokens: { type: DataTypes.INTEGER, allowNull: true },
    // What the provider charges us, USD per 1M tokens.
    input_cost_per_mtok: { type: DataTypes.DECIMAL(14, 4), allowNull: true },
    output_cost_per_mtok: { type: DataTypes.DECIMAL(14, 4), allowNull: true },
    // What we charge the user, credits per 1M tokens. A model without these
    // can't be called: it would be free.
    input_credits_per_mtok: { type: DataTypes.DECIMAL(14, 4), allowNull: true },
    output_credits_per_mtok: { type: DataTypes.DECIMAL(14, 4), allowNull: true },
    // The endpoint the model serves: chat, embedding, image, speech,
    // transcription or video. Chat pickers list only 'chat' models.
    api_kind: { type: DataTypes.STRING(20), defaultValue: 'chat' },
    // What it's billed by. 'token' and 'character' use the per-1M prices
    // above; 'second' uses unit_cost_usd / unit_credits per second.
    pricing_unit: { type: DataTypes.STRING(12), defaultValue: 'token' },
    unit_cost_usd: { type: DataTypes.DECIMAL(14, 6), allowNull: true },
    unit_credits: { type: DataTypes.DECIMAL(14, 6), allowNull: true },
    // What the model takes and produces ('text', 'image', 'audio', 'video',
    // 'embedding'), and what it can do.
    input_modalities: { type: DataTypes.ARRAY(DataTypes.TEXT), defaultValue: ['text'] },
    output_modalities: { type: DataTypes.ARRAY(DataTypes.TEXT), defaultValue: ['text'] },
    supports_streaming: { type: DataTypes.BOOLEAN, defaultValue: true },
    supports_vision: { type: DataTypes.BOOLEAN, defaultValue: false },
    supports_tools: { type: DataTypes.BOOLEAN, defaultValue: false },
    supports_json: { type: DataTypes.BOOLEAN, defaultValue: false },
    // Lifecycle label shown to users: beta, active or deprecated.
    status: { type: DataTypes.STRING(12), defaultValue: 'active' },
    // Access tier: callable by accounts whose plan unlocks at least this tier.
    // 0 = everyone, including accounts with no plan.
    tier: { type: DataTypes.SMALLINT, defaultValue: 0 },
    display_order: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
  },
  {
    tableName: 'ai_models',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

const _baseFindAll = AIModel.findAll.bind(AIModel);
AIModel.findAll = async function (filters = {}) {
  // Sequelize's own findOne/findByPk call findAll with `plain: true`; those
  // must reach Sequelize, not this filter (as in User.findAll).
  if (filters.plain) return _baseFindAll(filters);
  const { category, provider, search, includeInactive, apiKind } = filters;
  const where = {};
  if (!includeInactive) where.is_active = true;
  if (apiKind) where.api_kind = apiKind;
  if (category) where.category = category;
  if (provider) where.provider = provider;
  if (search) {
    where[Op.or] = [
      { name: { [Op.iLike]: `%${search}%` } },
      { provider: { [Op.iLike]: `%${search}%` } },
    ];
  }
  const rows = await _baseFindAll({
    where,
    order: [
      // Retired models keep their old position numbers; list them last.
      ['is_active', 'DESC'],
      ['display_order', 'ASC'],
      ['name', 'ASC'],
    ],
    raw: true,
  });
  return rows;
};

AIModel.findById = async function (id) {
  const m = await AIModel.findByPk(id);
  return m ? m.get({ plain: true }) : null;
};

AIModel.findBySlug = async function (slug) {
  const row = await AIModel.findOne({ where: { slug } });
  return row && typeof row.get === 'function' ? row.get({ plain: true }) : row || null;
};

const _baseCreate = AIModel.create.bind(AIModel);
AIModel.create = async function (data) {
  const { provider, name, slug, category, provider_model_id, display_order } = data;
  const m = await _baseCreate({
    provider,
    name,
    slug: slug || name.toLowerCase().replace(/\s+/g, '-'),
    category,
    provider_model_id: provider_model_id ?? null,
    display_order: display_order ?? 0,
  });
  return m.get({ plain: true });
};

module.exports = AIModel;
