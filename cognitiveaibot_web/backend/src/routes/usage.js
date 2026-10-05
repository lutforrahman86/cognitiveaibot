const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { getDashboard, getRecords } = require('../controllers/usageController');

const router = express.Router();

router.use(authMiddleware);

router.get('/dashboard', getDashboard);
router.get('/records', getRecords);

module.exports = router;
