import roomService from '../services/room.service.js';
import roomRepository from '../repositories/room.repository.js';
import presenceService from './presence.service.js';
import { buildRoomSnapshot } from './room.socket.js';
import prisma from '../config/database.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';

export async function onOccupySeat(io, socket, data, callback, db) {
  try {
    const roomId = data?.roomId;
    const seatIndex = Number(data?.seatIndex);

    if (!roomId || isNaN(seatIndex) || seatIndex < 0 || seatIndex > 30) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.INVALID_SEAT_INDEX, message: 'Valid roomId and seatIndex (0-30) are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const clientUser = data?.user || {};
    const userId = clientUser.id || clientUser.userId || socket.user?.id || socket.userId;

    // Resolve canonical room ID if short ID or alias was passed
    let canonicalRoomId = roomId;
    try {
      const roomRec = await (db || prisma).room.findUnique({ where: { id: roomId }, select: { id: true } });
      if (roomRec) {
        canonicalRoomId = roomRec.id;
      } else if (roomId.length <= 16) {
        const found = await (db || prisma).room.findFirst({
          where: { id: { startsWith: roomId, mode: 'insensitive' } },
          select: { id: true },
        });
        if (found) canonicalRoomId = found.id;
      }
    } catch (_) {}

    // Delegate to authoritative room service for atomic occupancy and concurrency locking
    const result = await roomService.occupySeat(roomId, seatIndex, userId, db);
    const updatedSeat = result?.updatedSeat || result;
    const vacatedSeatIndex = result?.vacatedSeatIndex;

    const effectiveName = clientUser.displayName || clientUser.name || clientUser.username || socket.user?.displayName || socket.user?.name || socket.user?.username || 'Speaker';
    const effectiveAvatar = clientUser.avatarUrl || socket.user?.avatarUrl || null;
    const effectiveNoble = clientUser.nobleTitle || socket.user?.nobleTitle || null;
    const effectiveVip = Boolean(clientUser.isVip || socket.user?.isVip);

    const eventId = `seat_occ_${canonicalRoomId}_${updatedSeat.seatIndex}_${userId}_${Date.now()}`;
    const payload = {
      id: eventId,
      eventId,
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      room: canonicalRoomId,
      seatIndex: updatedSeat.seatIndex,
      vacatedSeatIndex: typeof vacatedSeatIndex === 'number' ? vacatedSeatIndex : null,
      user: {
        id: userId,
        userId: userId,
        username: clientUser.username || socket.user?.username || effectiveName,
        displayName: effectiveName,
        name: effectiveName,
        avatarUrl: effectiveAvatar,
        nobleTitle: effectiveNoble,
        isVip: effectiveVip,
      },
    };

    // If user is ALREADY on this seat (idempotent tap / retry), return early to caller without re-broadcasting duplicate notifications
    if (result?.isNoop) {
      if (typeof callback === 'function') {
        return callback({
          success: true,
          message: `Already occupying seat ${seatIndex}`,
          data: payload,
        });
      }
      return;
    }

    const targetRoomIds = Array.from(new Set([String(roomId), String(canonicalRoomId)]));

    // If moving from a previous seat, broadcast seat release for old seat first
    if (typeof vacatedSeatIndex === 'number' && vacatedSeatIndex !== seatIndex) {
      const releaseEventId = `seat_rel_${canonicalRoomId}_${vacatedSeatIndex}_${userId}_${Date.now()}`;
      const releasePayload = {
        id: releaseEventId,
        eventId: releaseEventId,
        roomId: canonicalRoomId,
        clientRoomId: roomId,
        seatIndex: vacatedSeatIndex,
        releasedByUserId: userId,
      };
      for (const rid of targetRoomIds) {
        const broadcastTarget = io && io.to ? io.to(`room:${rid}`) : (socket.to ? socket.to(`room:${rid}`) : socket);
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, releasePayload);
        broadcastTarget.emit('seat_released', releasePayload);
        broadcastTarget.emit('seat:released', releasePayload);
      }
    }

    // Broadcast authoritative seat occupied event to the entire room
    for (const rid of targetRoomIds) {
      const broadcastTarget = io && io.to ? io.to(`room:${rid}`) : (socket.to ? socket.to(`room:${rid}`) : socket);
      broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_OCCUPIED, payload);
      broadcastTarget.emit('seat_occupied', payload);
      broadcastTarget.emit('seat:occupied', payload);
      broadcastTarget.emit('room_seat_occupied', payload);
    }

    if (typeof callback === 'function') {
      return callback({
        success: true,
        message: `Seat ${seatIndex} occupied successfully`,
        data: payload,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to occupy seat',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    if (socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
    }
  }
}

