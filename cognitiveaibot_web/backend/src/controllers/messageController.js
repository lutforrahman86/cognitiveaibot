const Chat = require('../models/Chat');
const Message = require('../models/Message');

async function list(req, res) {
  try {
    const chat = await Chat.findById(req.params.chatId, req.user.id);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    const messages = await Message.findByChatId(req.params.chatId, req.user.id);
    res.json({ messages });
  } catch (err) {
    console.error('list messages:', err);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
}

/**
 * Saves a user message without asking a model. Replies only come from
 * POST /:chatId/completions, so a client can't write assistant messages or
 * token counts of its own: those feed usage metering.
 */
async function create(req, res) {
  try {
    const { role = 'user', content } = req.body;
    if (role !== 'user') {
      return res
        .status(400)
        .json({ error: 'Only user messages can be saved directly.', code: 'INVALID_ROLE' });
    }
    const message = await Message.create(req.params.chatId, { role: 'user', content }, req.user.id);
    if (!message) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    res.status(201).json({ message });
  } catch (err) {
    console.error('create message:', err);
    res.status(500).json({ error: 'Failed to create message' });
  }
}

module.exports = { list, create };
