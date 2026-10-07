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
    // Null: the model's own default (never sent to the provider).
    temperature: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: true,
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
  temperature: null,
  token_threshold_80: true,
  token_threshold_90: true,
  token_threshold_100: true,
};

UserSettings.findByUserId = async function (userId) {
  const s = await UserSettings.findByPk(userId);
  return s ? s.get({ plain: true }) : { ...DEFAULTS, user_id: userId };
};

const FONT_SIZES = ['small', 'medium', 'large'];
const THEMES = ['dark', 'light', 'system'];
const MAX_SYSTEM_PROMPT = 4000;

class SettingsError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SettingsError';
    this.status = 400;
  }
}

/** Checks one field; returns the value to store or throws SettingsError. */
function validate(key, value) {
  const bool = () => {
    if (typeof value !== 'boolean') throw new SettingsError(`${key} must be true or false.`);
    return value;
  };
  switch (key) {
    case 'theme':
      if (!THEMES.includes(value)) throw new SettingsError(`theme must be one of: ${THEMES.join(', ')}.`);
      return value;
    case 'font_size':
      if (!FONT_SIZES.includes(value)) throw new SettingsError(`font_size must be one of: ${FONT_SIZES.join(', ')}.`);
      return value;
    case 'system_prompt': {
      if (value === null || value === '') return null;
      if (typeof value !== 'string') throw new SettingsError('system_prompt must be text.');
      if (value.length > MAX_SYSTEM_PROMPT) throw new SettingsError(`Custom instructions are limited to ${MAX_SYSTEM_PROMPT} characters.`);
      return value.trim() || null;
    }
    case 'temperature': {
      if (value === null || value === '') return null;
      const n = Number(value);
      if (!Number.isFinite(n) || n < 0 || n > 2) throw new SettingsError('temperature must be from 0 to 2, or empty for the model’s default.');
      return Math.round(n * 100) / 100;
    }
    case 'ai_voice_model':
      return value === null || value === '' ? null : String(value).slice(0, 100);
    default:
      return bool();
  }
}

/**
 * Changes only the settings given; the rest keep their saved values.
 * Unknown keys are ignored; an invalid value throws SettingsError (400).
 */
UserSettings.upsert = async function (userId, data = {}) {
  const current = await UserSettings.findByUserId(userId);
  const next = { ...DEFAULTS, ...current, user_id: userId };
  for (const key of Object.keys(DEFAULTS)) {
    if (key in data) next[key] = validate(key, data[key]);
  }
  const [row] = await UserSettings.findOrCreate({ where: { user_id: userId }, defaults: next });
  await row.update(next);
  return row.get({ plain: true });
};

module.exports = { UserSettings, DEFAULTS, SettingsError };
