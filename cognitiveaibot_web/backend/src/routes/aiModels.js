const express = require('express');
const { list, getById, getBySlug } = require('../controllers/aiModelController');

const router = express.Router();

router.get('/', list);
router.get('/by-slug/:slug', getBySlug);
router.get('/:id', getById);

module.exports = router;
