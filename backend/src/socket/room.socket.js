import roomRepository from '../repositories/room.repository.js';
import roomService from '../services/room.service.js';
import presenceService from './presence.service.js';
import { deriveAgoraUid } from '../utils/agoraToken.util.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';

/**
 * Builds a safe, public room snapshot containing no sensitive admin or private fields.
 */
export function buildRoomSnapshot(room, viewerCount) {
  if (!room) return null;

  const hostUserId = room.creatorUserId || room.creator?.id;

  return {
    roomId: room.id,
    title: room.title,
    roomType: room.roomType || 'VIDEO_PARTY',
    category: room.category || 'CHATTING',
    status: room.status,
    isPinned: Boolean(room.isPinned),
    pinPosition: room.pinPosition || null,
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : room.currentViewersCount || 0,
    agoraChannelName: room.agoraChannelName || null,
    agoraHostUid: hostUserId ? deriveAgoraUid(hostUserId) : null,
    host: room.creator ? {
      id: room.creator.id,
      username: room.creator.username,
      displayName: room.creator.profile?.displayName || room.creator.username,
      avatarUrl: room.creator.profile?.avatarUrl || null,
    } : null,
    seats: (room.seats || []).map((s) => ({
      seatIndex: s.seatIndex,
      isLocked: s.isLocked,
      isMuted: s.isMuted,
      user: s.user ? {
        id: s.user.id,
        username: s.user.username,
        displayName: s.user.profile?.displayName || s.user.username,
        avatarUrl: s.user.profile?.avatarUrl || null,
      } : null,
    })),
    createdAt: room.createdAt,
  };
}

