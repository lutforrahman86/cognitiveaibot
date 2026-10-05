const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { get, checkPro } = require('../controllers/subscriptionController');

const router = express.Router();

router.use(authMiddleware);

router.get('/', get);
router.get('/pro', checkPro);

module.exports = router;
