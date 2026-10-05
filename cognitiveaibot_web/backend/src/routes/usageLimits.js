const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { get, update } = require('../controllers/usageLimitController');

const router = express.Router();

router.use(authMiddleware);

router.get('/', get);
router.patch('/', update);

module.exports = router;
