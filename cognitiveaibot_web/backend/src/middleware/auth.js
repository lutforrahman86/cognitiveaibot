const jwt = require('jsonwebtoken');
const User = require('../models/User');

/**
 * Protect routes - requires valid JWT in Authorization header
 */
async function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    const user = await User.findByPk(decoded.userId, {
      attributes: ['id', 'email', 'name', 'avatar_url', 'type', 'created_at', 'suspended_at', 'email_verified_at', 'password_changed_at'],
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = typeof user.get === 'function' ? user.get({ plain: true }) : user;
    // A password change signs out every session issued before it.
    const changed = req.user.password_changed_at && Math.floor(new Date(req.user.password_changed_at).getTime() / 1000);
    if (changed && decoded.iat < changed) {
      return res.status(401).json({ error: 'Your password was changed. Sign in again.', code: 'SESSION_EXPIRED' });
    }
    // A suspended account keeps its data but can't use the service.
    if (req.user.suspended_at) {
      return res.status(403).json({ error: 'This account is suspended. Contact support.', code: 'ACCOUNT_SUSPENDED' });
    }
    next();
  } catch (err) {
    if (err.name === 'JsonWebTokenError' || err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Invalid or expired token' });
    }
    next(err);
  }
}

module.exports = { authMiddleware };
