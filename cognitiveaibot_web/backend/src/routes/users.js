const express = require('express');
const { authMiddleware } = require('../middleware/auth');
const { getProfile, updateProfile } = require('../controllers/userController');
const { uploadAvatar } = require('../controllers/avatarController');
const { uploadAvatar: multerUploadAvatar } = require('../config/upload');
const accounts = require('../auth/accounts');
const { GatewayError } = require('../gateway/errors');

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

const accountRoute = (label, fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (err) {
    if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
    console.error(`${label}:`, err);
    res.status(500).json({ error: `Couldn’t ${label}. Try again.` });
  }
};

/** POST /api/users/me/password { current_password, new_password } — signs other sessions out. */
router.post('/me/password', accountRoute('change the password', async (req, res) => {
  await accounts.changePassword(req.user.id, req.body?.current_password, req.body?.new_password);
  // This session was issued before the change too: give it a fresh token.
  const jwt = require('jsonwebtoken');
  res.json({ ok: true, token: jwt.sign({ userId: req.user.id }, process.env.JWT_SECRET, { expiresIn: '7d' }) });
}));

/** GET /api/users/me/export — everything we hold about the user, as a JSON download. */
router.get('/me/export', accountRoute('export your data', async (req, res) => {
  const data = await accounts.exportData(req.user.id);
  const date = new Date().toISOString().slice(0, 10);
  res.set('Content-Disposition', `attachment; filename="cognitiveaibot-export-${date}.json"`);
  res.json(data);
}));

/** DELETE /api/users/me { confirm } — deletes the account; `confirm` is the password (or email for OAuth-only accounts). */
router.delete('/me', accountRoute('delete the account', async (req, res) => {
  await accounts.deleteAccount(req.user.id, req.body?.confirm);
  res.json({ deleted: true });
}));

module.exports = router;
