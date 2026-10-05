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
const { plansRouter, billingRouter, webhookRouter, revenueCatRouter } = require('./routes/billing');
const developerRoutes = require('./routes/developer');
const reportsRoutes = require('./routes/reports');
const v1Router = require('./api/v1');

const app = express();
// Behind a load balancer or proxy, set TRUST_PROXY (e.g. 1) so per-IP limits
// see the client's address rather than the proxy's.
if (process.env.TRUST_PROXY) app.set('trust proxy', Number(process.env.TRUST_PROXY) || process.env.TRUST_PROXY);

// Middleware
app.use(cors({ origin: process.env.FRONTEND_URL || true, credentials: true }));
// Before express.json(): Stripe signs the raw request body, and the developer
// API parses its own (larger) bodies and answers errors in OpenAI's format.
app.use('/api/billing/webhook', webhookRouter);
app.use('/v1', v1Router);
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
app.use('/api/billing/revenuecat', revenueCatRouter);
app.use('/api/billing', billingRouter);
app.use('/api/developer', developerRoutes);
app.use('/api/reports', reportsRoutes);

app.get('/api', (req, res) => {
  res.json({
    name: 'CognitiveAI Bot API',
    version: '1.0.0',
    endpoints: [
      '/api/health',
      'POST /api/auth/register',
      'POST /api/auth/login',
      'POST /api/auth/forgot-password',
      'POST /api/auth/reset-password',
      'POST /api/auth/verify-email',
      'POST /api/auth/resend-verification',
      'POST /api/users/me/password',
      'GET /api/users/me/export',
      'DELETE /api/users/me',
      'POST /api/reports',
      'GET /api/admin/reports',
      'PATCH /api/admin/reports/:id',
      'GET /api/admin/alerts',
      'POST /api/admin/alerts/:id/resolve',
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
      'GET /api/billing/invoices',
      'POST /api/billing/portal',
      'POST /api/billing/webhook',
      'POST /api/billing/revenuecat',
      'GET /api/developer',
      'POST /api/developer/keys',
      'DELETE /api/developer/keys/:id',
      'GET /api/developer/usage',
      'GET /v1/models (API key)',
      'GET /v1/models/:id (API key)',
      'POST /v1/chat/completions (API key)',
      'GET /api/usage/dashboard',
      'GET /api/usage/summary',
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
      'PATCH /api/admin/models/:id',
      'POST /api/admin/users/:id/suspend',
      'POST /api/admin/users/:id/unsuspend',
      'POST /api/admin/requests/:id/refund',
      'GET /api/admin/audit',
    ],
  });
});

module.exports = { app };
