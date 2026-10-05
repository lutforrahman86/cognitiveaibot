const express = require('express');
const { adminMiddleware } = require('../middleware/adminAuth');
const {
  checkAdmin,
  getDashboard,
  getUsers,
  getSubscriptions,
  getUsage,
  getModels,
  getRequests,
  adjustCredits,
  checkModelUpdates,
  getPlans,
  createPlan,
  updatePlan,
  updateModel,
  suspendUser,
  unsuspendUser,
  refundRequest,
  getAuditLog,
  getReports,
  updateReport,
  getAlerts,
  resolveAlert,
} = require('../controllers/adminController');

const router = express.Router();

router.use(adminMiddleware);

router.get('/check', checkAdmin);
router.get('/dashboard', getDashboard);
router.get('/users', getUsers);
router.get('/subscriptions', getSubscriptions);
router.get('/usage', getUsage);
router.get('/models/check-updates', checkModelUpdates);
router.get('/models', getModels);
router.get('/requests', getRequests);
router.post('/users/:id/credits', adjustCredits);
router.get('/plans', getPlans);
router.post('/plans', createPlan);
router.patch('/plans/:id', updatePlan);
router.patch('/models/:id', updateModel);
router.post('/users/:id/suspend', suspendUser);
router.post('/users/:id/unsuspend', unsuspendUser);
router.post('/requests/:id/refund', refundRequest);
router.get('/audit', getAuditLog);
router.get('/reports', getReports);
router.patch('/reports/:id', updateReport);
router.get('/alerts', getAlerts);
router.post('/alerts/:id/resolve', resolveAlert);

module.exports = router;
