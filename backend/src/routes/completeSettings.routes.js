import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import completeSettingsController from '../controllers/completeSettings.controller.js';

const router = express.Router();

// Public / Authenticated Preview endpoint (Host Calculator preview)
router.post('/preview/host-earnings', completeSettingsController.calculateHostEarningsPreview);

// Admin-protected Policy & Settings endpoints
router.get(
  '/',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.getAllCompleteSettings
);

router.get(
  '/history',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.getPolicyVersionHistory
);

router.get(
  '/category/:category',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.getSettingsByCategory
);

router.put(
  '/single/:key',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.updateSingleSetting
);

router.post(
  '/batch',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.batchUpdateSettings
);

router.post(
  '/publish',
  authenticate,
  requirePermission('manage_system_settings'),
  completeSettingsController.publishNewPolicyVersion
);

export default router;
