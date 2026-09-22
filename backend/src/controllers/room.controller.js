import roomService from '../services/room.service.js';
import agoraService from '../services/agora.service.js';
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
  adminUpdateDpSchema,
  roomIdParamSchema,
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
    const room = await roomService.joinRoom(id, userId);

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
    const seat = await roomService.occupySeat(id, seatIndex, userId);

    return res.status(200).json({
      success: true,
      message: `Seat ${seatIndex} occupied successfully`,
      data: seat,
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

export default {
  createRoom,
  getActiveRooms,
  getRoomDetails,
  joinRoom,
  leaveRoom,
  occupySeat,
  leaveSeat,
  closeMyRoom,
  getAdminRooms,
  getAdminRoomById,
  postAdminPinRoom,
  deleteAdminPinRoom,
  postAdminCloseRoom,
  postAdminWarnRoom,
  postAdminMuteRoom,
  postAdminMuteParticipant,
  postAdminKickUser,
  postAdminUpdateRoomDp,
  getAdminAgoraToken,
};
