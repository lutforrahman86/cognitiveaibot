const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { getProfile, updateProfile } = require('../controllers/userController');
const { uploadAvatar } = require('../controllers/avatarController');
const { uploadAvatar: multerUploadAvatar } = require('../config/upload');

const router = express.Router();

router.use(authMiddleware);

router.get('/me', getProfile);
router.patch('/me', updateProfile);
router.post('/me/avatar', (req, res, next) => {
  multerUploadAvatar(req, res, (err) => {
    if (err) {
      const message = err.code === 'LIMIT_FILE_SIZE' ? 'Image must be 2MB or smaller.' : (err.message || 'Invalid file');
      return res.status(400).json({ error: message });
    }
    next();
  });
}, uploadAvatar);

module.exports = router;
