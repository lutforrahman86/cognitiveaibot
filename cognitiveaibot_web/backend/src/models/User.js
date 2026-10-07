const { DataTypes, Op } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define(
  'User',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
    },
    password_hash: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    avatar_url: {
      type: DataTypes.STRING(500),
      allowNull: true,
    },
    google_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
    },
    github_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
    },
    apple_id: {
      type: DataTypes.STRING(255),
      allowNull: true,
      unique: true,
    },
    type: {
      type: DataTypes.STRING(50),
      defaultValue: 'user',
    },
    suspended_at: { type: DataTypes.DATE, allowNull: true },
    email_verified_at: { type: DataTypes.DATE, allowNull: true },
    password_changed_at: { type: DataTypes.DATE, allowNull: true },
    suspended_reason: { type: DataTypes.TEXT, allowNull: true },
  },
  {
    tableName: 'users',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

const _baseFindAll = User.findAll.bind(User);
User.findById = async function (id) {
  const u = await User.findByPk(id, {
    attributes: ['id', 'email', 'name', 'avatar_url', 'google_id', 'github_id', 'apple_id', 'created_at', 'updated_at'],
  });
  return u ? u.get({ plain: true }) : null;
};

User.findByIdWithSettings = async function (id) {
  const { UserSettings } = require('./UserSettings');
  const user = await User.findById(id);
  if (!user) return null;
  const settings = await UserSettings.findByUserId(id);
  return { ...user, settings };
};

User.updateProfile = async function (id, data) {
  const { name, avatar_url } = data;
  const updateData = {};
  if (name !== undefined) updateData.name = name;
  if (avatar_url !== undefined) updateData.avatar_url = avatar_url;
  if (Object.keys(updateData).length === 0) return User.findById(id);
  const [_, [u]] = await User.update(updateData, { where: { id }, returning: true });
  return u ? u.get({ plain: true }) : null;
};

User.findAll = async function (options = {}) {
  const { limit = 100, offset = 0, plain, ...rest } = options;
  if (plain) {
    return _baseFindAll({ ...options });
  }
  const rows = await _baseFindAll({
    ...rest,
    limit,
    offset,
    attributes: rest.attributes ?? ['id', 'email', 'name', 'type', 'created_at', 'suspended_at', 'suspended_reason'],
    order: rest.order ?? [['created_at', 'DESC']],
    raw: true,
  });
  return rows;
};

User.getCount = async function () {
  return await User.count();
};

module.exports = User;
