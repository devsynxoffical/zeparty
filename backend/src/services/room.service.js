import crypto from 'crypto';
import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';
import { clearHostAbsentTimer } from '../socket/roomTimer.manager.js';
import presenceService from '../socket/presence.service.js';
import micInviteService from './micInvite.service.js';
import * as attendanceService from './attendance.service.js';
import wheelService from './wheel.service.js';
import luckyBagService from './luckyBag.service.js';
import bcrypt from 'bcryptjs';

async function logAudit(
  { adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress },
  db = prisma
) {
  try {
    if (!adminId) return;
    const adminExists = await db.admin.findUnique({ where: { id: adminId } });
    if (!adminExists) return;

    await db.auditLog.create({
      data: {
        adminId,
        adminName: adminName || adminExists.name || 'System',
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
    // Non-blocking platform audit logging
  }
}

export async function createRoom(
  { userId, title, coverImageUrl, backgroundImageUrl, roomType, category, isPrivate, roomPin },
  db = prisma
) {
  // 1. Any user can start live broadcast or audio party room freely without host registration requirement
  const hostProfile = await db.hostProfile.findUnique({
    where: { userId },
  });

  // Automatically close any previous active LIVE rooms created by this user
  try {
    const existingRooms = await db.room.findMany({
      where: { creatorUserId: userId, status: 'LIVE' },
      select: { id: true },
    });
    for (const er of existingRooms) {
      clearHostAbsentTimer(er.id);
      await db.room.update({
        where: { id: er.id },
        data: { status: 'ENDED', endedAt: new Date(), currentViewersCount: 0 },
      });
      socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_CLOSED, {
        roomId: er.id,
        status: 'ENDED',
        reason: 'NEW_BROADCAST_CREATED',
      });
      socketEmitter.broadcastGlobal('room:closed', { roomId: er.id, status: 'ENDED' });
      socketEmitter.broadcastGlobal('room:deleted', { roomId: er.id });
    }
  } catch (err) {
    console.warn('[RoomService] Error auto-closing previous rooms:', err?.message);
  }

  const agoraChannelName = `room_${crypto.randomUUID().replace(/-/g, '')}`;

  const room = await roomRepository.createRoomWithSeats(
    {
      creatorUserId: userId,
      title,
      coverImageUrl,
      backgroundImageUrl: backgroundImageUrl || null,
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
    socketEmitter.broadcastGlobal('room:created', room);
    socketEmitter.broadcastGlobal('room_created', room);
    socketEmitter.broadcastGlobal('room:started', room);
  } catch (err) {
    console.error('Failed to broadcast ROOM_CREATED socket event:', err);
  }

  return room;
}

export async function getActiveRooms(filters, db = prisma) {
  return await roomRepository.findActiveRooms(filters, db);
}

export async function cleanupStaleRooms(db = prisma) {
  try {
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago
    const staleRooms = await db.room.findMany({
      where: {
        status: 'LIVE',
        createdAt: { lt: cutoff },
      },
      select: { id: true },
    });

    if (staleRooms.length > 0) {
      const ids = staleRooms.map((r) => r.id);
      await db.room.updateMany({
        where: { id: { in: ids } },
        data: {
          status: 'ENDED',
          endedAt: new Date(),
          currentViewersCount: 0,
        },
      });
      console.log(`[RoomService] Cleaned up ${staleRooms.length} stale live rooms.`);
    }

    // Also close any orphaned room whose creator no longer exists
    const liveRooms = await db.room.findMany({
      where: { status: 'LIVE' },
      select: { id: true, creatorUserId: true },
    });
    const userIds = liveRooms.map((r) => r.creatorUserId);
    const existingUsers = await db.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true },
    });
    const existingSet = new Set(existingUsers.map((u) => u.id));
    const orphaned = liveRooms.filter((r) => !existingSet.has(r.creatorUserId));
    if (orphaned.length > 0) {
      const orphanedIds = orphaned.map((r) => r.id);
      await db.room.updateMany({
        where: { id: { in: orphanedIds } },
        data: {
          status: 'ENDED',
          endedAt: new Date(),
          currentViewersCount: 0,
        },
      });
      console.log(`[RoomService] Cleaned up ${orphaned.length} orphaned live rooms.`);
    }

    return { cleanedCount: staleRooms.length + orphaned.length };
  } catch (err) {
    console.warn('[RoomService] Cleanup stale rooms warning:', err?.message);
    return { error: err?.message };
  }
}

export async function getRoomDetails(roomId, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);

  // If room is ended or not live, check if host has restarted and has an active LIVE room session
  const isRoomLive = room && ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
  if (!isRoomLive && room && room.creatorUserId) {
    const activeRoom = await db.room.findFirst({
      where: {
        creatorUserId: room.creatorUserId,
        status: 'LIVE',
      },
      select: { id: true },
    });
    if (activeRoom) {
      const freshRoom = await roomRepository.findRoomById(activeRoom.id, db);
      if (freshRoom) {
        room = freshRoom;
      }
    }
  }

  // If room wasn't found by ID, check if roomId is a host's userId who has an active LIVE room
  if (!room && roomId) {
    const activeRoomByUser = await db.room.findFirst({
      where: {
        creatorUserId: roomId,
        status: 'LIVE',
      },
      select: { id: true },
    });
    if (activeRoomByUser) {
      room = await roomRepository.findRoomById(activeRoomByUser.id, db);
    }
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Calculate real-time viewer count
  let viewerCount = typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number' && presCount >= 0) {
      viewerCount = Math.max(viewerCount, presCount);
    }
  } catch (_) {}

  // Calculate gift coin total from transactions if present
  let totalGiftCoins = 0;
  if (Array.isArray(room.giftTransactions)) {
    totalGiftCoins = room.giftTransactions.reduce((sum, tx) => sum + Number(tx.totalCoins || 0), 0);
  }

  // Calculate today's daily gift coin total (Issue 08: Trophy Counter Sync)
  const todayUtc = new Date();
  todayUtc.setUTCHours(0, 0, 0, 0);
  let dailyGiftCoins = 0;
  try {
    const dailyTx = await db.giftTransaction.aggregate({
      where: {
        roomId: room.id,
        createdAt: { gte: todayUtc },
      },
      _sum: { totalCoins: true },
    });
    dailyGiftCoins = Number(dailyTx._sum.totalCoins || 0);
  } catch (_) {}

  // Check if any seats are muted to determine room-level mute flag
  const isRoomMuted = Array.isArray(room.seats) && room.seats.length > 0 && room.seats.every((s) => s.isMuted);

  const hasPin = Boolean(room.roomPin);
  const lockMode = hasPin ? 'PIN' : (room.isPrivate ? 'Approval' : 'NONE');
  const { roomPin: _confidentialPin, ...safeRoom } = room;

  return {
    ...safeRoom,
    currentViewersCount: viewerCount,
    viewerCount,
    count: viewerCount,
    backgroundImageUrl: room.backgroundImageUrl || null,
    background: room.backgroundImageUrl || null,
    giftsReceivedCoins: totalGiftCoins,
    totalGifts: totalGiftCoins,
    roomSendingTotal: dailyGiftCoins,
    dailySendingTotal: dailyGiftCoins,
    periodTotalCoins: dailyGiftCoins,
    trophyCoins: dailyGiftCoins,
    seatCapacity: (room.seats || []).length || 10,
    capacity: (room.seats || []).length || 10,
    isLocked: Boolean(room.isPrivate),
    lockMode,
    isMuted: isRoomMuted,
  };
}