export async function onLeaveSeat(io, socket, data, callback, db = prisma) {
  try {
    const roomId = data?.roomId;
    let seatIndex = data?.seatIndex !== undefined && data?.seatIndex !== null ? Number(data.seatIndex) : NaN;
    const userId = socket.userId;
    const isAdmin = socket.user?.isAdmin || socket.user?.isOwner || false;

    if (!roomId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.INVALID_ROOM_ID, message: 'Valid roomId is required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Auto-resolve seatIndex if omitted or invalid by finding which seat the user occupies in this room
    let resolvedRoomId = roomId;
    let room = await (db || prisma).room.findUnique({ where: { id: roomId }, select: { id: true } });
    if (!room && roomId && roomId.length <= 16) {
      room = await (db || prisma).room.findFirst({
        where: { id: { startsWith: roomId, mode: 'insensitive' } },
        select: { id: true },
      });
    }
    if (room) {
      resolvedRoomId = room.id;
    }

    if (isNaN(seatIndex) || seatIndex < 0) {
      const occupiedSeat = await (db || prisma).roomSeat.findFirst({
        where: {
          roomId: resolvedRoomId,
          occupiedUserId: userId,
        },
      });

      if (occupiedSeat) {
        seatIndex = occupiedSeat.seatIndex;
      }
    }

    if (isNaN(seatIndex) || seatIndex < 0 || seatIndex > 30) {
      // User was not occupying any seat, return clean success without error
      const noopPayload = {
        roomId: resolvedRoomId,
        clientRoomId: roomId,
        seatIndex: null,
        releasedByUserId: userId,
        message: 'User is not currently occupying any microphone seat',
      };
      if (typeof callback === 'function') return callback({ success: true, data: noopPayload });
      return;
    }

    // Delegate to authoritative room service for seat release authorization
    const releasedSeat = await roomService.leaveSeat(roomId, seatIndex, userId, isAdmin, db);

    if (releasedSeat?.isNoop) {
      const alreadyEmptyPayload = {
        roomId: resolvedRoomId,
        clientRoomId: roomId,
        seatIndex,
        releasedByUserId: userId,
        message: 'Seat already empty',
      };
      if (typeof callback === 'function') return callback({ success: true, data: alreadyEmptyPayload });
      return;
    }

    // Fetch refreshed room snapshot so seats and audience members list are fully up to date
    let updatedSnapshot = null;
    let viewerCount = 0;
    try {
      const updatedRoom = await roomRepository.findRoomById(roomId, db || prisma);
      if (updatedRoom) {
        viewerCount = await presenceService.getRoomViewerCount(updatedRoom.id, updatedRoom.creatorUserId);
        const activeUsers = await presenceService.getRoomActiveUsers(updatedRoom.id);
        updatedSnapshot = buildRoomSnapshot(updatedRoom, viewerCount, activeUsers);
      }
    } catch (_) {}

    const isRoomOwner = updatedSnapshot ? (updatedSnapshot.creatorUserId === userId) : false;
    const leaveEventId = `seat_rel_${resolvedRoomId}_${releasedSeat.seatIndex}_${userId}_${Date.now()}`;

    const payload = {
      id: leaveEventId,
      eventId: leaveEventId,
      roomId: updatedSnapshot ? updatedSnapshot.id : resolvedRoomId,
      clientRoomId: roomId,
      seatIndex: releasedSeat.seatIndex,
      releasedByUserId: userId,
      userId,
      isOwner: isRoomOwner,
      isHost: isRoomOwner,
      seats: updatedSnapshot ? updatedSnapshot.seats : [],
      members: updatedSnapshot ? updatedSnapshot.members : [],
      viewerCount: typeof viewerCount === 'number' ? viewerCount : (updatedSnapshot?.viewerCount || 0),
      currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (updatedSnapshot?.currentViewersCount || 0),
    };

    const targetRoomIds = Array.from(new Set([String(roomId), String(resolvedRoomId)]));

    // Broadcast authoritative seat released event to the entire room
    for (const rid of targetRoomIds) {
      const broadcastTarget = io && io.to ? io.to(`room:${rid}`) : (socket.to ? socket.to(`room:${rid}`) : socket);
      broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);
      broadcastTarget.emit('seat_released', payload);
      broadcastTarget.emit('seat:released', payload);
      broadcastTarget.emit('room_seat_released', payload);
      broadcastTarget.emit('room:mic_left', payload);
      broadcastTarget.emit('mic:left', payload);
      broadcastTarget.emit('mic_left', payload);
      broadcastTarget.emit('room:leave_mic_success', payload);

      if (updatedSnapshot?.members) {
        broadcastTarget.emit('room:audience_updated', {
          roomId: payload.roomId,
          clientRoomId: roomId,
          members: updatedSnapshot.members,
          count: payload.viewerCount,
        });
        broadcastTarget.emit('room:member_list', {
          roomId: payload.roomId,
          clientRoomId: roomId,
          members: updatedSnapshot.members,
        });
      }
    }

    if (typeof callback === 'function') {
      return callback({
        success: true,
        message: `Seat ${seatIndex} released successfully`,
        data: payload,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to release seat',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    if (socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
    }
  }
}

export function registerSeatHandlers(io, socket) {
  socket.on(
    SOCKET_EVENTS.ROOM_SEAT_OCCUPY,
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onOccupySeat(io, s, d, cb))
  );
  socket.on(
    'room_seat_occupy',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onOccupySeat(io, s, d, cb))
  );
  socket.on(
    'seat_occupy',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onOccupySeat(io, s, d, cb))
  );
  socket.on(
    'seat:occupy',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onOccupySeat(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_SEAT_LEAVE,
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'room_seat_leave',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'seat_leave',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'seat:leave',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );

  // Leave mic aliases for mobile client
  socket.on(
    'room:leave_mic',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'leave_mic',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'room_leave_mic',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'seat:leave_mic',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'seat_leave_mic',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'mic:leave',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );
  socket.on(
    'mic_leave',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLeaveSeat(io, s, d, cb))
  );

  // Issue 04: Mic Seat Locking Socket Events
  socket.on(
    'room:lock_seat',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, { ...d, isLocked: true }, cb))
  );
  socket.on(
    'room_lock_seat',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, { ...d, isLocked: true }, cb))
  );
  socket.on(
    'room:unlock_seat',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, { ...d, isLocked: false }, cb))
  );
  socket.on(
    'room_unlock_seat',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, { ...d, isLocked: false }, cb))
  );
  socket.on(
    'room:seat_lock',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, d, cb))
  );
  socket.on(
    'room:seat_locked_status',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, d, cb))
  );
  socket.on(
    'room_seat_locked_status',
    withRateLimit('SEAT_ACTION', 5, 1000, (s, d, cb) => onLockSeat(io, s, d, cb))
  );
}

