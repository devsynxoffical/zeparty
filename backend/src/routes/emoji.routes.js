import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import appEmojiController from '../controllers/appEmoji.controller.js';

export const adminEmojiRouter = express.Router();
adminEmojiRouter.use(authenticate);

// Admin App Emoji / Reaction Management
adminEmojiRouter.get('/', requirePermission('view_gifts'), appEmojiController.getAdminEmojis);
adminEmojiRouter.post('/', requirePermission('manage_gifts'), appEmojiController.postAdminEmoji);
adminEmojiRouter.post('/master-switch', requirePermission('manage_gifts'), appEmojiController.postAdminMasterSwitchEmojis);
adminEmojiRouter.post('/reorder', requirePermission('manage_gifts'), appEmojiController.postAdminReorderEmojis);
adminEmojiRouter.get('/analytics', requirePermission('view_gifts'), appEmojiController.getAdminEmojisAnalytics);
adminEmojiRouter.put('/:id', requirePermission('manage_gifts'), appEmojiController.putAdminEmoji);
adminEmojiRouter.post('/:id/toggle', requirePermission('manage_gifts'), appEmojiController.postAdminToggleEmoji);
adminEmojiRouter.post('/:id/emergency-disable', requirePermission('manage_gifts'), appEmojiController.postAdminEmergencyDisableEmoji);
adminEmojiRouter.delete('/:id', requirePermission('manage_gifts'), appEmojiController.deleteAdminEmoji);

export const userEmojiRouter = express.Router();
userEmojiRouter.get('/tray', appEmojiController.getUserEmojiTray);
userEmojiRouter.post('/send', authenticate, appEmojiController.postUserSendAppEmoji);

export default {
  adminEmojiRouter,
  userEmojiRouter,
};