export async function joinRoom(roomId, userId, { pin = null, isApproved = false } = {}, db = prisma) {
  const result = await roomRepository.joinRoomTx({ roomId, userId, pin, isApproved }, db);
  if (result) {
    if (result.creatorUserId === userId) {
      try {
        clearHostAbsentTimer(result.id);
      } catch (_) {}
    }
    let viewerCount = typeof result.currentViewersCount === 'number' ? result.currentViewersCount : 0;
    try {
      const presCount = await presenceService.getRoomViewerCount(result.id || roomId, result.creatorUserId);
      if (typeof presCount === 'number' && presCount >= 0) {
        viewerCount = Math.max(viewerCount, presCount);
      }
    } catch (_) {}

    const payload = {
      roomId: result.id || roomId,
      viewerCount,
      count: viewerCount,
      currentViewersCount: viewerCount,
    };
    try {
      socketEmitter.emitToRoom(roomId, 'room:viewer_count_changed', payload);
      socketEmitter.emitToRoom(roomId, 'room:viewer_count', payload);
      socketEmitter.emitToRoom(roomId, 'viewer_count_changed', payload);
    } catch (_) {}
  }
  return result;
}

export async function leaveRoom(roomId, userId, db = prisma) {
  const result = await roomRepository.leaveRoomTx({ roomId, userId }, db);
  if (result) {
    let viewerCount = typeof result.currentViewersCount === 'number' ? result.currentViewersCount : 0;
    try {
      const presCount = await presenceService.getRoomViewerCount(result.id || roomId, result.creatorUserId);
      if (typeof presCount === 'number' && presCount >= 0) {
        viewerCount = presCount;
      }
    } catch (_) {}

    const payload = {
      roomId: result.id || roomId,
      viewerCount,
      count: viewerCount,
      currentViewersCount: viewerCount,
    };
    try {
      socketEmitter.emitToRoom(roomId, 'room:viewer_count_changed', payload);
      socketEmitter.emitToRoom(roomId, 'room:viewer_count', payload);
      socketEmitter.emitToRoom(roomId, 'viewer_count_changed', payload);
    } catch (_) {}
  }
  return result;
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

  clearHostAbsentTimer(roomId);
  micInviteService.clearAllInvitesForRoom(roomId);
  await attendanceService.endBroadcastSession({ roomId, hostUserId: userId }, db).catch(() => {});
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

export async function adminGetPinnedPositions(db = prisma) {
  const pinnedRooms = await db.room.findMany({
    where: { isPinnedTop: true },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true } },
        },
      },
    },
    orderBy: { pinnedPosition: 'asc' },
  });

  const positions = [1, 2, 3].map((pos) => {
    const match = pinnedRooms.find((r) => r.pinnedPosition === pos);
    return {
      position: pos,
      isOccupied: !!match,
      room: match
        ? {
            id: match.id,
            title: match.title,
            roomType: match.roomType,
            status: match.status,
            country: match.country || match.creator?.country || 'Global',
            pinnedPosition: match.pinnedPosition,
            owner: {
              userId: match.creator?.id,
              username: match.creator?.username,
              displayName: match.creator?.profile?.displayName || match.creator?.username,
              avatarUrl: match.creator?.avatarUrl,
            },
          }
        : null,
    };
  });

  return {
    totalPinned: pinnedRooms.length,
    maxPositions: 3,
    positions,
  };
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

  // Broadcast to room and global
  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_WARNING_ISSUED, payload);
  socketEmitter.emitToRoom(roomId, 'room:warning', payload);
  socketEmitter.emitToRoom(roomId, 'room_warning', payload);
  socketEmitter.broadcastGlobal('room:warning', payload);
  socketEmitter.broadcastGlobal(SOCKET_EVENTS.ROOM_WARNING_ISSUED, payload);

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
  socketEmitter.broadcastGlobal('room:muted', payload);

  return { success: true, isMuted: Boolean(isMuted), room: updatedRoom };
}

export async function adminMuteParticipant(
  roomId,
  { targetUserId, seatIndex, isMuted, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const parsedSeatIndex = (seatIndex !== undefined && seatIndex !== null && seatIndex !== '') ? Number(seatIndex) : null;

  if (parsedSeatIndex !== null) {
    await roomRepository.updateSeatMuteStatus({ roomId, seatIndex: parsedSeatIndex, isMuted }, db);
  }
  if (targetUserId) {
    await roomRepository.updateUserSeatMuteStatus({ roomId, userId: targetUserId, isMuted }, db);
  }

  const payload = {
    roomId,
    targetUserId: targetUserId || null,
    seatIndex: parsedSeatIndex,
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
      reason: `Participant ${targetUserId || parsedSeatIndex} ${isMuted ? 'muted' : 'unmuted'} by admin`,
      ipAddress,
    },
    db
  );

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_MUTED, payload);
  socketEmitter.emitToRoom(roomId, 'room:user_muted', payload);
  if (targetUserId) {
    socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_MUTED, payload);
    socketEmitter.emitToUser(targetUserId, 'room:user_muted', payload);
  }
  socketEmitter.broadcastGlobal('room:user_muted', payload);

  return { success: true, data: payload };
}

export async function adminKickUser(
  roomId,
  { targetUserId, reason, adminId, adminName, ipAddress },
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
      reason: reason || 'Host removed by platform moderation',
      timestamp: new Date().toISOString(),
    };

    socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
    socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);
    socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
    socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);
    socketEmitter.broadcastGlobal('room:user_kicked', kickPayload);

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
        reason: `Host ${targetUserId} kicked by admin moderation: ${reason || 'Violation'}`,
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
    reason: reason || 'Participant removed by platform moderation',
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToRoom(roomId, 'room:user_kicked', kickPayload);
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);
  socketEmitter.broadcastGlobal('room:user_kicked', kickPayload);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'PARTICIPANT_KICKED',
      targetEntity: 'Room',
      targetEntityId: roomId,
      reason: `Participant ${targetUserId} kicked by admin: ${reason || 'Violation'}`,
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

