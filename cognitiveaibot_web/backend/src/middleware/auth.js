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
      attributes: ['id', 'email', 'name', 'avatar_url', 'type', 'created_at', 'suspended_at'],
    });

    if (!user) {
      return res.status(401).json({ error: 'User not found' });
    }

    req.user = typeof user.get === 'function' ? user.get({ plain: true }) : user;
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
