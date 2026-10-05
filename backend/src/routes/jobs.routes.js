import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import policyController from '../controllers/policy.controller.js';

import messageRepository from '../repositories/message.repository.js';

const router = express.Router();

router.use(authenticate);

// Auto-restore manual job trigger (guarded by manage_settings)
router.post(
  '/auto-restore/trigger',
  requirePermission('manage_settings'),
  policyController.triggerAutoRestoreSweep
);

// 30-day message media purge trigger (voice notes & images older than 1 month)
router.post(
  '/media-cleanup/trigger',
  requirePermission('manage_settings'),
  async (req, res, next) => {
    try {
      const purgedCount = await messageRepository.cleanupExpiredMessageMedia();
      return res.status(200).json({
        success: true,
        message: `Purged ${purgedCount} expired message media attachments (> 30 days old).`,
        data: { purgedCount },
      });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
