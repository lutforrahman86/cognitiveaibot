const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const chatController = require('../controllers/chatController');
const messageController = require('../controllers/messageController');
const completionController = require('../controllers/completionController');

const router = express.Router();

router.use(authMiddleware);

router.get('/search', chatController.search);
router.get('/', chatController.list);
router.post('/', chatController.create);
router.get('/:id', chatController.getById);
router.patch('/:id', chatController.update);
router.delete('/:id', chatController.remove);

router.get('/:chatId/messages', messageController.list);
router.post('/:chatId/messages', messageController.create);
router.post('/:chatId/completions', completionController.create);

module.exports = router;
