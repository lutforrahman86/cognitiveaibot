const { UserSettings } = require('../../models/UserSettings');

async function seed(userId) {
  await UserSettings.upsert(userId, {
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
  });
  console.log('Seeded user settings');
}

module.exports = { seed };
