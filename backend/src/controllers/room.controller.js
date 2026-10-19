import roomService from '../services/room.service.js';
import agoraService from '../services/agora.service.js';
import * as attendanceService from '../services/attendance.service.js';
import {
  createRoomSchema,
  queryActiveRoomsSchema,
  queryAdminRoomsSchema,
  occupySeatParamSchema,
  pinRoomSchema,
  adminCloseRoomSchema,
  adminWarnRoomSchema,
  adminMuteRoomSchema,
  adminMuteParticipantSchema,
  adminKickUserSchema,
  roomModerationSchema,
  roomModerationTargetSchema,
  roomModerationMuteSchema,
  adminUpdateDpSchema,
  roomIdParamSchema,
  updateRoomBackgroundSchema,
} from '../validators/room.validator.js';

export async function createRoom(req, res, next) {
  try {
    const validatedData = createRoomSchema.parse(req.body);
    const userId = req.auth.userId;

    const room = await roomService.createRoom({
      userId,
      ...validatedData,
    });

    return res.status(201).json({
      success: true,
      message: 'Room created successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function getActiveRooms(req, res, next) {
  try {
    const validatedQuery = queryActiveRoomsSchema.parse(req.query);
    const result = await roomService.getActiveRooms(validatedQuery);

    return res.status(200).json({
      success: true,
      message: 'Active rooms retrieved successfully',
      data: result.rooms,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getRoomDetails(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const room = await roomService.getRoomDetails(id);

    return res.status(200).json({
      success: true,
      message: 'Room details retrieved successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function joinRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const pin = req.body?.pin || req.body?.password;
    const isApproved = Boolean(req.body?.isApproved);
    const room = await roomService.joinRoom(id, userId, { pin, isApproved });

    return res.status(200).json({
      success: true,
      message: 'Joined room successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function leaveRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const room = await roomService.leaveRoom(id, userId);

    return res.status(200).json({
      success: true,
      message: 'Left room successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function occupySeat(req, res, next) {
  try {
    const { id, seatIndex } = occupySeatParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const result = await roomService.occupySeat(id, seatIndex, userId);
    const seat = result?.updatedSeat || result;
    const vacatedSeatIndex = result?.vacatedSeatIndex ?? null;

    return res.status(200).json({
      success: true,
      message: `Seat ${seatIndex} occupied successfully`,
      data: seat,
      vacatedSeatIndex,
    });
  } catch (err) {
    next(err);
  }
}

export async function leaveSeat(req, res, next) {
  try {
    const { id, seatIndex } = occupySeatParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const seat = await roomService.leaveSeat(id, seatIndex, userId);

    return res.status(200).json({
      success: true,
      message: `Seat ${seatIndex} released successfully`,
      data: seat,
    });
  } catch (err) {
    next(err);
  }
}

export async function leaveMic(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const userId = req.auth.userId;
    let seatIndex = req.body?.seatIndex !== undefined && req.body?.seatIndex !== null ? Number(req.body.seatIndex) : NaN;

    if (isNaN(seatIndex) || seatIndex < 0) {
      let resolvedRoomId = id;
      let room = await prisma.room.findUnique({ where: { id }, select: { id: true } });
      if (!room && id && id.length <= 16) {
        room = await prisma.room.findFirst({
          where: { id: { startsWith: id, mode: 'insensitive' } },
          select: { id: true },
        });
      }
      if (room) {
        resolvedRoomId = room.id;
      }

      const occupiedSeat = await prisma.roomSeat.findFirst({
        where: {
          roomId: resolvedRoomId,
          occupiedUserId: userId,
        },
      });

      if (occupiedSeat) {
        seatIndex = occupiedSeat.seatIndex;
      }
    }

    if (isNaN(seatIndex) || seatIndex < 0) {
      return res.status(200).json({
        success: true,
        message: 'User is not currently occupying any microphone seat',
        data: null,
      });
    }

    const seat = await roomService.leaveSeat(id, seatIndex, userId);
    return res.status(200).json({
      success: true,
      message: `Seat ${seatIndex} released successfully`,
      data: seat,
    });
  } catch (err) {
    next(err);
  }
}

export async function closeMyRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const room = await roomService.closeMyRoom(id, userId);

    return res.status(200).json({
      success: true,
      message: 'Room ended successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminRooms(req, res, next) {
  try {
    const validatedQuery = queryAdminRoomsSchema.parse(req.query);
    const result = await roomService.listRoomsForAdmin(validatedQuery);

    return res.status(200).json({
      success: true,
      message: 'Admin rooms retrieved successfully',
      data: result.rooms,
      pagination: result.pagination,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminRoomById(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const room = await roomService.getRoomDetails(id);

    return res.status(200).json({
      success: true,
      message: 'Admin room details retrieved successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminPinnedPositions(req, res, next) {
  try {
    const result = await roomService.adminGetPinnedPositions();
    return res.status(200).json({
      success: true,
      message: 'Pinned room positions retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminPinRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = pinRoomSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const room = await roomService.adminPinRoom(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: `Room pinned at position ${validatedBody.pinnedPosition} successfully`,
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function deleteAdminPinRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const room = await roomService.adminUnpinRoom(id, {
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Room unpinned successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminCloseRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminCloseRoomSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const room = await roomService.adminCloseRoom(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Room closed by admin successfully',
      data: room,
    });
  } catch (err) {
    next(err);
  }
}

export async function postAdminWarnRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminWarnRoomSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await roomService.adminIssueWarning(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminMuteRoom(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminMuteRoomSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await roomService.adminToggleRoomMute(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminMuteParticipant(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminMuteParticipantSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await roomService.adminMuteParticipant(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminKickUser(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminKickUserSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await roomService.adminKickUser(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminUpdateRoomDp(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const validatedBody = adminUpdateDpSchema.parse(req.body);
    const adminId = req.auth.userId;
    const adminName = req.admin?.name || 'Administrator';
    const ipAddress = req.ip || req.headers['x-forwarded-for'];

    const result = await roomService.adminUpdateRoomDp(id, {
      ...validatedBody,
      adminId,
      adminName,
      ipAddress,
    });

    return res.status(200).json({
      success: true,
      message: 'Room DP updated successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getAdminAgoraToken(req, res, next) {
  try {
    const { id: roomId } = req.params;
    const userId = req.auth.userId;

    const result = await agoraService.issueRoomAgoraToken({ roomId, userId });

    return res.status(200).json({
      success: true,
      message: 'Admin Agora RTC token generated successfully.',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getRoomMembers(req, res, next) {
  try {
    const { id } = req.params;
    const { search } = req.query;
    const result = await roomService.getRoomMembers(id, { search });

    return res.status(200).json({
      success: true,
      message: 'Room members retrieved successfully',
      data: result.members,
      totalCount: result.totalCount,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateMemberRole(req, res, next) {
  try {
    const { id, targetUserId } = req.params;
    const { role } = req.body;
    const actorUserId = req.auth.userId;

    const result = await roomService.updateMemberRole(id, actorUserId, targetUserId, { role });

    return res.status(200).json({
      success: true,
      message: `User role updated to ${role} successfully`,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getRoomSendingRankings(req, res, next) {
  try {
    const { id } = req.params;
    const { period } = req.query;
    const currentUserId = req.auth?.userId;

    const result = await roomService.getRoomSendingRankings(id, { period: period || 'daily', currentUserId });

    return res.status(200).json({
      success: true,
      message: 'Room sending rankings retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function uploadPaidRoomTheme(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId;
    const { themeUrl, themeType } = req.body;
    const result = await roomService.uploadPaidRoomTheme({ roomId: id, userId, themeUrl, themeType });
    return res.status(200).json({
      success: true,
      message: result.message,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function getRoomMicConfig(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.getRoomMicConfig(id);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function updateRoomMicConfig(req, res, next) {
  try {
    const { id } = req.params;
    const { micPreset } = req.body;
    const actorUserId = req.auth?.userId;
    const result = await roomService.updateRoomMicConfig(id, { micPreset, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getRoomAnnouncement(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.getRoomAnnouncement(id);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function updateRoomAnnouncement(req, res, next) {
  try {
    const { id } = req.params;
    const { announcement, isEnabled } = req.body;
    const actorUserId = req.auth?.userId;
    const result = await roomService.updateRoomAnnouncement(id, { announcement, isEnabled, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function controlRoomYouTube(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlRoomYouTube(id, { ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function controlSuperWheel(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlSuperWheel(id, { ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getSuperWheel(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.controlSuperWheel(id, { action: 'GET' });
    return res.status(200).json({ success: true, data: result.data });
  } catch (err) {
    next(err);
  }
}

export async function joinSuperWheel(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlSuperWheel(id, { action: 'JOIN', ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function spinSuperWheel(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlSuperWheel(id, { action: 'SPIN', ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function cancelSuperWheel(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlSuperWheel(id, { action: 'CANCEL', ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function controlLuckyBag(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlLuckyBag(id, { ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getActiveLuckyBags(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.controlLuckyBag(id, { action: 'GET' });
    return res.status(200).json({ success: true, data: result.data });
  } catch (err) {
    next(err);
  }
}

export async function claimLuckyBag(req, res, next) {
  try {
    const { id, bagId } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlLuckyBag(id, {
      action: 'CLAIM',
      bagId: bagId || req.body.bagId,
      actorUserId,
    });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function controlRoomLock(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.controlRoomLock(id, { ...req.body, actorUserId });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function updateRoomProfile(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId || req.user?.id;
    const { title, coverImageUrl, coverUrl, category, roomType, backgroundImageUrl, capacity, seatCapacity } = req.body;
    const result = await roomService.updateRoomProfile(id, userId, {
      title,
      coverImageUrl: coverImageUrl || coverUrl,
      category,
      roomType,
      backgroundImageUrl,
      capacity,
      seatCapacity,
    });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function manageMicSeatAction(req, res, next) {
  try {
    const { id, seatIndex } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.manageMicSeatAction(id, { seatIndex, ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function sendMicReaction(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId;
    const result = await roomService.sendMicReaction(id, { ...req.body, actorUserId });
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getEntryBannerConfig(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.getEntryBannerConfig(id);
    return res.status(200).json({ success: true, data: result });
  } catch (err) {
    next(err);
  }
}

export async function getRoomBackground(req, res, next) {
  try {
    const { id } = req.params;
    const result = await roomService.getRoomBackground(id);
    return res.status(200).json({
      success: true,
      message: 'Room background retrieved successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function updateRoomBackground(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId;
    const validated = updateRoomBackgroundSchema.parse(req.body);
    const result = await roomService.updateRoomBackground(id, userId, validated);
    return res.status(200).json({
      success: true,
      message: result.message,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function removeRoomBackground(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId;
    const result = await roomService.removeRoomBackground(id, userId);
    return res.status(200).json({
      success: true,
      message: result.message,
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function removeUserFromMic(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId || req.user?.id;
    const targetUserId = req.params.targetUserId || req.body.targetUserId;
    const { reason } = req.body;

    if (!targetUserId) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Target user ID is required' } });
    }

    const result = await roomService.removeRoomUserFromMic(id, actorUserId, { targetUserId, reason });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function muteUser(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId || req.user?.id;
    const targetUserId = req.params.targetUserId || req.body.targetUserId;
    const isMuted = req.body.isMuted !== undefined ? Boolean(req.body.isMuted) : true;
    const { reason } = req.body;

    if (!targetUserId) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Target user ID is required' } });
    }

    const result = await roomService.moderateRoomUserMute(id, actorUserId, { targetUserId, isMuted, reason });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function kickUser(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId || req.user?.id;
    const targetUserId = req.params.targetUserId || req.body.targetUserId;
    const { reason } = req.body;

    if (!targetUserId) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Target user ID is required' } });
    }

    const result = await roomService.kickRoomUser(id, actorUserId, { targetUserId, reason });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function moderateUser(req, res, next) {
  try {
    const { id } = req.params;
    const actorUserId = req.auth?.userId || req.user?.id;
    const validated = roomModerationSchema.parse(req.body);

    const result = await roomService.moderateRoomUser(id, actorUserId, validated);
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminRemoveFromMic(req, res, next) {
  try {
    const { id } = req.params;
    const { targetUserId, reason } = req.body;
    const adminId = req.user?.id || 'admin';
    const adminName = req.user?.username || req.user?.name || 'Admin Moderation';

    if (!targetUserId) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Target user ID is required' } });
    }

    const result = await roomService.adminRemoveFromMic(id, {
      targetUserId,
      reason,
      adminId,
      adminName,
      ipAddress: req.ip,
    });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function inviteViewerToMic(req, res, next) {
  try {
    const { id } = req.params;
    const { targetUserId, seatIndex } = req.body;
    const actorUserId = req.auth?.userId || req.user?.id;

    const result = await roomService.createMicInvite({
      roomId: id,
      actorUserId,
      targetUserId,
      seatIndex: seatIndex !== undefined && seatIndex !== null ? Number(seatIndex) : null,
    });

    return res.status(201).json({
      success: true,
      message: 'Invitation to mic sent successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function acceptMicInvite(req, res, next) {
  try {
    const { id, invitationId } = req.params;
    const userId = req.auth?.userId || req.user?.id;

    const result = await roomService.acceptMicInvite({
      roomId: id,
      invitationId,
      userId,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function declineMicInvite(req, res, next) {
  try {
    const { id, invitationId } = req.params;
    const { reason } = req.body;
    const userId = req.auth?.userId || req.user?.id;

    const result = await roomService.declineMicInvite({
      roomId: id,
      invitationId,
      userId,
      reason: reason || 'DECLINED_BY_USER',
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function cancelMicInvite(req, res, next) {
  try {
    const { id, invitationId } = req.params;
    const actorUserId = req.auth?.userId || req.user?.id;

    const result = await roomService.cancelMicInvite({
      roomId: id,
      invitationId,
      actorUserId,
    });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function getRoomViewers(req, res, next) {
  try {
    const { id } = req.params;
    const { search } = req.query;
    const result = await roomService.getRoomMembers(id, { search });

    return res.status(200).json({
      success: true,
      message: 'Room viewers retrieved successfully',
      data: result.members,
      totalCount: result.totalCount,
    });
  } catch (err) {
    next(err);
  }
}

export async function adminInviteViewerToMic(req, res, next) {
  try {
    const { id } = req.params;
    const { targetUserId, seatIndex } = req.body;
    const adminId = req.user?.id || 'admin';

    const result = await roomService.createMicInvite({
      roomId: id,
      actorUserId: adminId,
      targetUserId,
      seatIndex: seatIndex !== undefined && seatIndex !== null ? Number(seatIndex) : null,
    });

    return res.status(201).json({
      success: true,
      message: 'Admin invitation to mic sent successfully',
      data: result,
    });
  } catch (err) {
    next(err);
  }
}

export async function recordRoomHeartbeat(req, res, next) {
  try {
    const hostUserId = req.auth.userId;
    const { id } = req.params;
    const result = await attendanceService.recordBroadcastHeartbeat({ roomId: id, hostUserId });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function clearRoomFeed(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const userId = req.auth.userId;
    const { reason } = req.body || {};
    const result = await roomService.clearRoomFeed(id, userId, { reason });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postAdminClearRoomFeed(req, res, next) {
  try {
    const { id } = roomIdParamSchema.parse(req.params);
    const adminId = req.auth.userId;
    const { reason } = req.body || {};
    const result = await roomService.adminClearRoomFeed(id, adminId, { reason });

    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}


export async function updateRoomLayout(req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.auth?.userId || req.user?.id;
    const { capacity, seatCapacity, roomType } = req.body;
    const result = await roomService.updateRoomLayout(id, userId, {
      capacity,
      seatCapacity,
      roomType,
    });
    return res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

export default {
  createRoom,
  getActiveRooms,
  getRoomDetails,
  joinRoom,
  leaveRoom,
  occupySeat,
  leaveSeat,
  leaveMic,
  closeMyRoom,
  recordRoomHeartbeat,
  getAdminRooms,
  getAdminRoomById,
  getAdminPinnedPositions,
  postAdminPinRoom,
  deleteAdminPinRoom,
  postAdminCloseRoom,
  postAdminWarnRoom,
  postAdminMuteRoom,
  postAdminMuteParticipant,
  postAdminKickUser,
  postAdminRemoveFromMic,
  postAdminUpdateRoomDp,
  getAdminAgoraToken,
  getRoomMembers,
  updateMemberRole,
  getRoomSendingRankings,
  uploadPaidRoomTheme,
  updateRoomBackground,
  removeRoomBackground,
  getRoomBackground,
  getRoomMicConfig,
  updateRoomMicConfig,
  getRoomAnnouncement,
  updateRoomAnnouncement,
  controlRoomYouTube,
  controlSuperWheel,
  getSuperWheel,
  joinSuperWheel,
  spinSuperWheel,
  cancelSuperWheel,
  controlLuckyBag,
  getActiveLuckyBags,
  claimLuckyBag,
  controlRoomLock,
  updateRoomProfile,
  updateRoomLayout,
  manageMicSeatAction,
  sendMicReaction,
  getEntryBannerConfig,
  removeUserFromMic,
  muteUser,
  kickUser,
  moderateUser,
  inviteViewerToMic,
  acceptMicInvite,
  declineMicInvite,
  cancelMicInvite,
  getRoomViewers,
  adminInviteViewerToMic,
  clearRoomFeed,
  postAdminClearRoomFeed,
};

