const User = require('./User');
const AIModel = require('./AIModel');
const Chat = require('./Chat');
const Message = require('./Message');
const { UserSettings } = require('./UserSettings');
const Subscription = require('./Subscription');
const UsageRecord = require('./UsageRecord');
const UsageLimit = require('./UsageLimit');

// Associations
User.hasMany(Chat, { foreignKey: 'user_id' });
Chat.belongsTo(User, { foreignKey: 'user_id' });
User.hasOne(UserSettings, { foreignKey: 'user_id' });
UserSettings.belongsTo(User, { foreignKey: 'user_id' });
User.hasMany(Subscription, { foreignKey: 'user_id' });
Subscription.belongsTo(User, { foreignKey: 'user_id' });
User.hasOne(UsageLimit, { foreignKey: 'user_id' });
UsageLimit.belongsTo(User, { foreignKey: 'user_id' });
User.hasMany(UsageRecord, { foreignKey: 'user_id' });
UsageRecord.belongsTo(User, { foreignKey: 'user_id' });

AIModel.hasMany(Chat, { foreignKey: 'model_id' });
Chat.belongsTo(AIModel, { foreignKey: 'model_id' });
AIModel.hasMany(Message, { foreignKey: 'model_id' });
Message.belongsTo(AIModel, { foreignKey: 'model_id' });
AIModel.hasMany(UsageRecord, { foreignKey: 'model_id' });
UsageRecord.belongsTo(AIModel, { foreignKey: 'model_id' });

Chat.hasMany(Message, { foreignKey: 'chat_id' });
Message.belongsTo(Chat, { foreignKey: 'chat_id' });

module.exports = {
  User,
  AIModel,
  Chat,
  Message,
  UserSettings,
  Subscription,
  UsageRecord,
  UsageLimit,
};
