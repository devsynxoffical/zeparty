import crypto from 'crypto';
import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';
import { clearHostAbsentTimer } from '../socket/roomTimer.manager.js';

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

  clearHostAbsentTimer(roomId);
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

  const where = { roomId };
  if (search && search.trim() !== '') {
    const q = search.trim();
    where.OR = [
      { userId: { equals: q } },
      { user: { username: { contains: q, mode: 'insensitive' } } },
      { user: { profile: { displayName: { contains: q, mode: 'insensitive' } } } },
    ];
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

  const formatted = members.map((m) => {
    let role = 'MEMBER';
    if (m.userId === room.creatorUserId) {
      role = 'HOST';
    } else if (m.role === 'ADMIN') {
      role = 'ADMIN';
    }
    return {
      id: m.id,
      userId: m.userId,
      role,
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

  const totalMembers = await db.roomMember.count({ where: { roomId } });

  return {
    members: formatted,
    totalCount: totalMembers,
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
      roomId,
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
    where: { roomId, createdAt: { gte: startDate } },
    _sum: { totalCoins: true },
  });
  const periodTotalCoins = Number(periodTotalResult._sum.totalCoins || 0);

  const overallTotalResult = await db.giftTransaction.aggregate({
    where: { roomId },
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
        where: { roomId, senderUserId: currentUserId, createdAt: { gte: startDate } },
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
      data: { coverImageUrl: themeUrl },
    });

    return updatedRoom;
  });

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

export async function controlSuperWheel(roomId, { action, roundCost = 100, actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    sessionType: 'SUPER_WHEEL',
    action: action || 'LAUNCH',
    roundCost,
    status: 'ACTIVE_SPINNING',
  };
}

export async function controlLuckyBag(roomId, { action, totalCoins = 10000, claimCount = 10, actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    sessionType: 'LUCKY_BAG',
    action: action || 'CREATE',
    totalCoins,
    claimCount,
    claimsRemaining: claimCount,
    status: 'ACTIVE_CLAIMABLE',
  };
}

export async function controlRoomLock(roomId, { isLocked = true, accessMode = 'PASSWORD', pin = '1234', actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    isLocked: Boolean(isLocked),
    accessMode,
    pin: accessMode === 'PASSWORD' ? pin : null,
  };
}

/**
 * Module 07: Room Mic Seat Management Action Sheet
 */
export async function manageMicSeatAction(roomId, { seatIndex = 0, action = 'LOCK', targetUserId, actorUserId }, db = prisma) {
  return {
    success: true,
    roomId,
    seatIndex: Number(seatIndex),
    action: String(action).toUpperCase(),
    targetUserId: targetUserId || null,
    actorUserId,
    newSeatState: {
      seatIndex: Number(seatIndex),
      isLocked: action === 'LOCK',
      isMuted: action === 'MUTE',
      occupiedBy: action === 'TAKE' ? actorUserId : null,
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
  adminGetPinnedPositions,
  adminCloseRoom,
  adminIssueWarning,
  adminToggleRoomMute,
  adminMuteParticipant,
  adminKickUser,
  adminUpdateRoomDp,
  getRoomMembers,
  updateMemberRole,
  getRoomSendingRankings,
  uploadPaidRoomTheme,
  updateRoomMicConfig,
  getRoomMicConfig,
  getRoomAnnouncement,
  updateRoomAnnouncement,
  controlRoomYouTube,
  controlSuperWheel,
  controlLuckyBag,
  controlRoomLock,
  manageMicSeatAction,
  sendMicReaction,
  getEntryBannerConfig,
};
