import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import pkController from '../controllers/pk.controller.js';

export const userPKRouter = express.Router();
userPKRouter.use(authenticate);

// ── CANONICAL PK 2.0 REST ROUTES ──────────────────────────────
userPKRouter.get('/discover', pkController.discoverOpponent);
userPKRouter.post('/invitations', pkController.sendInvitation);
userPKRouter.post('/invitations/:id/respond', pkController.respondInvitation);
userPKRouter.post('/invitations/:id/cancel', pkController.cancelInvitation);
userPKRouter.post('/matches/:id/ready', pkController.setOperatorReady);
userPKRouter.get('/matches/:id', pkController.getMatchSnapshot);
userPKRouter.get('/rooms/:roomId/active', pkController.getActiveMatchForRoom);
userPKRouter.get('/matches/:id/supporters', pkController.getTopSupporters);
userPKRouter.post('/matches/:id/rematch', pkController.requestRematch);
userPKRouter.get('/history', pkController.getHistory);

// ── LEGACY BACKWARD-COMPATIBLE ROUTES ─────────────────────────
userPKRouter.post('/create', pkController.createPKSession);
userPKRouter.post('/invite', pkController.sendPKInvite);
userPKRouter.get('/invite/:id', pkController.getInvitationDetails);
userPKRouter.post('/invite/:id/respond', pkController.respondPKInvite);
userPKRouter.post('/join-by-code', pkController.joinByInviteCode);
userPKRouter.get('/available-hosts', pkController.getAvailablePKHosts);
userPKRouter.post('/:id/start', pkController.startPKBattle);
userPKRouter.get('/:id', pkController.getPKSession);
userPKRouter.get('/room/:roomId', pkController.getRoomPKStatus);
userPKRouter.post('/:id/end', pkController.endPKBattle);

// ── ADMIN MANAGEMENT ROUTES ───────────────────────────────────
export const adminPKRouter = express.Router();
adminPKRouter.use(authenticate);

// Matches & Live Monitor
adminPKRouter.get('/matches', requirePermission('view_pk_events'), pkController.listAdminMatches);
adminPKRouter.post('/matches/:id/force-stop', requirePermission('manage_pk_events'), pkController.adminForceStop);
adminPKRouter.post('/matches/:id/revise-result', requirePermission('manage_pk_events'), pkController.adminReviseResult);

// Settings
adminPKRouter.get('/settings', requirePermission('view_pk_events'), pkController.getSettings);
adminPKRouter.put('/settings', requirePermission('manage_pk_events'), pkController.updateSettings);

// Restrictions
adminPKRouter.get('/restrictions', requirePermission('view_pk_events'), pkController.listRestrictions);
adminPKRouter.post('/restrictions', requirePermission('manage_pk_events'), pkController.createRestriction);
adminPKRouter.delete('/restrictions/:id', requirePermission('manage_pk_events'), pkController.revokeRestriction);

// Legacy Root routes (for backwards compatibility with existing admin API callers)
adminPKRouter.get('/', requirePermission('view_pk_events'), pkController.listAdminMatches);
adminPKRouter.post('/:id/end', requirePermission('manage_pk_events'), pkController.adminForceStop);
adminPKRouter.post('/:id/force-stop', requirePermission('manage_pk_events'), pkController.adminForceStop);

export default {
  userPKRouter,
  adminPKRouter,
};