export async function getRoomMembers(roomId, { search } = {}, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, creatorUserId: true },
  });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true, creatorUserId: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const resolvedRoomId = room.id;
  const hostSeat = await db.roomSeat.findFirst({
    where: {
      roomId: resolvedRoomId,
      occupiedUserId: room.creatorUserId,
    },
  });
  const hostIsOccupyingSeat = Boolean(hostSeat);

  const where = {
    roomId: resolvedRoomId,
  };
  if (hostIsOccupyingSeat) {
    where.userId = { not: room.creatorUserId };
  }

  if (search && search.trim() !== '') {
    const q = search.trim();
    const searchFilter = {
      OR: [
        { userId: { equals: q } },
        { user: { username: { contains: q, mode: 'insensitive' } } },
        { user: { profile: { displayName: { contains: q, mode: 'insensitive' } } } },
      ],
    };
    if (hostIsOccupyingSeat) {
      where.AND = [
        { userId: { not: room.creatorUserId } },
        searchFilter,
      ];
      delete where.userId;
    } else {
      where.AND = [searchFilter];
    }
  }

  const members = await db.roomMember.findMany({
    where,
    orderBy: { joinedAt: 'asc' },
    include: {
      user: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          lastLoginAt: true,
          profile: {
            select: {
              displayName: true,
              level: true,
              vipLevel: true,
            },
          },
        },
      },
    },
  });

  const formatted = members
    .filter((m) => !(hostIsOccupyingSeat && m.userId === room.creatorUserId))
    .map((m) => {
      const isHost = m.userId === room.creatorUserId;
      let role = isHost ? 'HOST' : 'MEMBER';
      if (m.role === 'ADMIN') {
        role = 'ADMIN';
      }
      return {
        id: m.id,
        userId: m.userId,
        role,
        isHost,
        isOwner: isHost,
        joinedAt: m.joinedAt,
        user: {
          id: m.user.id,
          username: m.user.username,
          displayName: m.user.profile?.displayName || m.user.username,
          avatarUrl: m.user.avatarUrl || '',
          lastSeenAt: m.user.lastLoginAt,
        },
      };
    });

  const existingIds = new Set(formatted.map((m) => m.userId));

  // If host is NOT occupying a mic seat, show host in the audience exactly once
  if (!hostIsOccupyingSeat && room.creatorUserId && !existingIds.has(room.creatorUserId)) {
    try {
      const creatorUser = await db.user.findUnique({
        where: { id: room.creatorUserId },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          lastLoginAt: true,
          profile: { select: { displayName: true } },
        },
      });
      if (creatorUser) {
        formatted.unshift({
          id: `host_member_${room.creatorUserId}`,
          userId: room.creatorUserId,
          role: 'HOST',
          isHost: true,
          isOwner: true,
          joinedAt: new Date().toISOString(),
          user: {
            id: creatorUser.id,
            username: creatorUser.username,
            displayName: creatorUser.profile?.displayName || creatorUser.username,
            avatarUrl: creatorUser.avatarUrl || '',
            lastSeenAt: creatorUser.lastLoginAt,
          },
        });
        existingIds.add(room.creatorUserId);
      }
    } catch (_) {}
  }

  const totalMembers = formatted.length;

  // Merge active guest participants from realtime presence
  try {
    const activePresence = await presenceService.getRoomActiveUsers(resolvedRoomId);
    for (const p of activePresence) {
      if (p.userId && !existingIds.has(p.userId)) {
        if (p.userId === room.creatorUserId && hostIsOccupyingSeat) continue;
        if (search && search.trim() !== '') {
          const q = search.trim().toLowerCase();
          const match = p.userId.toLowerCase().includes(q) || (p.displayName && p.displayName.toLowerCase().includes(q));
          if (!match) continue;
        }
        const guestName = p.displayName || `User_${String(p.userId).replace('guest_', '').substring(0, 5)}`;
        formatted.push({
          id: `guest_member_${p.userId}`,
          userId: p.userId,
          role: 'MEMBER',
          joinedAt: p.joinedAt || new Date().toISOString(),
          user: {
            id: p.userId,
            username: guestName,
            displayName: guestName,
            avatarUrl: p.avatarUrl || '',
            lastSeenAt: new Date().toISOString(),
          },
        });
        existingIds.add(p.userId);
      }
    }
  } catch (_) {}

  const decorated = await micInviteService.decorateMembersWithMicInviteStatus(resolvedRoomId, formatted, db);

  return {
    members: decorated,
    totalCount: decorated.length,
  };
}

export async function updateMemberRole(roomId, actorUserId, targetUserId, { role }, db = prisma) {
  const room = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, creatorUserId: true },
  });
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Permission check: actor must be creator or admin
  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  if (!isOwner) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId, userId: actorUserId } },
    });
    if (actorMember && actorMember.role === 'ADMIN') {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only the room owner or room admins can manage roles');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Cannot alter room owner
  if (targetUserId === room.creatorUserId) {
    const error = new Error('Cannot change or revoke the room owner role');
    error.statusCode = 400;
    error.code = 'OWNER_ROLE_IMMUTABLE';
    throw error;
  }

  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId, userId: targetUserId } },
  });
  if (!targetMember) {
    const error = new Error('User is not a member of this room');
    error.statusCode = 404;
    error.code = 'MEMBER_NOT_FOUND';
    throw error;
  }

  if (!isOwner && targetMember.role === 'ADMIN' && role !== 'ADMIN') {
    const error = new Error('Admins cannot revoke other admins; only the room owner can');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const updatedRole = role === 'ADMIN' ? 'ADMIN' : 'MEMBER';
  const updatedMember = await db.roomMember.update({
    where: { roomId_userId: { roomId, userId: targetUserId } },
    data: { role: updatedRole },
    include: {
      user: {
        select: { id: true, username: true, avatarUrl: true, profile: true },
      },
    },
  });

  try {
    socketEmitter.emitToRoom(roomId, 'room:role_updated', {
      roomId,
      targetUserId,
      role: updatedRole,
    });
  } catch (err) {
    console.error('Failed to emit room:role_updated event:', err);
  }

  return updatedMember;
}

export async function getRoomSendingRankings(roomId, { period = 'daily', currentUserId } = {}, db = prisma) {
  let canonicalRoomId = roomId;
  let room = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, creatorUserId: true },
  });
  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      select: { id: true, creatorUserId: true },
    });
  }
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }
  canonicalRoomId = room.id;

  const startDate = new Date();

  if (period === 'daily') {
    startDate.setUTCHours(0, 0, 0, 0);
  } else if (period === 'weekly') {
    const day = startDate.getUTCDay();
    const diff = startDate.getUTCDate() - day + (day === 0 ? -6 : 1);
    startDate.setUTCDate(diff);
    startDate.setUTCHours(0, 0, 0, 0);
  } else if (period === 'monthly') {
    startDate.setUTCDate(1);
    startDate.setUTCHours(0, 0, 0, 0);
  }

  const txs = await db.giftTransaction.groupBy({
    by: ['senderUserId'],
    where: {
      roomId: canonicalRoomId,
      createdAt: { gte: startDate },
    },
    _sum: {
      totalCoins: true,
    },
    orderBy: {
      _sum: {
        totalCoins: 'desc',
      },
    },
  });

  const periodTotalResult = await db.giftTransaction.aggregate({
    where: { roomId: canonicalRoomId, createdAt: { gte: startDate } },
    _sum: { totalCoins: true },
  });
  const periodTotalCoins = Number(periodTotalResult._sum.totalCoins || 0);

  const overallTotalResult = await db.giftTransaction.aggregate({
    where: { roomId: canonicalRoomId },
    _sum: { totalCoins: true },
  });
  const overallTotalCoins = Number(overallTotalResult._sum.totalCoins || 0);

  const senderUserIds = txs.map((t) => t.senderUserId);
  const senders = await db.user.findMany({
    where: { id: { in: senderUserIds } },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      profile: {
        select: { displayName: true },
      },
    },
  });

  const senderMap = new Map(senders.map((s) => [s.id, s]));

  const rankings = txs.map((t, idx) => {
    const s = senderMap.get(t.senderUserId);
    return {
      rank: idx + 1,
      userId: t.senderUserId,
      name: s?.profile?.displayName || s?.username || 'User',
      username: s?.username || 'user',
      avatarUrl: s?.avatarUrl || '',
      totalCoins: Number(t._sum.totalCoins || 0),
    };
  });

  let viewerRank = null;
  if (currentUserId) {
    const userIndex = rankings.findIndex((r) => r.userId === currentUserId);
    if (userIndex !== -1) {
      viewerRank = rankings[userIndex];
    } else {
      const userTx = await db.giftTransaction.aggregate({
        where: { roomId: canonicalRoomId, senderUserId: currentUserId, createdAt: { gte: startDate } },
        _sum: { totalCoins: true },
      });
      const userCoins = Number(userTx._sum.totalCoins || 0);
      viewerRank = {
        rank: userCoins > 0 ? rankings.length + 1 : 0,
        userId: currentUserId,
        name: 'You',
        avatarUrl: '',
        totalCoins: userCoins,
      };
    }
  }

  return {
    period,
    periodTotalCoins,
    overallTotalCoins,
    roomSendingTotal: periodTotalCoins,
    dailySendingTotal: periodTotalCoins,
    trophyCoins: periodTotalCoins,
    rankings,
    viewerRank,
  };
}

