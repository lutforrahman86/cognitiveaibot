const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authMiddleware } = require('../middleware/auth');
const { passport, frontendUrl } = require('../config/passport');
const accounts = require('../auth/accounts');
const { allowAction } = require('../gateway/rateLimit');
const { GatewayError } = require('../gateway/errors');

// Abuse limits per IP address (roadmap E4), per hour.
const signupsPerIp = () => Number(process.env.SIGNUPS_PER_IP_PER_HOUR) || 5;
const resetsPerIp = () => Number(process.env.RESETS_PER_IP_PER_HOUR) || 10;

function sendAccountError(res, err, label) {
  if (err instanceof GatewayError) return res.status(err.status).json({ error: err.message, code: err.code });
  console.error(`${label}:`, err);
  return res.status(500).json({ error: `Couldn’t ${label}. Try again.` });
}

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
  return typeof password === 'string' && password.length >= accounts.MIN_PASSWORD && password.length <= 200;
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
        error: `Password must be at least ${accounts.MIN_PASSWORD} characters`,
        code: 'WEAK_PASSWORD',
      });
    }

    if (!(await allowAction(`signup:${req.ip}`, signupsPerIp(), 3600))) {
      return res.status(429).json({ error: 'Too many sign-ups from this network. Try again later.', code: 'TOO_MANY_SIGNUPS' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await User.create({
      email: email.trim().toLowerCase(),
      password_hash: passwordHash,
      name: name?.trim() || null,
    });
    const token = createToken(user);
    // Trial credits arrive once the emailed link is followed.
    accounts.sendVerification(user.id).catch((err) => console.error('verification email:', err.message));

    res.status(201).json({
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        type: user.type || 'user',
        createdAt: user.created_at,
        email_verified: false,
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
        email_verified: Boolean(user.email_verified_at),
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
      email_verified: Boolean(req.user.email_verified_at),
    },
  });
});

/** POST /api/auth/forgot-password { email } — emails a reset link if the account exists (always 200). */
router.post('/forgot-password', async (req, res) => {
  try {
    if (await allowAction(`reset:${req.ip}`, resetsPerIp(), 3600)) {
      await accounts.requestPasswordReset(req.body?.email);
    }
    res.json({ ok: true, message: 'If an account uses that email, a reset link is on its way.' });
  } catch (err) {
    sendAccountError(res, err, 'send the reset email');
  }
});

/** POST /api/auth/reset-password { token, password } */
router.post('/reset-password', async (req, res) => {
  try {
    await accounts.resetPassword(req.body?.token, req.body?.password);
    res.json({ ok: true });
  } catch (err) {
    sendAccountError(res, err, 'reset the password');
  }
});

/** POST /api/auth/verify-email { token } */
router.post('/verify-email', async (req, res) => {
  try {
    await accounts.verifyEmail(req.body?.token);
    res.json({ ok: true });
  } catch (err) {
    sendAccountError(res, err, 'confirm the email');
  }
});

/** POST /api/auth/resend-verification — a new confirmation link for the signed-in user. */
router.post('/resend-verification', authMiddleware, async (req, res) => {
  try {
    if (!(await allowAction(`verify:${req.user.id}`, 5, 3600))) {
      return res.status(429).json({ error: 'Too many emails. Try again in an hour.', code: 'TOO_MANY_EMAILS' });
    }
    const sent = await accounts.sendVerification(req.user.id);
    res.json({ ok: true, already_verified: !sent });
  } catch (err) {
    sendAccountError(res, err, 'send the confirmation email');
  }
});

module.exports = router;
