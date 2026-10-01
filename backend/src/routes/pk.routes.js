import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import pkController from '../controllers/pk.controller.js';

export const userPKRouter = express.Router();
userPKRouter.use(authenticate);

// Real-Time Matchmaking & Invites
userPKRouter.post('/matchmaking/join', pkController.joinMatchmaking);
userPKRouter.post('/matchmaking/leave', pkController.leaveMatchmaking);
userPKRouter.post('/invite', pkController.sendPKInvite);
userPKRouter.post('/invite/:id/respond', pkController.respondPKInvite);
userPKRouter.get('/available-hosts', pkController.getAvailablePKHosts);

// PK Battle Lifecycle
userPKRouter.post('/start', pkController.startPK);
userPKRouter.post('/:id/activate', pkController.activatePK);
userPKRouter.get('/room/:roomId', pkController.getRoomPKStatus);
userPKRouter.post('/:id/end', pkController.endPK);

export const adminPKRouter = express.Router();
adminPKRouter.use(authenticate);

adminPKRouter.get('/', requirePermission('view_pk_events'), pkController.listAdminPKEvents);
adminPKRouter.post('/start', requirePermission('manage_pk_events'), pkController.startPK);
adminPKRouter.post('/:id/end', requirePermission('manage_pk_events'), pkController.endPK);

export default {
  userPKRouter,
  adminPKRouter,
};