/**
 * Module 02: Paid Room Theme / DP Upload (100,000 Coins)
 */
export async function uploadPaidRoomTheme({ roomId, userId, themeUrl, themeType = 'GALLERY_WALLPAPER' }, db = prisma) {
  const room = await db.room.findUnique({ where: { id: roomId } });
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    throw error;
  }

  const wallet = await db.wallet.findUnique({ where: { userId } });
  const requiredCoins = 100000;

  if (!wallet || BigInt(wallet.coinBalance) < BigInt(requiredCoins)) {
    const error = new Error('Insufficient Coins. 100,000 Coins required to upload custom wallpaper from gallery.');
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_COINS';
    error.requiredCoins = requiredCoins;
    error.currentBalance = wallet ? wallet.coinBalance.toString() : '0';
    throw error;
  }

  // Deduct 100,000 coins and apply theme
  const updated = await db.$transaction(async (tx) => {
    await tx.wallet.update({
      where: { userId },
      data: { coinBalance: { decrement: BigInt(requiredCoins) } },
    });

    const updatedRoom = await tx.room.update({
      where: { id: roomId },
      data: { coverImageUrl: themeUrl, backgroundImageUrl: themeUrl },
    });

    return updatedRoom;
  });

  try {
    const payload = {
      roomId,
      backgroundImageUrl: themeUrl,
      background: themeUrl,
      updatedBy: userId,
    };
    socketEmitter.emitToRoom(roomId, 'room:background_updated', payload);
    socketEmitter.emitToRoom(roomId, 'room_background_updated', payload);
  } catch (_) {}

  return {
    success: true,
    message: 'Room Theme uploaded and 100,000 Coins deducted successfully.',
    requiredCoins,
    themeUrl,
    room: updated,
  };
}

/**
 * Module 03: Room Mic Size Preset
 */
export async function updateRoomMicConfig(roomId, { micPreset = 'LARGE', actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    micPreset: micPreset.toUpperCase(),
    spacing: 'GENEROUS_CIRCULAR',
    profileSize: 'PROMINENT_LARGE',
  };
}

export async function getRoomMicConfig(roomId, db = prisma) {
  return {
    roomId,
    micPreset: 'LARGE',
    seatCount: 8,
    isLargeSeats: true,
  };
}

/**
 * Module 03: Room Entry Announcement
 */
export async function getRoomAnnouncement(roomId, db = prisma) {
  return {
    roomId,
    announcement: 'Welcome to ZeParty. Please respect each other and communicate in a friendly and appropriate manner.',
    isEnabled: true,
    attachedPosition: 'BELOW_MIC_SEATS',
  };
}

export async function updateRoomAnnouncement(roomId, { announcement, isEnabled = true, actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    announcement: announcement || 'Welcome to ZeParty. Please respect each other and communicate in a friendly and appropriate manner.',
    isEnabled: Boolean(isEnabled),
    attachedPosition: 'BELOW_MIC_SEATS',
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Module 06: Party Room Owner/Admin Controls (YouTube, Super Wheel, Lucky Bag, Lock Room)
 */
export async function controlRoomYouTube(roomId, { action, videoUrl, videoTitle, timestamp = 0, actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    sessionType: 'YOUTUBE_SYNC',
    action: action || 'START',
    videoUrl: videoUrl || 'https://youtube.com/watch?v=official_zeparty',
    videoTitle: videoTitle || 'ZeParty Official Audio',
    playbackState: { isPlaying: action !== 'PAUSE' && action !== 'STOP', timestamp },
  };
}

export async function controlSuperWheel(
  roomId,
  { action = 'LAUNCH', sessionId, entryCoinFee, stakeAmount, maxParticipants = 10, rewardCoins = 0, actorUserId },
  db = prisma
) {
  const upperAction = String(action || 'LAUNCH').toUpperCase();

  if (upperAction === 'LAUNCH' || upperAction === 'CREATE') {
    const fee = entryCoinFee !== undefined ? entryCoinFee : (stakeAmount || 0);
    const session = await wheelService.createWheelSession(
      roomId,
      {
        entryCoinFee: fee,
        maxParticipants,
        rewardCoins,
        actorUserId,
      },
      db
    );
    return {
      success: true,
      message: 'Super Wheel session launched',
      data: session,
    };
  }

  if (upperAction === 'JOIN') {
    return await wheelService.joinWheelSession({ sessionId, roomId, userId: actorUserId }, db);
  }

  if (upperAction === 'SPIN') {
    return await wheelService.spinWheelRound({ sessionId, roomId, actorUserId }, db);
  }

  if (upperAction === 'CANCEL') {
    return await wheelService.cancelWheelSession({ sessionId, roomId, actorUserId }, db);
  }

  const active = wheelService.getActiveWheelSession(roomId);
  return {
    success: true,
    data: active,
  };
}

export async function controlLuckyBag(
  roomId,
  {
    action = 'CREATE',
    bagId,
    mode = 'normal',
    totalCoins = 1000,
    claimCount,
    quantity,
    claimersLimit,
    taskType = 'none',
    countdownSeconds = 0,
    actorUserId,
  },
  db = prisma
) {
  const upperAction = String(action || 'CREATE').toUpperCase();

  if (upperAction === 'CREATE' || upperAction === 'DROP') {
    const bag = await luckyBagService.createLuckyBag(
      {
        roomId,
        mode,
        totalCoins,
        quantity: quantity || claimCount || claimersLimit || 10,
        taskType,
        countdownSeconds,
        creatorUserId: actorUserId,
      },
      db
    );
    return {
      success: true,
      message: 'Lucky Bag dropped successfully',
      data: bag,
    };
  }

  if (upperAction === 'CLAIM') {
    return await luckyBagService.claimLuckyBag(
      {
        bagId,
        roomId,
        claimantUserId: actorUserId,
      },
      db
    );
  }

  const bags = luckyBagService.getActiveLuckyBags(roomId);
  return {
    success: true,
    data: bags,
  };
}

export async function controlRoomLock(roomId, { isLocked = true, accessMode = 'PASSWORD', mode, pin, actorUserId }, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization check: Only Host/Creator or Moderator/Admin
  const isCreator = room.creatorUserId === actorUserId;
  let isAuthorized = isCreator;
  if (!isAuthorized && actorUserId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: room.id,
        userId: actorUserId,
        role: { in: ['OWNER', 'CO_HOST', 'ADMIN', 'MODERATOR'] },
      },
    });
    if (member) isAuthorized = true;
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or moderator can configure room lock settings');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const effectiveLockMode = (mode || accessMode || 'PIN').toUpperCase();
  const locked = Boolean(isLocked);
  let hashedPin = null;

  if (locked) {
    if (effectiveLockMode === 'PIN' || effectiveLockMode === 'PASSWORD') {
      const pinStr = String(pin !== undefined && pin !== null ? pin : '1234').trim();
      if (!/^\d{4,8}$/.test(pinStr)) {
        const error = new Error('PIN must be between 4 and 8 digits');
        error.statusCode = 400;
        error.code = 'INVALID_PIN_FORMAT';
        throw error;
      }
      hashedPin = await bcrypt.hash(pinStr, 10);
    }
  }

  await roomRepository.updateRoomLockSettings({
    roomId: room.id,
    isLocked: locked,
    roomPin: hashedPin,
  }, db);

  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    isLocked: locked,
    lockMode: locked ? (effectiveLockMode.includes('APPROVAL') ? 'Approval' : 'PIN') : 'NONE',
    hasPin: Boolean(hashedPin),
    updatedAt: new Date().toISOString(),
  };

  // Broadcast lock state to room participants
  try {
    socketEmitter.emitToRoom(room.id, 'room:lock_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:lock_status', payload);
    socketEmitter.emitToRoom(room.id, 'room:lock_settings', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:lock_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:lock_status', payload);
    }
  } catch (_) {}

  return {
    success: true,
    data: payload,
  };
}