function resolveArgs(arg1, arg2, arg3, arg4, arg5) {
  // Case A: (io, socket, data, callback, db)
  if (arg2 && (arg2.handshake || arg2.conn || arg2.client || typeof arg2.join === 'function' || arg2.userId || arg2.id)) {
    const io = arg1;
    const socket = arg2;
    const data = arg3;
    const callback = typeof arg4 === 'function' ? arg4 : (typeof arg5 === 'function' ? arg5 : null);
    const db = (arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : (arg5 || null);
    return { io, socket, data, callback, db };
  }

  // Case B: (socket, data, callback, db)
  const socket = arg1;
  const data = arg2;
  const callback = typeof arg3 === 'function' ? arg3 : (typeof arg4 === 'function' ? arg4 : null);
  const db = (arg3 && typeof arg3 === 'object' && typeof arg3 !== 'function') ? arg3 : ((arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : (arg5 || null));
  return { io: null, socket, data, callback, db };
}

export async function onJoinRoom(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);

  try {
    const roomId = data?.roomId;
    if (!roomId || typeof roomId !== 'string') {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const userId = socket.userId;

    // 1. Authoritative Room Existence and Lifecycle Check
    const room = await roomRepository.findRoomById(roomId, db);
    if (!room) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (room.status !== 'LIVE') {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_LIVE, message: `Room is not live (status: ${room.status})` } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // 2. Persistent RoomMember registration via authoritative Room Service
    const joinResult = await roomService.joinRoom(roomId, userId, db);

    // 3. Socket subscription to Room
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    // 4. Ephemeral Presence Tracking
    const { isFirstSocket } = await presenceService.addSocketToRoom(roomId, userId, socket.id);

    // 5. Generate and Send Authoritative Room Snapshot
    const currentCount = joinResult?.currentViewersCount || (room.currentViewersCount || room.viewerCount || 0) + 1;
    const snapshot = buildRoomSnapshot(room, currentCount);
    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, { room, seats: room.seats || [] });

    // 6. Broadcast user joined event to ALL room members (including host's own socket)
    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    const userPayload = {
      roomId,
      userId: socket.user?.id || userId,
      user: {
        id: socket.user?.id || userId,
        userId: socket.user?.id || userId,
        username: socket.user?.username || 'user',
        name: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
        displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
        avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
        isVip: Boolean(socket.user?.isVip),
        nobleLevel: socket.user?.nobleLevel || null,
        nobleTitle: socket.user?.nobleTitle || null,
      },
      viewerCount: currentCount,
      count: currentCount,
      currentViewersCount: currentCount,
    };

    broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
    broadcastTarget.emit('room:user_joined', userPayload);
    broadcastTarget.emit('user_joined', userPayload);
    broadcastTarget.emit('user:joined', userPayload);
    broadcastTarget.emit('room_user_joined', userPayload);

    const viewerPayload = {
      roomId,
      viewerCount: currentCount,
      count: currentCount,
      currentViewersCount: currentCount,
    };
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
    broadcastTarget.emit('room:viewer_count_changed', viewerPayload);
    broadcastTarget.emit('room:viewer_count', viewerPayload);
    broadcastTarget.emit('viewer_count_changed', viewerPayload);

    if (typeof callback === 'function') {
      return callback({
        success: true,
        data: snapshot,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to join room',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onLeaveRoom(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);

  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const userId = socket.userId;

    // 1. Remove socket from room
    if (typeof socket.leave === 'function') {
      socket.leave(`room:${roomId}`);
    }

    // 2. Remove socket from presence tracker
    let isLastSocket = true;
    try {
      const pres = await presenceService.removeSocketFromRoom(roomId, userId, socket.id);
      isLastSocket = pres?.isLastSocket ?? true;
    } catch {}

    let updatedViewerCount = 0;

    // 3. If this was the user's last remaining connection, execute persistent leave
    if (isLastSocket) {
      let leaveResult = null;
      try {
        leaveResult = await roomService.leaveRoom(roomId, userId, db);
        updatedViewerCount = leaveResult?.currentViewersCount || 0;
      } catch (leaveErr) {
        // Safe fallback
      }

      const isRoomEnded = leaveResult?.status === 'ENDED';
      const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);

      if (isRoomEnded) {
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_CLOSED, {
          roomId,
          status: 'ENDED',
          reason: 'HOST_LEFT',
        });
        if (io) {
          io.emit('room:closed', { roomId, status: 'ENDED' });
          io.emit('room:deleted', { roomId });
        }
      } else {
        const leftPayload = { roomId, userId };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, leftPayload);
        broadcastTarget.emit('room:user_left', leftPayload);
        broadcastTarget.emit('user_left', leftPayload);
        broadcastTarget.emit('user:left', leftPayload);

        const countPayload = {
          roomId,
          viewerCount: updatedViewerCount,
          count: updatedViewerCount,
          currentViewersCount: updatedViewerCount,
        };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, countPayload);
        broadcastTarget.emit('room:viewer_count_changed', countPayload);
        broadcastTarget.emit('room:viewer_count', countPayload);
        broadcastTarget.emit('viewer_count_changed', countPayload);
      }
    }

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'Left room successfully' });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to leave room',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onRequestSnapshot(socket, data, callback, db) {
  try {
    const roomId = data?.roomId;
    if (!roomId) {
      const err = { success: false, error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const room = await roomRepository.findRoomById(roomId, db);
    if (!room) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const snapshot = {
      room,
      host: room.creator || null,
      seats: room.seats || [],
      timestamp: new Date().toISOString(),
    };

    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, snapshot);

    if (typeof callback === 'function') {
      return callback({ success: true, data: snapshot });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to retrieve snapshot',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSocketDisconnect(io, socket) {
  const userId = socket.userId;
  if (!userId) return;

  // Inspect all rooms the socket was part of
  const rooms = Array.from(socket.rooms || []).filter((r) => r.startsWith('room:'));

  for (const r of rooms) {
    const roomId = r.replace('room:', '');
    try {
      const { isLastSocket } = await presenceService.removeSocketFromRoom(roomId, userId, socket.id);
      if (isLastSocket) {
        let updatedViewerCount = 0;
        let roomEnded = false;
        try {
          const leaveResult = await roomService.leaveRoom(roomId, userId);
          updatedViewerCount = leaveResult.currentViewersCount || 0;
          if (leaveResult.status === 'ENDED') {
            roomEnded = true;
          }
        } catch {}

        if (roomEnded) {
          if (io) {
            io.to(`room:${roomId}`).emit(SOCKET_EVENTS.ROOM_CLOSED, {
              roomId,
              status: 'ENDED',
              reason: 'HOST_DISCONNECTED',
            });
            io.emit('room:closed', { roomId, status: 'ENDED' });
            io.emit('room:deleted', { roomId });
          } else if (socket.to) {
            socket.to(`room:${roomId}`).emit(SOCKET_EVENTS.ROOM_CLOSED, {
              roomId,
              status: 'ENDED',
              reason: 'HOST_DISCONNECTED',
            });
          }
        } else {
          const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
          broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, {
            roomId,
            userId,
          });

          broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, {
            roomId,
            viewerCount: updatedViewerCount,
          });
        }
      }
    } catch {}
  }
}

