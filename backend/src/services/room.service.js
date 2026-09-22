import crypto from 'crypto';
import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || 'SYSTEM',
        adminName: adminName || 'System',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in room.service:', err);
  }
}

export async function createRoom(
  { userId, title, coverImageUrl, roomType, category, isPrivate, roomPin },
  db = prisma
) {
  const agoraChannelName = `room_${crypto.randomUUID().replace(/-/g, '')}`;

  const room = await roomRepository.createRoomWithSeats(
    {
      creatorUserId: userId,
      title,
      coverImageUrl,
      roomType,
      category,
      isPrivate,
      roomPin,
      agoraChannelName,
    },
    db
  );

  // Broadcast new room creation to global realtime discovery subscribers
  try {
    socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CREATED, room);
  } catch (err) {
    console.error('Failed to broadcast ROOM_CREATED socket event:', err);
  }

  return room;
}

export async function getActiveRooms(filters, db = prisma) {
  return await roomRepository.findActiveRooms(filters, db);
}

export async function getRoomDetails(roomId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Calculate gift coin total from transactions if present
  let totalGiftCoins = 0;
  if (Array.isArray(room.giftTransactions)) {
    totalGiftCoins = room.giftTransactions.reduce((sum, tx) => sum + Number(tx.totalCoins || 0), 0);
  }

  // Check if any seats are muted to determine room-level mute flag
  const isRoomMuted = Array.isArray(room.seats) && room.seats.length > 0 && room.seats.every((s) => s.isMuted);

  return {
    ...room,
    giftsReceivedCoins: totalGiftCoins,
    totalGifts: totalGiftCoins,
    isMuted: isRoomMuted,
  };
}

export async function joinRoom(roomId, userId, db = prisma) {
  return await roomRepository.joinRoomTx({ roomId, userId }, db);
}

export async function leaveRoom(roomId, userId, db = prisma) {
  return await roomRepository.leaveRoomTx({ roomId, userId }, db);
}

export async function occupySeat(roomId, seatIndex, userId, db = prisma) {
  return await roomRepository.occupySeatTx({ roomId, seatIndex, userId }, db);
}

export async function leaveSeat(roomId, seatIndex, userId, options = {}, db = prisma) {
  const force = typeof options === 'boolean' ? options : (options?.force || false);
  const targetDb = options && typeof options === 'object' && options.$transaction ? options : db;
  return await roomRepository.leaveSeatTx({ roomId, seatIndex, userId, force }, targetDb);
}

export async function closeMyRoom(roomId, userId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  if (room.creatorUserId !== userId) {
    const error = new Error('Only the room creator can close this room');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const closedRoom = await roomRepository.closeRoomTx({ roomId, status: 'ENDED' }, db);

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, {
    roomId,
    status: 'ENDED',
    reason: 'HOST_CLOSED',
  });

  return closedRoom;
}

export async function listRoomsForAdmin(filters, db = prisma) {
  return await roomRepository.findAdminRooms(filters, db);
}

export async function adminPinRoom(
  roomId,
  { pinnedPosition = 1, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { isPinnedTop: room.isPinnedTop, pinnedPosition: room.pinnedPosition };
  const updatedRoom = await roomRepository.pinRoom({ roomId, isPinnedTop: true, pinnedPosition }, db);
  const afterState = { isPinnedTop: updatedRoom.isPinnedTop, pinnedPosition: updatedRoom.pinnedPosition };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_PINNED_TOP',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason: `Pinned at position ${pinnedPosition}`,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_PINNED, {
    roomId,
    isPinnedTop: true,
    pinnedPosition,
  });
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_PINNED, {
    roomId,
    isPinnedTop: true,
    pinnedPosition,
  });

  return updatedRoom;
}

export async function adminUnpinRoom(
  roomId,
  { adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { isPinnedTop: room.isPinnedTop, pinnedPosition: room.pinnedPosition };
  const updatedRoom = await roomRepository.pinRoom({ roomId, isPinnedTop: false, pinnedPosition: null }, db);
  const afterState = { isPinnedTop: false, pinnedPosition: null };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_UNPINNED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_UNPINNED, {
    roomId,
    isPinnedTop: false,
    pinnedPosition: null,
  });
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_UNPINNED, {
    roomId,
    isPinnedTop: false,
    pinnedPosition: null,
  });

  return updatedRoom;
}

export async function adminCloseRoom(
  roomId,
  { reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const beforeState = { status: room.status };
  const updatedRoom = await roomRepository.closeRoomTx({ roomId, status: 'CLOSED_BY_ADMIN' }, db);
  const afterState = { status: 'CLOSED_BY_ADMIN' };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_CLOSED_BY_ADMIN',
      targetEntity: 'Room',
      targetEntityId: roomId,
      beforeStateJson: beforeState,
      afterStateJson: afterState,
      reason,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, {
    roomId,
    status: 'CLOSED_BY_ADMIN',
    reason,
  });

  return updatedRoom;
}