export async function updateRoomProfile(roomId, userId, { title, coverImageUrl, coverUrl, category, roomType, backgroundImageUrl }, db = prisma) {
  let room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization: Only host or admin can update room profile
  const isCreator = room.creatorUserId === userId;
  let isAuthorized = isCreator;
  if (!isAuthorized && userId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: room.id,
        userId,
        role: { in: ['OWNER', 'CO_HOST', 'ADMIN', 'MODERATOR'] },
      },
    });
    if (member) isAuthorized = true;
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or moderator can update room information');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const finalCover = coverImageUrl !== undefined ? coverImageUrl : coverUrl;

  const updatedRoom = await roomRepository.updateRoomDetails({
    roomId: room.id,
    title,
    coverImageUrl: finalCover,
    category,
    roomType,
    backgroundImageUrl,
  }, db);

  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    title: updatedRoom.title,
    coverImageUrl: updatedRoom.coverImageUrl,
    coverUrl: updatedRoom.coverImageUrl,
    category: updatedRoom.category,
    roomType: updatedRoom.roomType,
    backgroundImageUrl: updatedRoom.backgroundImageUrl,
    updatedAt: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:details_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:profile_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_details', payload);
    socketEmitter.emitToRoom(room.id, 'room:details_update', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:details_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:profile_updated', payload);
    }
  } catch (_) {}

  return {
    success: true,
    data: payload,
  };
}

/**
 * Issue 11: Update Room Seat Count & Layout Mode
 */
export async function updateRoomLayout(roomId, userId, { capacity, seatCapacity, roomType }, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    include: { creator: true },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      include: { creator: true },
    });
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization check: Only Host/Creator or Moderator/Admin
  let isAuthorized = room.creatorUserId === userId;
  if (!isAuthorized && userId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: room.id,
        userId,
        role: { in: ['OWNER', 'CO_HOST', 'ADMIN', 'MODERATOR'] },
      },
    });
    if (member) isAuthorized = true;
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or moderator can update room layout');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const requestedCapacity = parseInt(capacity || seatCapacity, 10);
  if (!requestedCapacity || isNaN(requestedCapacity) || requestedCapacity < 8 || requestedCapacity > 50) {
    const error = new Error('Invalid seat capacity. Must be between 8 and 30');
    error.statusCode = 400;
    error.code = 'INVALID_SEAT_CAPACITY';
    throw error;
  }

  const updatedRoom = await roomRepository.updateRoomLayoutTx({
    roomId: room.id,
    capacity: requestedCapacity,
    roomType,
  }, db);

  const finalCapacity = (updatedRoom.seats || []).length;
  const payload = {
    roomId: room.id,
    clientRoomId: roomId,
    capacity: finalCapacity,
    seatCapacity: finalCapacity,
    roomType: updatedRoom.roomType,
    seats: (updatedRoom.seats || []).map((s) => {
      const u = s.occupiedUser || s.user;
      return {
        seatIndex: s.seatIndex,
        isLocked: s.isLocked,
        isMuted: s.isMuted,
        user: u ? {
          id: u.id,
          username: u.username,
          displayName: u.profile?.displayName || u.displayName || u.username,
          avatarUrl: u.profile?.avatarUrl || u.avatarUrl || null,
        } : null,
      };
    }),
    timestamp: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:layout_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_layout', payload);
    if (room.id !== roomId) {
      socketEmitter.emitToRoom(roomId, 'room:layout_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:update_layout', payload);
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Room layout updated successfully',
    data: payload,
  };
}

/**
 * Module 07: Room Mic Seat Management Action Sheet
 */
export async function lockRoomSeat(roomId, { seatIndex = 0, isLocked = true, actorUserId }, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Permission check: Host or Co-Host or Moderator
  const isCreator = room.creatorUserId === actorUserId;
  let isAuthorized = isCreator;
  if (!isAuthorized && actorUserId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: room.id,
        userId: actorUserId,
        role: { in: ['OWNER', 'CO_HOST', 'MODERATOR', 'ADMIN'] },
      },
    });
    if (member) isAuthorized = true;
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or moderator can lock or unlock microphone seats');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const sIndex = Number(seatIndex);
  if (isNaN(sIndex) || sIndex < 0 || sIndex > 30) {
    const error = new Error('Invalid seatIndex (must be 0-30)');
    error.statusCode = 400;
    error.code = 'INVALID_SEAT_INDEX';
    throw error;
  }

  const updatedSeat = await roomRepository.updateSeatLockStatus(
    { roomId: room.id, seatIndex: sIndex, isLocked: Boolean(isLocked) },
    db
  );

  const eventId = `evt-seat-lock-${room.id}-${sIndex}-${Date.now()}`;
  const payload = {
    id: eventId,
    eventId,
    roomId: room.id,
    clientRoomId: roomId,
    seatIndex: sIndex,
    isLocked: Boolean(isLocked),
    lockedByUserId: actorUserId,
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room channels
  socketEmitter.emitToRoom(room.id, 'room:seat_locked_status', payload);
  socketEmitter.emitToRoom(room.id, 'room:seat_locked', payload);
  socketEmitter.emitToRoom(room.id, 'room:lock_seat', payload);
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_UPDATED, payload);

  return {
    success: true,
    message: `Seat ${sIndex} ${isLocked ? 'locked' : 'unlocked'} successfully`,
    data: payload,
  };
}

export async function manageMicSeatAction(roomId, { seatIndex = 0, action = 'LOCK', isLocked, targetUserId, actorUserId }, db = prisma) {
  const upperAction = String(action || '').toUpperCase();
  if (['REMOVE_FROM_MIC', 'REMOVE_MIC', 'MUTE', 'UNMUTE', 'KICK'].includes(upperAction) && targetUserId) {
    return await moderateRoomUser(roomId, actorUserId, { targetUserId, action: upperAction }, db);
  }

  if (upperAction === 'LOCK' || upperAction === 'UNLOCK' || isLocked !== undefined) {
    const lockState = isLocked !== undefined ? Boolean(isLocked) : upperAction === 'LOCK';
    return await lockRoomSeat(roomId, { seatIndex, isLocked: lockState, actorUserId }, db);
  }

  return {
    success: true,
    roomId,
    seatIndex: Number(seatIndex),
    action: upperAction,
    targetUserId: targetUserId || null,
    actorUserId,
    newSeatState: {
      seatIndex: Number(seatIndex),
      isLocked: upperAction === 'LOCK',
      isMuted: upperAction === 'MUTE',
      occupiedBy: upperAction === 'TAKE' ? actorUserId : null,
    },
  };
}

/**
 * Module 08: Mic Reaction & Sticker Display Anchored to Seat
 */
