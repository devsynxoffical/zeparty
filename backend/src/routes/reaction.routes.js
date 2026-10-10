import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import bdReactionController from '../controllers/bdReaction.controller.js';

export const adminBDReactionRouter = express.Router();
adminBDReactionRouter.use(authenticate);

// Admin BD Reaction Management
adminBDReactionRouter.get('/', requirePermission('manage_bd_centers'), bdReactionController.getAdminBDReactions);
adminBDReactionRouter.post('/', requirePermission('manage_bd_centers'), bdReactionController.postAdminBDReaction);
adminBDReactionRouter.post('/master-switch', requirePermission('manage_bd_centers'), bdReactionController.postAdminMasterSwitchBDReactions);
adminBDReactionRouter.get('/analytics', requirePermission('manage_bd_centers'), bdReactionController.getAdminBDReactionsAnalytics);
adminBDReactionRouter.put('/:id', requirePermission('manage_bd_centers'), bdReactionController.putAdminBDReaction);
adminBDReactionRouter.post('/:id/toggle', requirePermission('manage_bd_centers'), bdReactionController.postAdminToggleBDReaction);
adminBDReactionRouter.post('/:id/emergency-disable', requirePermission('manage_bd_centers'), bdReactionController.postAdminEmergencyDisableBDReaction);
adminBDReactionRouter.delete('/:id', requirePermission('manage_bd_centers'), bdReactionController.deleteAdminBDReaction);

export const userBDReactionRouter = express.Router();
userBDReactionRouter.get('/', authenticate, bdReactionController.getUserBDReactions);
userBDReactionRouter.post('/send', authenticate, bdReactionController.postUserSendBDReaction);

export default {
  adminBDReactionRouter,
  userBDReactionRouter,
};
