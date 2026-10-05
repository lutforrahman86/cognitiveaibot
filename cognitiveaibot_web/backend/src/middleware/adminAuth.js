const { authMiddleware } = require('./auth');

function adminMiddleware(req, res, next) {
  authMiddleware(req, res, (err) => {
    if (err) return next(err);
    if (req.user?.type !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }
    next();
  });
}

module.exports = { adminMiddleware };
