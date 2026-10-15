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
userRoomRouter.post('/:id/leave-mic', authenticate, roomController.leaveMic);
userRoomRouter.post('/:id/seats/leave', authenticate, roomController.leaveMic);
userRoomRouter.get('/:id/members', roomController.getRoomMembers);
userRoomRouter.get('/:id/viewers', roomController.getRoomViewers);
userRoomRouter.put('/:id/members/:targetUserId/role', authenticate, roomController.updateMemberRole);
userRoomRouter.get('/:id/rankings', roomController.getRoomSendingRankings);
userRoomRouter.post('/:id/agora-token', authenticate, agoraController.getAgoraToken);
userRoomRouter.post('/:id/agora-token/refresh', authenticate, agoraController.postRefreshAgoraToken);

// Module 02: Room Background & Paid Theme / DP Upload
userRoomRouter.get('/:id/background', roomController.getRoomBackground);
userRoomRouter.put('/:id/background', authenticate, roomController.updateRoomBackground);
userRoomRouter.post('/:id/background', authenticate, roomController.updateRoomBackground);
userRoomRouter.delete('/:id/background', authenticate, roomController.removeRoomBackground);
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

// Issue 04: Room User Moderation (Remove from Mic, Mute/Unmute, Kick)
userRoomRouter.post('/:id/moderation', authenticate, roomController.moderateUser);
userRoomRouter.post('/:id/moderation/remove-mic', authenticate, roomController.removeUserFromMic);
userRoomRouter.post('/:id/moderation/mute', authenticate, roomController.muteUser);
userRoomRouter.post('/:id/moderation/kick', authenticate, roomController.kickUser);
userRoomRouter.post('/:id/members/:targetUserId/remove-mic', authenticate, roomController.removeUserFromMic);
userRoomRouter.post('/:id/members/:targetUserId/mute', authenticate, roomController.muteUser);
userRoomRouter.post('/:id/members/:targetUserId/kick', authenticate, roomController.kickUser);

// Module 31: Room Entry Banner Config
userRoomRouter.get('/:id/entry-banner-config', roomController.getEntryBannerConfig);

// Change 13: Invite to Mic from Live Viewers
userRoomRouter.post('/:id/mic/invite', authenticate, roomController.inviteViewerToMic);
userRoomRouter.post('/:id/invite-mic', authenticate, roomController.inviteViewerToMic);
userRoomRouter.post('/:id/mic/invitations/:invitationId/accept', authenticate, roomController.acceptMicInvite);
userRoomRouter.post('/:id/mic/invite/:invitationId/accept', authenticate, roomController.acceptMicInvite);
userRoomRouter.post('/:id/mic/invite/accept', authenticate, roomController.acceptMicInvite);
userRoomRouter.post('/:id/mic/invitations/:invitationId/decline', authenticate, roomController.declineMicInvite);
userRoomRouter.post('/:id/mic/invite/:invitationId/decline', authenticate, roomController.declineMicInvite);
userRoomRouter.post('/:id/mic/invite/decline', authenticate, roomController.declineMicInvite);
userRoomRouter.delete('/:id/mic/invitations/:invitationId', authenticate, roomController.cancelMicInvite);
userRoomRouter.delete('/:id/mic/invite/:invitationId', authenticate, roomController.cancelMicInvite);

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
adminRoomRouter.post('/:id/remove-mic', requirePermission('moderation_actions'), roomController.postAdminRemoveFromMic);
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
adminRoomRouter.post('/:id/invite-mic', requirePermission('moderation_actions'), roomController.adminInviteViewerToMic);
adminRoomRouter.post('/:id/mic/invite', requirePermission('moderation_actions'), roomController.adminInviteViewerToMic);


export default {
  userRoomRouter,
  adminRoomRouter,
};