export async function sendMicReaction(roomId, { seatIndex = 0, reactionId, reactionType = 'EMOJI', actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    senderUserId: actorUserId,
    seatIndex: Number(seatIndex),
    reactionId: reactionId || 'react_popular_01',
    reactionType,
    displayAnchor: 'OCCUPIED_MIC_TOP',
    durationSeconds: 3,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Module 31: Room Entry Name & Entrance Banner Position
 */
export async function getEntryBannerConfig(roomId, db = prisma) {
  return {
    roomId,
    position: 'BELOW_MIC_GRID',
    offsetBelowMicGridDp: 16,
    offsetAboveChatDp: 14,
    nonOverlapEnforced: true,
    queueMultipleEntries: true,
  };
}

/**
 * Module 02 / Issue 02: Room Background Management
 */
export async function updateRoomBackground(roomId, userId, { backgroundImageUrl, background }, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Ensure only the room creator/owner or system admin can modify the room background
  if (room.creatorUserId !== userId) {
    const error = new Error('Only the room owner can update the room background');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Accept backgroundImageUrl or fallback to background
  const rawBg = backgroundImageUrl !== undefined ? backgroundImageUrl : background;
  const targetBackground = rawBg ? String(rawBg).trim() : null;

  const updatedRoom = await roomRepository.updateRoomBackgroundTx(
    { roomId: room.id, backgroundImageUrl: targetBackground },
    db
  );

  const payload = {
    roomId: room.id,
    backgroundImageUrl: updatedRoom.backgroundImageUrl || null,
    background: updatedRoom.backgroundImageUrl || null,
    updatedBy: userId,
    timestamp: new Date().toISOString(),
  };

  try {
    socketEmitter.emitToRoom(room.id, 'room:background_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room_background_updated', payload);
    socketEmitter.emitToRoom(room.id, 'room:update_background', payload);
  } catch (_) {}

  return {
    success: true,
    message: targetBackground ? 'Room background updated successfully' : 'Room background removed successfully',
    roomId: room.id,
    backgroundImageUrl: updatedRoom.backgroundImageUrl || null,
    background: updatedRoom.backgroundImageUrl || null,
  };
}

export async function removeRoomBackground(roomId, userId, db = prisma) {
  return await updateRoomBackground(roomId, userId, { backgroundImageUrl: null }, db);
}

export async function getRoomBackground(roomId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

    return {
    success: true,
    roomId: room.id,
    backgroundImageUrl: room.backgroundImageUrl || null,
    background: room.backgroundImageUrl || null,
  };
}

/**
 * =========================================================================
 * Issue 04: Room User Moderation (Remove from Mic, Mute/Unmute, Kick from Room)
 * =========================================================================
 */

function formatRoomSnapshot(room, viewerCount) {
  if (!room) return null;
  const hostUserId = room.creatorUserId;
  const hostIsOccupyingSeat = (room.seats || []).some(
    (s) => s.occupiedUserId === hostUserId
  );

  const membersList = (room.members || [])
    .filter((m) => {
      const mid = m.userId || m.user?.id;
      if (mid === hostUserId && hostIsOccupyingSeat) return false;
      return true;
    })
    .map((m) => {
      const u = m.user || {};
      const mid = m.userId || u.id;
      const isHost = mid === hostUserId;
      const displayName = u.profile?.displayName || u.displayName || u.username || (isHost ? 'Host' : 'User');
      return {
        userId: mid,
        role: isHost ? 'HOST' : (m.role || 'LISTENER'),
        isHost,
        isOwner: isHost,
        user: {
          id: mid,
          username: u.username || displayName,
          displayName,
          name: displayName,
          avatarUrl: u.avatarUrl || u.profile?.avatarUrl || null,
        },
      };
    });

  const existingMemberIds = new Set(membersList.map((m) => m.userId));
  if (!hostIsOccupyingSeat && hostUserId && !existingMemberIds.has(hostUserId)) {
    const hostUser = room.creator || {};
    const hostDisplayName = hostUser.profile?.displayName || hostUser.displayName || hostUser.username || 'Host';
    membersList.unshift({
      userId: hostUserId,
      role: 'HOST',
      isHost: true,
      isOwner: true,
      user: {
        id: hostUserId,
        username: hostUser.username || hostDisplayName,
        displayName: hostDisplayName,
        name: hostDisplayName,
        avatarUrl: hostUser.avatarUrl || hostUser.profile?.avatarUrl || null,
      },
    });
  }

  const seatsList = (room.seats || []).map((s) => ({
    id: s.id,
    seatIndex: s.seatIndex,
    occupiedUserId: s.occupiedUserId,
    isMuted: Boolean(s.isMuted),
    isMutedByModerator: Boolean(s.isMutedByModerator),
    isLocked: Boolean(s.isLocked),
    user: s.occupiedUser ? {
      id: s.occupiedUser.id,
      username: s.occupiedUser.username,
      displayName: s.occupiedUser.profile?.displayName || s.occupiedUser.displayName || s.occupiedUser.username,
      avatarUrl: s.occupiedUser.avatarUrl || s.occupiedUser.profile?.avatarUrl || null,
    } : null,
  }));

  return {
    id: room.id,
    roomId: room.id,
    creatorUserId: hostUserId,
    seats: seatsList,
    members: membersList,
    viewerCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
  };
}

export async function validateModerationPermission(roomId, actorUserId, targetUserId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(room.status);
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  if (!isOwner) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
    });
    if (actorMember && (actorMember.role === 'ADMIN' || actorMember.role === 'HOST')) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only the room owner or authorized room admins can perform moderation actions');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Room admins and other users cannot moderate or kick the room owner
  if (targetUserId === room.creatorUserId) {
    const error = new Error('Cannot moderate or kick the room owner');
    error.statusCode = 403;
    error.code = 'CANNOT_MODERATE_OWNER';
    throw error;
  }

  // Verify target is actually in this room
  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId: room.id, userId: targetUserId } },
  });
  const occupiedSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.occupiedUserId === targetUserId) : null;

  if (!targetMember && !occupiedSeat) {
    const error = new Error('Selected user is not currently in this room');
    error.statusCode = 404;
    error.code = 'TARGET_NOT_IN_ROOM';
    throw error;
  }

  return { room, isOwner, isAdmin, targetMember, occupiedSeat };
}

