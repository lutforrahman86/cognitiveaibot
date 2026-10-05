const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');
const { passport, frontendUrl } = require('../config/passport');

const router = express.Router();

function createToken(user) {
  return jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '7d' });
}

function redirectWithToken(res, token, error = false) {
  const params = new URLSearchParams();
  if (token) params.set('token', token);
  if (error) params.set('error', error);
  res.redirect(`${frontendUrl}/auth/callback?${params.toString()}`);
}

/** GET /api/auth/google - Start Google OAuth */
router.get('/google', (req, res, next) => {
  if (!process.env.GOOGLE_CLIENT_ID || !process.env.GOOGLE_CLIENT_SECRET) {
    return res.status(503).json({ error: 'Google sign-in is not configured' });
  }
  passport.authenticate('google', { session: false })(req, res, next);
});

/** GET /api/auth/google/callback - Google OAuth callback */
router.get('/google/callback', (req, res, next) => {
  passport.authenticate('google', { session: false }, (err, user) => {
    if (err) {
      console.error('Google OAuth error:', err);
      return redirectWithToken(res, null, 'Google sign-in failed');
    }
    if (!user) return redirectWithToken(res, null, 'Authentication failed');
    const token = createToken(user);
    redirectWithToken(res, token);
  })(req, res, next);
});

/** GET /api/auth/github - Start GitHub OAuth */
router.get('/github', (req, res, next) => {
  if (!process.env.GITHUB_CLIENT_ID || !process.env.GITHUB_CLIENT_SECRET) {
    return res.status(503).json({ error: 'GitHub sign-in is not configured' });
  }
  passport.authenticate('github', { session: false })(req, res, next);
});

/** GET /api/auth/github/callback - GitHub OAuth callback */
router.get('/github/callback', (req, res, next) => {
  passport.authenticate('github', { session: false }, (err, user) => {
    if (err) {
      console.error('GitHub OAuth error:', err);
      return redirectWithToken(res, null, 'GitHub sign-in failed');
    }
    if (!user) return redirectWithToken(res, null, 'Authentication failed');
    const token = createToken(user);
    redirectWithToken(res, token);
  })(req, res, next);
});

// Validation helpers
function validateEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function validatePassword(password) {
  return password && password.length >= 6;
}

/**
 * POST /api/auth/register
 * Register a new user
 */
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    if (!validateEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    if (!validatePassword(password)) {
      return res.status(400).json({
        error: 'Password must be at least 6 characters',
      });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await User.create({
      email: email.trim().toLowerCase(),
      password_hash: passwordHash,
      name: name?.trim() || null,
    });
    const token = jwt.sign(
      { userId: user.id },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        type: user.type || 'user',
        createdAt: user.created_at,
      },
      token,
    });
  } catch (err) {
    if (err.name === 'SequelizeUniqueConstraintError' || err.code === '23505') {
      return res.status(409).json({ error: 'Email already registered' });
    }
    console.error('Register error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

/**
 * POST /api/auth/login
 * Login with email and password (Passport Local strategy)
 */
router.post('/login', (req, res, next) => {
  passport.authenticate('local', { session: false }, (err, user, info) => {
    if (err) {
      console.error('Login error:', err);
      return res.status(500).json({ error: 'Login failed' });
    }
    if (!user) {
      return res.status(401).json({ error: info?.message || 'Invalid email or password' });
    }
    const token = createToken(user);
    res.json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        type: user.type || 'user',
        createdAt: user.created_at,
      },
      token,
    });
  })(req, res, next);
});

/**
 * GET /api/auth/me
 * Get current user (protected)
 */
router.get('/me', authMiddleware, (req, res) => {
  res.json({
    user: {
      id: req.user.id,
      email: req.user.email,
      name: req.user.name,
      avatar_url: req.user.avatar_url,
      type: req.user.type || 'user',
      createdAt: req.user.created_at,
    },
  });
});

module.exports = router;
