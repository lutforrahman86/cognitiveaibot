const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const UserSettings = sequelize.define(
  'UserSettings',
  {
    user_id: {
      type: DataTypes.UUID,
      primaryKey: true,
    },
    theme: {
      type: DataTypes.STRING(20),
      defaultValue: 'dark',
    },
    font_size: {
      type: DataTypes.STRING(20),
      defaultValue: 'medium',
    },
    enter_to_send: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    show_timestamps: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    read_aloud: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    ai_voice_model: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    system_prompt: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    temperature: {
      type: DataTypes.DECIMAL(3, 2),
      defaultValue: 0.7,
    },
    token_threshold_80: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    token_threshold_90: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
    token_threshold_100: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
    },
  },
  {
    tableName: 'user_settings',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at',
  }
);

const DEFAULTS = {
  theme: 'dark',
  font_size: 'medium',
  enter_to_send: true,
  show_timestamps: true,
  read_aloud: false,
  ai_voice_model: null,
  system_prompt: null,
  temperature: 0.7,
  token_threshold_80: true,
  token_threshold_90: true,
  token_threshold_100: true,
};

UserSettings.findByUserId = async function (userId) {
  const s = await UserSettings.findByPk(userId);
  return s ? s.get({ plain: true }) : { ...DEFAULTS, user_id: userId };
};

const _baseUpsert = UserSettings.upsert.bind(UserSettings);
UserSettings.upsert = async function (userId, data) {
  const {
    theme,
    font_size,
    enter_to_send,
    show_timestamps,
    read_aloud,
    ai_voice_model,
    system_prompt,
    temperature,
    token_threshold_80,
    token_threshold_90,
    token_threshold_100,
  } = data;
  const [s] = await _baseUpsert({
    user_id: userId,
    theme: theme ?? DEFAULTS.theme,
    font_size: font_size ?? DEFAULTS.font_size,
    enter_to_send: enter_to_send ?? DEFAULTS.enter_to_send,
    show_timestamps: show_timestamps ?? DEFAULTS.show_timestamps,
    read_aloud: read_aloud ?? DEFAULTS.read_aloud,
    ai_voice_model: ai_voice_model ?? DEFAULTS.ai_voice_model,
    system_prompt: system_prompt ?? DEFAULTS.system_prompt,
    temperature: temperature ?? DEFAULTS.temperature,
    token_threshold_80: token_threshold_80 ?? DEFAULTS.token_threshold_80,
    token_threshold_90: token_threshold_90 ?? DEFAULTS.token_threshold_90,
    token_threshold_100: token_threshold_100 ?? DEFAULTS.token_threshold_100,
  });
  return s.get({ plain: true });
};

module.exports = { UserSettings, DEFAULTS };
