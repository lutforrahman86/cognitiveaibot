const Chat = require('../models/Chat');
const Message = require('../models/Message');

async function list(req, res) {
  try {
    const { limit, offset, search, category } = req.query;
    const chats = await Chat.findByUserId(req.user.id, {
      limit: limit ? parseInt(limit, 10) : 50,
      offset: offset ? parseInt(offset, 10) : 0,
      search,
      category,
    });
    res.json({ chats });
  } catch (err) {
    console.error('list chats:', err);
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
}

async function search(req, res) {
  try {
    const { q } = req.query;
    if (!q || q.trim().length === 0) {
      return res.json({ chats: [] });
    }
    const chats = await Chat.search(req.user.id, q.trim());
    res.json({ chats });
  } catch (err) {
    console.error('search chats:', err);
    res.status(500).json({ error: 'Failed to search chats' });
  }
}

async function getById(req, res) {
  try {
    const chat = await Chat.findById(req.params.id, req.user.id);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    const messages = await Message.findByChatId(req.params.id, req.user.id);
    res.json({ chat: { ...chat, messages } });
  } catch (err) {
    console.error('getById:', err);
    res.status(500).json({ error: 'Failed to fetch chat' });
  }
}

async function create(req, res) {
  try {
    const { title, excerpt, model_id, category } = req.body;
    const chat = await Chat.create(req.user.id, {
      title: title || 'New chat',
      excerpt,
      model_id,
      category,
    });
    res.status(201).json({ chat });
  } catch (err) {
    console.error('create chat:', err);
    res.status(500).json({ error: 'Failed to create chat' });
  }
}

async function update(req, res) {
  try {
    const { title, excerpt, model_id, category } = req.body;
    const chat = await Chat.update(req.params.id, req.user.id, {
      title,
      excerpt,
      model_id,
      category,
    });
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    res.json({ chat });
  } catch (err) {
    console.error('update chat:', err);
    res.status(500).json({ error: 'Failed to update chat' });
  }
}

async function remove(req, res) {
  try {
    const deleted = await Chat.deleteById(req.params.id, req.user.id);
    if (!deleted) {
      return res.status(404).json({ error: 'Chat not found' });
    }
    res.status(204).send();
  } catch (err) {
    console.error('delete chat:', err);
    res.status(500).json({ error: 'Failed to delete chat' });
  }
}

module.exports = { list, search, getById, create, update, remove };
