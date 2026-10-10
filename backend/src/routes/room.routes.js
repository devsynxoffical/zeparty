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
userRoomRouter.get('/:id/members', roomController.getRoomMembers);
userRoomRouter.put('/:id/members/:targetUserId/role', authenticate, roomController.updateMemberRole);
userRoomRouter.get('/:id/rankings', roomController.getRoomSendingRankings);
userRoomRouter.post('/:id/agora-token', authenticate, agoraController.getAgoraToken);
userRoomRouter.post('/:id/agora-token/refresh', authenticate, agoraController.postRefreshAgoraToken);

// Module 02: Paid Room Theme / DP Upload
userRoomRouter.post('/:id/theme/upload-paid', authenticate, roomController.uploadPaidRoomTheme);

// Module 03: Mic Config & Entry Announcement
userRoomRouter.get('/:id/mic-config', roomController.getRoomMicConfig);
userRoomRouter.put('/:id/mic-config', authenticate, roomController.updateRoomMicConfig);
userRoomRouter.get('/:id/announcement', roomController.getRoomAnnouncement);
userRoomRouter.put('/:id/announcement', authenticate, roomController.updateRoomAnnouncement);

// Module 06: Owner / Admin Room Options
userRoomRouter.post('/:id/youtube', authenticate, roomController.controlRoomYouTube);
userRoomRouter.post('/:id/super-wheel', authenticate, roomController.controlSuperWheel);
userRoomRouter.post('/:id/lucky-bag', authenticate, roomController.controlLuckyBag);
userRoomRouter.post('/:id/lock', authenticate, roomController.controlRoomLock);

// Module 07: Mic Seat Action Sheet
userRoomRouter.post('/:id/seats/:seatIndex/action', authenticate, roomController.manageMicSeatAction);

// Module 08: Mic Reaction Display
userRoomRouter.post('/:id/mic-reaction', authenticate, roomController.sendMicReaction);

// Module 31: Room Entry Banner Config
userRoomRouter.get('/:id/entry-banner-config', roomController.getEntryBannerConfig);

// Admin Live Room Management Routes
adminRoomRouter.use(authenticate);
adminRoomRouter.get('/pinned-positions', requirePermission('view_live_rooms'), roomController.getAdminPinnedPositions);
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
adminRoomRouter.post('/:id/remove-dp', requirePermission('moderation_actions'), (req, res, next) => {
  req.body = { ...req.body, coverImageUrl: null };
  roomController.postAdminUpdateRoomDp(req, res, next);
});
adminRoomRouter.post('/:id/delete-dp', requirePermission('moderation_actions'), (req, res, next) => {
  req.body = { ...req.body, coverImageUrl: null };
  roomController.postAdminUpdateRoomDp(req, res, next);
});
adminRoomRouter.delete('/:id/dp', requirePermission('moderation_actions'), (req, res, next) => {
  req.body = { ...req.body, coverImageUrl: null };
  roomController.postAdminUpdateRoomDp(req, res, next);
});


export default {
  userRoomRouter,
  adminRoomRouter,
};
