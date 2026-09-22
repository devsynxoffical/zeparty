import express from 'express';
import authenticate from '../middlewares/authenticate.js';
import requirePermission from '../middlewares/requirePermission.js';
import roomController from '../controllers/room.controller.js';
import agoraController from '../controllers/agora.controller.js';

export const userRoomRouter = express.Router();
export const adminRoomRouter = express.Router();

// User & Mobile Live Room Routes
userRoomRouter.post('/', authenticate, roomController.createRoom);
userRoomRouter.get('/active', roomController.getActiveRooms);
userRoomRouter.get('/:id', roomController.getRoomDetails);
userRoomRouter.post('/:id/join', authenticate, roomController.joinRoom);
userRoomRouter.post('/:id/leave', authenticate, roomController.leaveRoom);
userRoomRouter.post('/:id/close', authenticate, roomController.closeMyRoom);
userRoomRouter.post('/:id/seats/:seatIndex/occupy', authenticate, roomController.occupySeat);
userRoomRouter.post('/:id/seats/:seatIndex/leave', authenticate, roomController.leaveSeat);
userRoomRouter.post('/:id/agora-token', authenticate, agoraController.getAgoraToken);
userRoomRouter.post('/:id/agora-token/refresh', authenticate, agoraController.postRefreshAgoraToken);

// Admin Live Room Management Routes
adminRoomRouter.use(authenticate);
adminRoomRouter.get('/', requirePermission('view_live_rooms'), roomController.getAdminRooms);
adminRoomRouter.get('/:id', requirePermission('view_live_rooms'), roomController.getAdminRoomById);
adminRoomRouter.get('/:id/agora-token', requirePermission('view_live_rooms'), roomController.getAdminAgoraToken);
adminRoomRouter.post('/:id/pin', requirePermission('view_live_rooms'), roomController.postAdminPinRoom);
adminRoomRouter.delete('/:id/pin', requirePermission('view_live_rooms'), roomController.deleteAdminPinRoom);
adminRoomRouter.post('/:id/close', requirePermission('moderation_actions'), roomController.postAdminCloseRoom);
adminRoomRouter.post('/:id/warn', requirePermission('moderation_actions'), roomController.postAdminWarnRoom);
adminRoomRouter.post('/:id/mute', requirePermission('moderation_actions'), roomController.postAdminMuteRoom);
adminRoomRouter.post('/:id/mute-participant', requirePermission('moderation_actions'), roomController.postAdminMuteParticipant);
adminRoomRouter.post('/:id/kick', requirePermission('moderation_actions'), roomController.postAdminKickUser);
adminRoomRouter.post('/:id/dp', requirePermission('moderation_actions'), roomController.postAdminUpdateRoomDp);
adminRoomRouter.delete('/:id/dp', requirePermission('moderation_actions'), (req, res, next) => {
  req.body = { ...req.body, coverImageUrl: null };
  roomController.postAdminUpdateRoomDp(req, res, next);
});

export default {
  userRoomRouter,
  adminRoomRouter,
};
