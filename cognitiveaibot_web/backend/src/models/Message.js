const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Message = sequelize.define(
  'Message',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    chat_id: {
      type: DataTypes.UUID,
      allowNull: false,
    },
    role: {
      type: DataTypes.STRING(20),
      allowNull: false,
    },
    content: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: '',
    },
    model_id: {
      type: DataTypes.UUID,
      allowNull: true,
    },
    tokens_input: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    tokens_output: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
  },
  {
    tableName: 'messages',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: false,
  }
);

Message.findByChatId = async function (chatId, userId) {
  const AIModel = require('./AIModel');
  const Chat = require('./Chat');
  const rows = await Message.findAll({
    where: { chat_id: chatId },
    include: [
      { model: Chat, attributes: [], where: { user_id: userId }, required: true },
      { model: AIModel, attributes: ['name', 'slug'], required: false },
    ],
    order: [['created_at', 'ASC']],
    raw: true,
  });
  return rows.map((r) => {
    const res = { ...r };
    res.model_name = r['AIModel.name'];
    res.model_slug = r['AIModel.slug'];
    delete res['AIModel.name'];
    delete res['AIModel.slug'];
    return res;
  });
};

const _baseCreate = Message.create.bind(Message);
Message.create = async function (chatId, data, userId) {
  const Chat = require('./Chat');
  const chat = await Chat.findOne({ where: { id: chatId, user_id: userId } });
  if (!chat) return null;
  const { role, content, model_id, tokens_input, tokens_output } = data;
  const m = await _baseCreate({
    chat_id: chatId,
    role,
    content: content || '',
    model_id: model_id || null,
    tokens_input: tokens_input || 0,
    tokens_output: tokens_output || 0,
  });
  return m.get({ plain: true });
};

Message.updateExcerptForChat = async function (chatId, userId, excerpt) {
  const Chat = require('./Chat');
  await Chat.update(chatId, userId, { excerpt: excerpt?.substring(0, 500) || null });
};

module.exports = Message;
