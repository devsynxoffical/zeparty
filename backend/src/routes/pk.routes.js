import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import pkController from '../controllers/pk.controller.js';

export const userPKRouter = express.Router();
userPKRouter.use(authenticate);

// ── PK Battle Creation & Invitations (Host-Controlled) ────────
userPKRouter.post('/create', pkController.createPKSession);
userPKRouter.post('/invite', pkController.sendPKInvite);
userPKRouter.get('/invite/:id', pkController.getInvitationDetails);
userPKRouter.post('/invite/:id/respond', pkController.respondPKInvite);
userPKRouter.post('/join-by-code', pkController.joinByInviteCode);
userPKRouter.get('/available-hosts', pkController.getAvailablePKHosts);

// ── PK Battle Lifecycle (Start with Authoritative Timer, Status, End) ──
userPKRouter.post('/:id/start', pkController.startPKBattle);
userPKRouter.get('/:id', pkController.getPKSession);
userPKRouter.get('/room/:roomId', pkController.getRoomPKStatus);
userPKRouter.post('/:id/end', pkController.endPKBattle);

// ── Admin PK Management ───────────────────────────────────────
export const adminPKRouter = express.Router();
adminPKRouter.use(authenticate);

adminPKRouter.get('/', requirePermission('view_pk_events'), pkController.listAdminPKEvents);
adminPKRouter.post('/create', requirePermission('manage_pk_events'), pkController.createPKSession);
adminPKRouter.post('/:id/start', requirePermission('manage_pk_events'), pkController.startPKBattle);
adminPKRouter.post('/:id/end', requirePermission('manage_pk_events'), pkController.endPKBattle);

export default {
  userPKRouter,
  adminPKRouter,
};