export async function onLockSeat(io, socket, data, callback, db) {
  try {
    const roomId = data?.roomId;
    const seatIndex = Number(data?.seatIndex !== undefined ? data.seatIndex : data?.seatNumber);
    const isLocked = data?.isLocked !== undefined ? Boolean(data.isLocked) : true;

    if (!roomId || isNaN(seatIndex) || seatIndex < 0 || seatIndex > 30) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.INVALID_SEAT_INDEX, message: 'Valid roomId and seatIndex (0-30) are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const actorUserId = socket.user?.id || socket.userId || data?.userId || data?.actorUserId;

    // Resolve canonical room ID
    let canonicalRoomId = roomId;
    let room = null;
    try {
      room = await (db || prisma).room.findUnique({ where: { id: roomId } });
      if (room) {
        canonicalRoomId = room.id;
      } else if (roomId.length <= 16) {
        room = await (db || prisma).room.findFirst({
          where: { id: { startsWith: roomId, mode: 'insensitive' } },
        });
        if (room) canonicalRoomId = room.id;
      }
    } catch (_) {}

    if (!room) {
      const err = { success: false, error: { code: 'ROOM_NOT_FOUND', message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Permission check: Host or Co-Host/Moderator
    const isCreator = room.creatorUserId === actorUserId;
    const member = !isCreator && actorUserId ? await (db || prisma).roomMember.findFirst({
      where: { roomId: canonicalRoomId, userId: actorUserId, role: { in: ['OWNER', 'CO_HOST', 'MODERATOR', 'ADMIN'] } },
    }) : null;

    if (!isCreator && !member) {
      const err = {
        success: false,
        error: { code: 'FORBIDDEN', message: 'Only the room host or moderator can lock or unlock microphone seats' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    await roomRepository.updateSeatLockStatus({
      roomId: canonicalRoomId,
      seatIndex,
      isLocked,
    }, db || prisma);

    const eventId = `evt-seat-lock-${canonicalRoomId}-${seatIndex}-${Date.now()}`;
    const payload = {
      id: eventId,
      eventId,
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      seatIndex,
      isLocked: Boolean(isLocked),
      lockedByUserId: actorUserId,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = io.to(`room:${canonicalRoomId}`);
    if (canonicalRoomId !== roomId) {
      broadcastTarget.to(`room:${roomId}`);
    }

    // Multi-alias emission for Flutter compatibility
    broadcastTarget.emit('room:seat_locked_status', payload);
    broadcastTarget.emit('room:seat_locked', payload);
    broadcastTarget.emit('room:lock_seat', payload);
    broadcastTarget.emit('room_seat_locked_status', payload);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_UPDATED, payload);

    if (typeof callback === 'function') {
      return callback({
        success: true,
        message: `Seat ${seatIndex} ${isLocked ? 'locked' : 'unlocked'} successfully`,
        data: payload,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to update seat lock state',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    if (socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
    }
  }
}

export default {
  onOccupySeat,
  onLeaveSeat,
  onLockSeat,
  registerSeatHandlers,
};
