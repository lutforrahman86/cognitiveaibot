const { DataTypes, Op } = require('sequelize');
const { sequelize } = require('../config/database');

const Chat = sequelize.define(
  'Chat',
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
    title: {
      type: DataTypes.STRING(255),
      defaultValue: 'New chat',
    },
    excerpt: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    model_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    category: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
  },
  {
    tableName: 'chats',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

Chat.findByUserId = async function (userId, options = {}) {
  const { limit = 50, offset = 0, search, category } = options;
  const AIModel = require('./AIModel');
  const where = { user_id: userId };
  if (search) {
    where[Op.or] = [
      { title: { [Op.iLike]: `%${search}%` } },
      { excerpt: { [Op.iLike]: `%${search}%` } },
      { category: { [Op.iLike]: `%${search}%` } },
    ];
  }
  if (category) where.category = category;
  const rows = await Chat.findAll({
    where,
    include: [{ model: AIModel, attributes: ['name', 'provider'], required: false }],
    order: [['updated_at', 'DESC']],
    limit,
    offset,
    raw: true,
    nest: true,
  });
  return rows.map((r) => {
    const aim = r.AIModel || r.ai_model;
    return {
      ...r,
      model_name: aim?.name,
      model_provider: aim?.provider,
      AIModel: undefined,
      ai_model: undefined,
    };
  });
};

Chat.findById = async function (id, userId) {
  const AIModel = require('./AIModel');
  const c = await Chat.findOne({
    where: { id, user_id: userId },
    include: [{ model: AIModel, attributes: ['name', 'slug', 'provider'], required: false }],
  });
  if (!c) return null;
  const plain = c.get({ plain: true });
  const aim = plain.AIModel || plain.ai_model;
  return {
    ...plain,
    model_name: aim?.name,
    model_slug: aim?.slug,
    model_provider: aim?.provider,
    AIModel: undefined,
    ai_model: undefined,
  };
};

const _baseCreate = Chat.create.bind(Chat);
Chat.create = async function (userId, data = {}) {
  const { title = 'New chat', excerpt, model_id, category } = data;
  const c = await _baseCreate({
    user_id: userId,
    title,
    excerpt: excerpt || null,
    model_id: model_id || null,
    category: category || null,
  });
  return c.get({ plain: true });
};

// Kept before the override below: calling Chat.update from inside it would
// recurse into the override instead of reaching Sequelize.
const _baseUpdate = Chat.update.bind(Chat);
Chat.update = async function (id, userId, data) {
  const { title, excerpt, model_id, category } = data;
  const updateData = {};
  if (title !== undefined) updateData.title = title;
  if (excerpt !== undefined) updateData.excerpt = excerpt;
  if (model_id !== undefined) updateData.model_id = model_id;
  if (category !== undefined) updateData.category = category;
  if (Object.keys(updateData).length === 0) return Chat.findById(id, userId);
  const [count] = await _baseUpdate(updateData, { where: { id, user_id: userId } });
  if (count === 0) return null;
  return Chat.findById(id, userId);
};

Chat.deleteById = async function (id, userId) {
  const deleted = await Chat.destroy({ where: { id, user_id: userId } });
  return deleted ? { id } : null;
};

Chat.search = async function (userId, q) {
  const { sequelize: db } = require('../config/database');
  const { QueryTypes } = require('sequelize');
  const rows = await db.query(
    `SELECT c.*, m.name as model_name
     FROM chats c
     LEFT JOIN ai_models m ON c.model_id = m.id
     WHERE c.user_id = :userId AND (
       to_tsvector('english', coalesce(c.title,'') || ' ' || coalesce(c.excerpt,'') || ' ' || coalesce(c.category,'') || ' ' || coalesce(m.name,'')) @@ plainto_tsquery('english', :q)
     )
     ORDER BY c.updated_at DESC`,
    { replacements: { userId, q }, type: QueryTypes.SELECT }
  );
  return Array.isArray(rows) ? rows : [];
};

module.exports = Chat;