export async function adminIssueWarning(
  roomId,
  { reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const payload = {
    roomId,
    roomTitle: room.title,
    message: reason || 'Community Guidelines Violation Warning',
    reason: reason || 'Community Guidelines Violation Warning',
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: 'ROOM_WARNING_ISSUED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: reason || 'Official moderation warning broadcasted',
      ipAddress,
    },
    db
  );

  // Broadcast to room
  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_WARNING_ISSUED, payload);
  socketEmitter.emitToRoom(roomId, 'room:warning', payload);

  return { success: true, message: 'Warning broadcasted successfully', data: payload };
}

export async function adminToggleRoomMute(
  roomId,
  { isMuted, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomMuteStatus({ roomId, isMuted }, db);

  const payload = {
    roomId,
    isMuted: Boolean(isMuted),
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: isMuted ? 'ROOM_MUTED' : 'ROOM_UNMUTED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: isMuted ? 'Room audio muted by admin' : 'Room audio unmuted by admin',
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_MUTED, payload);
  socketEmitter.emitToRoom(roomId, 'room:muted', payload);

  return { success: true, isMuted: Boolean(isMuted), room: updatedRoom };
}

export async function adminMuteParticipant(
  roomId,
  { targetUserId, seatIndex, isMuted, adminId, adminName, ipAddress },
  db = prisma
) {
  if (seatIndex !== undefined && seatIndex !== null) {
    await roomRepository.updateSeatMuteStatus({ roomId, seatIndex, isMuted }, db);
  } else if (targetUserId) {
    await roomRepository.updateUserSeatMuteStatus({ roomId, userId: targetUserId, isMuted }, db);
  }

  const payload = {
    roomId,
    targetUserId,
    seatIndex,
    isMuted: Boolean(isMuted),
    adminName: adminName || 'Admin Moderation',
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: isMuted ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: `Participant ${targetUserId || seatIndex} ${isMuted ? 'muted' : 'unmuted'} by admin`,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_MUTED, payload);
  socketEmitter.emitToRoom(roomId, 'room:user_muted', payload);

  return { success: true, data: payload };
}

export async function adminKickUser(
  roomId,
  { targetUserId, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isHost = room.creatorUserId === targetUserId;

  if (isHost) {
    // If the host is kicked, close the stream
    await roomRepository.closeRoomTx({ roomId, status: 'HOST_KICKED' }, db);

    const kickPayload = {
      roomId,
      targetUserId,
      kickedByUserId: adminId || 'admin',
      isHost: true,
      reason: 'Host removed by platform moderation',
      timestamp: new Date().toISOString(),
    };

    socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
    socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);

    socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, {
      roomId,
      status: 'ENDED',
      reason: 'HOST_KICKED_BY_ADMIN',
    });

    await logAudit(
      {
        adminId,
        adminName,
        action: 'HOST_KICKED_ROOM_CLOSED',
        targetEntity: 'Room',
        targetEntityId: roomId,
        reason: `Host ${targetUserId} kicked by admin moderation`,
        ipAddress,
      },
      db
    );

    return { success: true, message: 'Host kicked and room closed', isHost: true };
  }

  // Regular participant/speaker/viewer
  await roomRepository.kickUserFromRoomTx({ roomId, targetUserId }, db);

  const kickPayload = {
    roomId,
    targetUserId,
    kickedByUserId: adminId || 'admin',
    isHost: false,
    reason: 'Participant removed by platform moderation',
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'PARTICIPANT_KICKED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: `Participant ${targetUserId} kicked by admin`,
      ipAddress,
    },
    db
  );

  return { success: true, message: 'Participant kicked successfully', isHost: false };
}

export async function adminUpdateRoomDp(
  roomId,
  { coverImageUrl, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomCoverImage({ roomId, coverImageUrl }, db);

  const payload = {
    roomId,
    coverImageUrl,
    dpDeleted: !coverImageUrl,
    timestamp: new Date().toISOString(),
  };

  await logAudit(
    {
      adminId,
      adminName,
      action: coverImageUrl ? 'ROOM_DP_UPDATED' : 'ROOM_DP_DELETED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: coverImageUrl ? 'Room display picture updated by admin' : 'Room display picture removed by admin',
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_DP_UPDATED, payload);
  socketEmitter.emitToRoom(roomId, 'room:dp_updated', payload);

  return updatedRoom;
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
  listRoomsForAdmin,
  adminPinRoom,
  adminUnpinRoom,
  adminCloseRoom,
  adminIssueWarning,
  adminToggleRoomMute,
  adminMuteParticipant,
  adminKickUser,
  adminUpdateRoomDp,
};
