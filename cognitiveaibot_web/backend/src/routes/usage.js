const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { getDashboard, getRecords, getSummary } = require('../controllers/usageController');

const router = express.Router();

router.use(authMiddleware);

router.get('/dashboard', getDashboard);
router.get('/records', getRecords);
router.get('/summary', getSummary);

module.exports = router;