export async function removeRoomUserFromMic(roomId, actorUserId, { targetUserId, reason }, db = prisma) {
  const { room, occupiedSeat, targetMember } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);

  if (!occupiedSeat) {
    const error = new Error('Selected user does not occupy a microphone seat');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_MIC';
    throw error;
  }

  // Atomically release the seat
  await db.roomSeat.update({
    where: { id: occupiedSeat.id },
    data: {
      occupiedUserId: null,
      isMuted: false,
      isMutedByModerator: false,
    },
  });

  // Ensure target user remains in the audience as listener
  if (!targetMember) {
    try {
      await db.roomMember.create({
        data: {
          roomId: room.id,
          userId: targetUserId,
          role: 'MEMBER',
        },
      });
    } catch (_) {}
  }

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const seatPayload = {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    releasedByUserId: actorUserId,
    targetUserId,
    isModerationAction: true,
    action: 'REMOVE_FROM_MIC',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  const notificationPayload = {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    removedByUserId: actorUserId,
    targetUserId,
    reason: reason || 'Removed from microphone seat by room moderator',
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:seat_released', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });

  // Direct target notification
  socketEmitter.emitToUser(targetUserId, 'room:removed_from_mic', notificationPayload);
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatPayload);
  socketEmitter.emitToUser(targetUserId, 'room:seat_released', seatPayload);

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: 'REMOVE_FROM_MIC',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat.id,
      reason: `Participant ${targetUserId} removed from mic seat ${occupiedSeat.seatIndex} by moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: 'User removed from mic successfully',
    data: {
      roomId: room.id,
      targetUserId,
      seatIndex: occupiedSeat.seatIndex,
      seats: snapshot.seats,
      members: snapshot.members,
    },
  };
}

export async function moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted = true, reason }, db = prisma) {
  const { room, occupiedSeat } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);
  const shouldMute = Boolean(isMuted);

  if (shouldMute) {
    const existing = await db.roomModeration.findFirst({
      where: {
        roomId: room.id,
        targetUserId,
        actionType: 'MUTE_MIC',
      },
    });
    if (!existing) {
      await db.roomModeration.create({
        data: {
          roomId: room.id,
          targetUserId,
          actionType: 'MUTE_MIC',
          reason: reason || 'Muted by room moderator',
        },
      });
    }
  } else {
    await db.roomModeration.deleteMany({
      where: {
        roomId: room.id,
        targetUserId,
        actionType: 'MUTE_MIC',
      },
    });
  }

  if (occupiedSeat) {
    await db.roomSeat.update({
      where: { id: occupiedSeat.id },
      data: {
        isMuted: shouldMute,
        isMutedByModerator: shouldMute,
      },
    });
  }

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const mutePayload = {
    roomId: room.id,
    targetUserId,
    seatIndex: occupiedSeat ? occupiedSeat.seatIndex : null,
    isMuted: shouldMute,
    isMutedByModerator: shouldMute,
    moderatedByUserId: actorUserId,
    seats: snapshot.seats,
    timestamp: new Date().toISOString(),
  };

  const eventName = shouldMute ? SOCKET_EVENTS.ROOM_USER_MUTED : 'room:user_unmuted';
  socketEmitter.emitToRoom(room.id, eventName, mutePayload);
  socketEmitter.emitToRoom(room.id, shouldMute ? 'room:user_muted' : 'room:user_unmuted', mutePayload);
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_UPDATED, mutePayload);
  socketEmitter.emitToRoom(room.id, 'room:seat_updated', mutePayload);

  socketEmitter.emitToUser(targetUserId, eventName, mutePayload);
  socketEmitter.emitToUser(targetUserId, shouldMute ? 'room:user_muted' : 'room:user_unmuted', mutePayload);
  socketEmitter.emitToUser(targetUserId, 'room:seat_updated', mutePayload);

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: shouldMute ? 'PARTICIPANT_MUTED' : 'PARTICIPANT_UNMUTED',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat?.id || room.id,
      reason: `Participant ${targetUserId} ${shouldMute ? 'muted' : 'unmuted'} by room moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: shouldMute ? 'User muted successfully' : 'User unmuted successfully',
    data: mutePayload,
  };
}

export async function kickRoomUser(roomId, actorUserId, { targetUserId, reason }, db = prisma) {
  const { room, occupiedSeat } = await validateModerationPermission(roomId, actorUserId, targetUserId, db);

  await db.$transaction(async (tx) => {
    // 1. Release any seat
    await tx.roomSeat.updateMany({
      where: { roomId: room.id, occupiedUserId: targetUserId },
      data: { occupiedUserId: null, isMuted: false, isMutedByModerator: false },
    });

    // 2. Remove room membership
    await tx.roomMember.deleteMany({
      where: { roomId: room.id, userId: targetUserId },
    });

    // 3. Decrement viewer count if > 0
    await tx.room.updateMany({
      where: { id: room.id, currentViewersCount: { gt: 0 } },
      data: { currentViewersCount: { decrement: 1 } },
    });

    // 4. Record session kick restriction
    await tx.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId,
        actionType: 'KICK',
        reason: reason || 'Kicked from room by moderator',
        expiresAt: new Date(Date.now() + 86400000),
      },
    });
  }, { maxWait: 15000, timeout: 20000 });

  try {
    await presenceService.leaveRoomPresence(room.id, targetUserId);
  } catch (_) {}

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const kickPayload = {
    roomId: room.id,
    targetUserId,
    kickedByUserId: actorUserId,
    reason: reason || 'You were kicked from this room by a room moderator',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToRoom(room.id, 'room:user_kicked', kickPayload);
  if (occupiedSeat) {
    const seatRelPayload = {
      roomId: room.id,
      seatIndex: occupiedSeat.seatIndex,
      releasedByUserId: actorUserId,
      targetUserId,
      seats: snapshot.seats,
    };
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatRelPayload);
    socketEmitter.emitToRoom(room.id, 'room:seat_released', seatRelPayload);
  }
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });
  socketEmitter.emitToRoom(room.id, 'room:viewer_count_changed', {
    roomId: room.id,
    viewerCount,
    count: viewerCount,
  });

  // Direct target notification
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_USER_KICKED, kickPayload);
  socketEmitter.emitToUser(targetUserId, 'room:user_kicked', kickPayload);

  await logAudit(
    {
      adminId: actorUserId,
      adminName: 'Room Moderator',
      action: 'PARTICIPANT_KICKED',
      targetEntity: 'Room',
      targetEntityId: room.id,
      reason: `Participant ${targetUserId} kicked from room by moderator: ${reason || 'Action'}`,
    },
    db
  );

  return {
    success: true,
    message: 'User kicked from room successfully',
    data: kickPayload,
  };
}

export async function moderateRoomUser(roomId, actorUserId, { targetUserId, action, isMuted, reason }, db = prisma) {
  const upperAction = String(action || '').toUpperCase();
  if (upperAction === 'REMOVE_FROM_MIC' || upperAction === 'REMOVE_MIC') {
    return await removeRoomUserFromMic(roomId, actorUserId, { targetUserId, reason }, db);
  }
  if (upperAction === 'MUTE') {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted: true, reason }, db);
  }
  if (upperAction === 'UNMUTE') {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted: false, reason }, db);
  }
  if (upperAction === 'KICK') {
    return await kickRoomUser(roomId, actorUserId, { targetUserId, reason }, db);
  }
  if (isMuted !== undefined) {
    return await moderateRoomUserMute(roomId, actorUserId, { targetUserId, isMuted, reason }, db);
  }

  const error = new Error('Invalid moderation action specified');
  error.statusCode = 400;
  error.code = 'INVALID_MODERATION_ACTION';
  throw error;
}

export async function adminRemoveFromMic(
  roomId,
  { targetUserId, reason, adminId, adminName, ipAddress },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const occupiedSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.occupiedUserId === targetUserId) : null;
  if (!occupiedSeat) {
    const error = new Error('Participant does not occupy a microphone seat');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_MIC';
    throw error;
  }

  await db.roomSeat.update({
    where: { id: occupiedSeat.id },
    data: {
      occupiedUserId: null,
      isMuted: false,
      isMutedByModerator: false,
    },
  });

  const updatedRoom = await roomRepository.findRoomById(room.id, db);
  let viewerCount = updatedRoom?.currentViewersCount || 0;
  try {
    const presCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    if (typeof presCount === 'number') viewerCount = presCount;
  } catch (_) {}

  const snapshot = formatRoomSnapshot(updatedRoom, viewerCount);

  const payload = {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    releasedByUserId: adminId || 'admin',
    targetUserId,
    isModerationAction: true,
    action: 'REMOVE_FROM_MIC',
    seats: snapshot.seats,
    members: snapshot.members,
    viewerCount,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);
  socketEmitter.emitToRoom(room.id, 'room:seat_released', payload);
  socketEmitter.emitToRoom(room.id, 'room:audience_updated', {
    roomId: room.id,
    members: snapshot.members,
    count: viewerCount,
  });

  socketEmitter.emitToUser(targetUserId, 'room:removed_from_mic', {
    roomId: room.id,
    seatIndex: occupiedSeat.seatIndex,
    removedByUserId: adminId || 'admin',
    reason: reason || 'Removed from mic by platform admin',
    timestamp: new Date().toISOString(),
  });
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);

  await logAudit(
    {
      adminId,
      adminName,
      action: 'REMOVE_FROM_MIC',
      targetEntity: 'RoomSeat',
      targetEntityId: occupiedSeat.id,
      reason: `Participant ${targetUserId} removed from mic seat by admin: ${reason || 'Admin action'}`,
      ipAddress,
    },
    db
  );

  return { success: true, message: 'Participant removed from mic successfully', data: payload };
}

