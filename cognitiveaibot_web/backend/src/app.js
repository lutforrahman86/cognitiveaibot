const express = require('express');
const cors = require('cors');

const { passport } = require('./config/passport');
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const aiModelsRoutes = require('./routes/aiModels');
const chatsRoutes = require('./routes/chats');
const usageRoutes = require('./routes/usage');
const settingsRoutes = require('./routes/settings');
const subscriptionsRoutes = require('./routes/subscriptions');
const usageLimitsRoutes = require('./routes/usageLimits');
const adminRoutes = require('./routes/admin');
const creditsRoutes = require('./routes/credits');
const { plansRouter, billingRouter, webhookRouter } = require('./routes/billing');

const app = express();

// Middleware
app.use(cors({ origin: process.env.FRONTEND_URL || true, credentials: true }));
// Before express.json(): Stripe signs the raw request body.
app.use('/api/billing/webhook', webhookRouter);
app.use(express.json());
app.use(passport.initialize());

// Serve uploaded avatars
const path = require('path');
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// API Routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'CognitiveAI Bot API is running' });
});

app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/models', aiModelsRoutes);
app.use('/api/chats', chatsRoutes);
app.use('/api/usage', usageRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/subscriptions', subscriptionsRoutes);
app.use('/api/usage-limits', usageLimitsRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/credits', creditsRoutes);
app.use('/api/plans', plansRouter);
app.use('/api/billing', billingRouter);

app.get('/api', (req, res) => {
  res.json({
    name: 'CognitiveAI Bot API',
    version: '1.0.0',
    endpoints: [
      '/api/health',
      'POST /api/auth/register',
      'POST /api/auth/login',
      'GET /api/auth/me',
      'GET /api/users/me',
      'PATCH /api/users/me',
      'POST /api/users/me/avatar',
      'GET /api/models',
      'GET /api/models/:id',
      'GET /api/chats',
      'GET /api/chats/:id',
      'POST /api/chats',
      'PATCH /api/chats/:id',
      'DELETE /api/chats/:id',
      'GET /api/chats/:chatId/messages',
      'POST /api/chats/:chatId/messages',
      'POST /api/chats/:chatId/completions',
      'GET /api/credits',
      'GET /api/plans',
      'GET /api/billing',
      'POST /api/billing/checkout',
      'POST /api/billing/portal',
      'POST /api/billing/webhook',
      'GET /api/usage/dashboard',
      'GET /api/usage/records',
      'GET /api/settings',
      'PATCH /api/settings',
      'GET /api/subscriptions',
      'GET /api/subscriptions/pro',
      'GET /api/usage-limits',
      'PATCH /api/usage-limits',
      'GET /api/admin/check',
      'GET /api/admin/dashboard',
      'GET /api/admin/users',
      'GET /api/admin/subscriptions',
      'GET /api/admin/usage',
      'GET /api/admin/models',
      'GET /api/admin/requests',
      'POST /api/admin/users/:id/credits',
      'GET /api/admin/plans',
      'POST /api/admin/plans',
      'PATCH /api/admin/plans/:id',
    ],
  });
});

module.exports = { app };