export async function onSendRoomEmoji(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const emoji = (data?.emoji || '').trim();
    const targetUserId = data?.targetUserId || null;

    if (!roomId || !emoji) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'roomId and emoji are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Ensure socket is joined to room channel
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    const payload = {
      id: `emoji_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId,
      emoji,
      targetUserId,
      sender: {
        id: socket.user?.id || socket.userId,
        username: socket.user?.username || 'user',
        displayName: socket.user?.displayName || socket.user?.username || 'User',
        avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
      },
      timestamp: new Date().toISOString(),
    };

    // Broadcast to ALL room members including sender
    const broadcastTarget = io ? io.to(`room:${roomId}`) : socket;
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_EMOJI_RECEIVED, payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to send emoji reaction',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSendRoomChat(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const text = (data?.text || '').trim();

    if (!roomId || !text) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'roomId and message text are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // Ensure socket is joined to room channel
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    const payload = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId,
      sender: {
        id: socket.user?.id || socket.userId,
        username: socket.user?.username || 'user',
        displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
        avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
        isVip: Boolean(socket.user?.isVip),
        nobleLevel: socket.user?.nobleLevel || null,
        nobleTitle: socket.user?.nobleTitle || null,
      },
      text: text.substring(0, 500),
      timestamp: new Date().toISOString(),
      type: data?.type || 'text',
    };

    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
    broadcastTarget.emit('chat:message', payload);
    broadcastTarget.emit('room_chat_message', payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to send room chat message',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onKickUser(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const targetUserId = data?.targetUserId;

    if (!roomId || !targetUserId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'roomId and targetUserId are required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const payload = {
      roomId,
      targetUserId,
      kickedByUserId: socket.userId,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_KICKED, payload);

    if (typeof callback === 'function') {
      return callback({ success: true, message: 'User kicked successfully', data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to kick user' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export async function onSendRoomLike(arg1, arg2, arg3, arg4, arg5) {
  const { io, socket, data, callback } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
  try {
    const roomId = data?.roomId;
    const count = Number(data?.count) || 1;

    if (!roomId) {
      const err = {
        success: false,
        error: { code: SOCKET_ERRORS.VALIDATION_ERROR, message: 'Valid roomId is required' },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
    }

    const sender = data?.sender && typeof data.sender === 'object' ? data.sender : {
      id: socket.user?.id || socket.userId,
      userId: socket.user?.id || socket.userId,
      username: socket.user?.username || 'user',
      name: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
      displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
      avatarUrl: socket.user?.avatarUrl || socket.user?.profile?.avatarUrl || null,
      isVip: Boolean(socket.user?.isVip),
      nobleLevel: socket.user?.nobleLevel || null,
      nobleTitle: socket.user?.nobleTitle || null,
    };

    const payload = {
      roomId,
      count,
      userId: socket.user?.id || socket.userId,
      sender,
      timestamp: new Date().toISOString(),
    };

    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit('room:like', payload);
    broadcastTarget.emit('room:like_sent', payload);
    broadcastTarget.emit('room_like', payload);
    broadcastTarget.emit('like_sent', payload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: payload });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message || 'Failed to send room like' },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export function registerRoomHandlers(io, socket) {
  socket.on(
    SOCKET_EVENTS.ROOM_JOIN,
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_join',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_LEAVE,
    withRateLimit('ROOM_LEAVE', 10, 1000, (s, d, cb) => onLeaveRoom(io, s, d, cb))
  );
  socket.on(
    'room_leave',
    withRateLimit('ROOM_LEAVE', 10, 1000, (s, d, cb) => onLeaveRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_SNAPSHOT,
    withRateLimit('ROOM_SNAPSHOT', 10, 1000, (s, d, cb) => onRequestSnapshot(s, d, cb))
  );
  socket.on(
    'room_snapshot',
    withRateLimit('ROOM_SNAPSHOT', 10, 1000, (s, d, cb) => onRequestSnapshot(s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_CHAT_SEND,
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'room_chat_send',
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );
  socket.on(
    'send_room_chat',
    withRateLimit('ROOM_CHAT', 25, 1000, (s, d, cb) => onSendRoomChat(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_EMOJI_SEND,
    withRateLimit('ROOM_EMOJI', 30, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );
  socket.on(
    'room_emoji_send',
    withRateLimit('ROOM_EMOJI', 30, 1000, (s, d, cb) => onSendRoomEmoji(io, s, d, cb))
  );

  // Real-time Room Likes
  socket.on(
    'room:like',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'room:like_send',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'room_like',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );
  socket.on(
    'like_send',
    withRateLimit('ROOM_LIKE', 50, 1000, (s, d, cb) => onSendRoomLike(io, s, d, cb))
  );

  // Client user joined trigger
  socket.on(
    'room:user_joined',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );
  socket.on(
    'room_user_joined',
    withRateLimit('ROOM_JOIN', 10, 1000, (s, d, cb) => onJoinRoom(io, s, d, cb))
  );

  socket.on(
    SOCKET_EVENTS.ROOM_KICK_USER,
    withRateLimit('ROOM_MOD', 5, 1000, (s, d, cb) => onKickUser(io, s, d, cb))
  );

  socket.on(SOCKET_EVENTS.DISCONNECT, () => onSocketDisconnect(io, socket));
}

export default {
  buildRoomSnapshot,
  onJoinRoom,
  onLeaveRoom,
  onRequestSnapshot,
  onSendRoomChat,
  onSendRoomEmoji,
  onSendRoomLike,
  onKickUser,
  onSocketDisconnect,
  registerRoomHandlers,
};