export async function validateRoomAdminOrOwner(roomId, actorUserId, db = prisma) {
  if (!roomId || typeof roomId !== 'string') {
    const error = new Error('Valid roomId is required');
    error.statusCode = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }

  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  let actorMember = null;

  if (!isOwner) {
    actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
      include: {
        user: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });
    if (actorMember && (actorMember.role === 'ADMIN' || actorMember.role === 'HOST')) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only room owner or authorized room administrators can perform this action');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  return { room, isOwner, isAdmin, actorMember };
}

export async function clearRoomFeed(roomId, actorUserId, { reason } = {}, db = prisma) {
  const { room, isOwner, isAdmin, actorMember } = await validateRoomAdminOrOwner(roomId, actorUserId, db);

  const clearedAt = new Date().toISOString();

  // Authoritatively record in presence service for stale message filtering on snapshot/reconnect
  try {
    await presenceService.setRoomFeedClearedAt(room.id, clearedAt);
    if (roomId !== room.id) {
      await presenceService.setRoomFeedClearedAt(roomId, clearedAt);
    }
  } catch (presErr) {
    console.warn('[RoomService] Error updating presence feedClearedAt:', presErr.message);
  }

  // Non-destructive room moderation audit log (reusing RoomModeration model)
  try {
    await db.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId: actorUserId,
        actionType: 'DELETE_CONTENT',
        reason: reason || 'Room feed cleared by room owner/admin',
      },
    });
  } catch (auditErr) {
    console.warn('[RoomService] Non-blocking room moderation audit log notice:', auditErr.message);
  }

  const actorDisplayName = isOwner
    ? (room.creator?.profile?.displayName || room.creator?.username || 'Room Owner')
    : (actorMember?.user?.profile?.displayName || actorMember?.user?.username || 'Room Admin');

  const clearPayload = {
    roomId: room.id,
    clientRoomId: roomId,
    room: room.id,
    clearedAt,
    timestamp: clearedAt,
    clearedBy: actorUserId,
    actorUserId,
    actor: {
      id: actorUserId,
      name: actorDisplayName,
      displayName: actorDisplayName,
      role: isOwner ? 'OWNER' : 'ADMIN',
    },
    reason: reason || 'Room feed cleared',
    isCleared: true,
  };

  // Broadcast realtime feed cleared events to all connected room participants
  try {
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.PARTY_CLEAR_SCREEN, clearPayload);
    socketEmitter.emitToRoom(room.id, 'room:feed_cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'party:clear_screen', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed:cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed_cleared', clearPayload);

    if (roomId !== room.id) {
      socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
      socketEmitter.emitToRoom(roomId, 'room:feed_cleared', clearPayload);
      socketEmitter.emitToRoom(roomId, 'party:clear_screen', clearPayload);
    }
  } catch (emitErr) {
    console.warn('[RoomService] Error emitting feed cleared socket event:', emitErr.message);
  }

  return {
    success: true,
    message: 'Room feed cleared successfully',
    roomId: room.id,
    clearedAt,
    clearedBy: actorUserId,
    data: clearPayload,
    ...clearPayload,
  };
}

export async function adminClearRoomFeed(roomId, adminId, { reason } = {}, db = prisma) {
  if (!roomId || typeof roomId !== 'string') {
    const error = new Error('Valid roomId is required');
    error.statusCode = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }

  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomOpen = ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
  if (!isRoomOpen) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  const clearedAt = new Date().toISOString();

  try {
    await presenceService.setRoomFeedClearedAt(room.id, clearedAt);
    if (roomId !== room.id) {
      await presenceService.setRoomFeedClearedAt(roomId, clearedAt);
    }
  } catch (_) {}

  try {
    await db.roomModeration.create({
      data: {
        roomId: room.id,
        targetUserId: adminId,
        actionType: 'DELETE_CONTENT',
        reason: reason || 'Room feed cleared by platform administrator',
      },
    });
  } catch (_) {}

  const clearPayload = {
    roomId: room.id,
    clientRoomId: roomId,
    room: room.id,
    clearedAt,
    timestamp: clearedAt,
    clearedBy: adminId,
    actorUserId: adminId,
    actor: {
      id: adminId,
      name: 'Platform Administrator',
      displayName: 'Platform Administrator',
      role: 'PLATFORM_ADMIN',
    },
    reason: reason || 'Feed cleared by platform administration',
    isCleared: true,
  };

  try {
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
    socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.PARTY_CLEAR_SCREEN, clearPayload);
    socketEmitter.emitToRoom(room.id, 'room:feed_cleared', clearPayload);
    socketEmitter.emitToRoom(room.id, 'party:clear_screen', clearPayload);
    socketEmitter.emitToRoom(room.id, 'feed:cleared', clearPayload);

    if (roomId !== room.id) {
      socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_FEED_CLEARED, clearPayload);
      socketEmitter.emitToRoom(roomId, 'room:feed_cleared', clearPayload);
      socketEmitter.emitToRoom(roomId, 'party:clear_screen', clearPayload);
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Room feed cleared by platform administrator',
    roomId: room.id,
    clearedAt,
    clearedBy: adminId,
    data: clearPayload,
    ...clearPayload,
  };
}

export default {
  createRoom,
  getActiveRooms,
  cleanupStaleRooms,
  getRoomDetails,
  joinRoom,
  leaveRoom,
  occupySeat,
  leaveSeat,
  closeMyRoom,
  listRoomsForAdmin,
  adminPinRoom,
  adminUnpinRoom,
  adminGetPinnedPositions,
  adminCloseRoom,
  adminIssueWarning,
  adminToggleRoomMute,
  adminMuteParticipant,
  adminKickUser,
  adminRemoveFromMic,
  adminUpdateRoomDp,
  getRoomMembers,
  updateMemberRole,
  getRoomSendingRankings,
  uploadPaidRoomTheme,
  updateRoomBackground,
  removeRoomBackground,
  getRoomBackground,
  updateRoomMicConfig,
  getRoomMicConfig,
  getRoomAnnouncement,
  updateRoomAnnouncement,
  controlRoomYouTube,
  controlSuperWheel,
  controlLuckyBag,
  controlRoomLock,
  updateRoomProfile,
  updateRoomLayout,
  manageMicSeatAction,
  lockRoomSeat,
  sendMicReaction,
  getEntryBannerConfig,
  validateModerationPermission,
  removeRoomUserFromMic,
  moderateRoomUserMute,
  kickRoomUser,
  moderateRoomUser,
  validateRoomAdminOrOwner,
  clearRoomFeed,
  adminClearRoomFeed,
  createMicInvite: micInviteService.createMicInvite,
  acceptMicInvite: micInviteService.acceptMicInvite,
  declineMicInvite: micInviteService.declineMicInvite,
  cancelMicInvite: micInviteService.cancelMicInvite,
  getActiveInviteForUser: micInviteService.getActiveInviteForUser,
};
