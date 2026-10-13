import roomService from '../services/room.service.js';
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

    // Delegate to authoritative room service for atomic occupancy and concurrency locking
    const result = await roomService.occupySeat(roomId, seatIndex, userId, db);
    const updatedSeat = result?.updatedSeat || result;
    const vacatedSeatIndex = result?.vacatedSeatIndex;

    // If moving from a previous seat, broadcast seat release for old seat first
    if (typeof vacatedSeatIndex === 'number' && vacatedSeatIndex !== seatIndex) {
      const releasePayload = {
        roomId,
        seatIndex: vacatedSeatIndex,
        releasedByUserId: userId,
      };
      const broadcastTarget = io && io.to ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
      broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, releasePayload);
      broadcastTarget.emit('room:seat_released', releasePayload);
      broadcastTarget.emit('seat_released', releasePayload);
      broadcastTarget.emit('seat:released', releasePayload);
    }

    const effectiveName = clientUser.displayName || clientUser.name || clientUser.username || socket.user?.displayName || socket.user?.name || socket.user?.username || 'Speaker';
    const effectiveAvatar = clientUser.avatarUrl || socket.user?.avatarUrl || null;
    const effectiveNoble = clientUser.nobleTitle || socket.user?.nobleTitle || null;
    const effectiveVip = Boolean(clientUser.isVip || socket.user?.isVip);

    const payload = {
      roomId,
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

    // Broadcast authoritative seat occupied event to the entire room
    const broadcastTarget = io && io.to ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_OCCUPIED, payload);
    broadcastTarget.emit('room:seat_occupied', payload);
    broadcastTarget.emit('seat_occupied', payload);

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

export async function onLeaveSeat(io, socket, data, callback, db) {
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

    const userId = socket.userId;
    const isAdmin = socket.user?.isAdmin || socket.user?.isOwner || false;

    // Delegate to authoritative room service for seat release authorization
    const releasedSeat = await roomService.leaveSeat(roomId, seatIndex, userId, isAdmin, db);

    const payload = {
      roomId,
      seatIndex: releasedSeat.seatIndex,
      releasedByUserId: userId,
    };

    // Broadcast authoritative seat released event to the entire room
    const broadcastTarget = io && io.to ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_SEAT_RELEASED, payload);
    broadcastTarget.emit('room:seat_released', payload);
    broadcastTarget.emit('seat_released', payload);
    broadcastTarget.emit('seat:released', payload);

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
}

export default {
  onOccupySeat,
  onLeaveSeat,
  registerSeatHandlers,
};
