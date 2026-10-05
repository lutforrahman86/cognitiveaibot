const User = require('../models/User');

async function uploadAvatar(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    const avatarUrl = `/uploads/avatars/${req.file.filename}`;
    const user = await User.updateProfile(req.user.id, { avatar_url: avatarUrl });

    res.json({ user, avatar_url: avatarUrl });
  } catch (err) {
    console.error('uploadAvatar:', err);
    res.status(500).json({ error: 'Failed to upload avatar' });
  }
}

module.exports = { uploadAvatar };
