import roomRepository from '../repositories/room.repository.js';
import userRepository from '../repositories/user.repository.js';
import roomService from '../services/room.service.js';
import presenceService from './presence.service.js';
import prisma from '../config/database.js';
import { startHostAbsentTimer, clearHostAbsentTimer } from './roomTimer.manager.js';
import { deriveAgoraUid } from '../utils/agoraToken.util.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';

/**
 * Builds a safe, public room snapshot containing no sensitive admin or private fields.
 */
export function buildRoomSnapshot(room, viewerCount, activePresenceUsers = []) {
  if (!room) return null;

  const hostUserId = room.creatorUserId || room.creator?.id;

  const membersList = (room.members || [])
    .filter((m) => (m.userId || m.user?.id) !== hostUserId)
    .map((m) => {
      const u = m.user || {};
      const displayName = u.profile?.displayName || u.displayName || u.username || 'User';
      return {
        userId: m.userId || u.id,
        role: m.role || 'LISTENER',
        user: {
          id: u.id || m.userId,
          username: u.username || displayName,
          displayName,
          name: displayName,
          avatarUrl: u.avatarUrl || u.profile?.avatarUrl || null,
        },
      };
    });

  // Merge active guest participants
  const existingMemberIds = new Set(membersList.map((m) => m.userId));
  for (const pres of (activePresenceUsers || [])) {
    const pid = pres.userId || pres.id;
    if (pid && !existingMemberIds.has(pid) && pid !== hostUserId) {
      const guestDisplayName = pres.displayName || pres.name || pres.username || `User_${String(pid).replace('guest_', '').substring(0, 5)}`;
      membersList.push({
        userId: pid,
        role: 'LISTENER',
        user: {
          id: pid,
          username: guestDisplayName,
          displayName: guestDisplayName,
          name: guestDisplayName,
          avatarUrl: pres.avatarUrl || null,
        },
      });
      existingMemberIds.add(pid);
    }
  }

  return {
    id: room.id,
    roomId: room.id,
    creatorUserId: hostUserId,
    title: room.title,
    roomType: room.roomType || 'VIDEO_PARTY',
    category: room.category || 'CHATTING',
    status: room.status,
    isPinned: Boolean(room.isPinned),
    pinPosition: room.pinPosition || null,
    currentViewersCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    viewerCount: typeof viewerCount === 'number' ? viewerCount : (room.currentViewersCount || 0),
    agoraChannelName: room.agoraChannelName || null,
    agoraHostUid: hostUserId ? deriveAgoraUid(hostUserId) : null,
    host: room.creator ? {
      id: room.creator.id,
      username: room.creator.username,
      displayName: room.creator.profile?.displayName || room.creator.username,
      avatarUrl: room.creator.profile?.avatarUrl || null,
    } : null,
    seats: (room.seats || []).map((s) => {
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
    members: membersList,
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
    const dbCandidate = (arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : arg5;
    const db = (dbCandidate && typeof dbCandidate === 'object') ? dbCandidate : prisma;
    return { io, socket, data, callback, db };
  }

  // Case B: (socket, data, callback, db)
  const socket = arg1;
  const data = arg2;
  const callback = typeof arg3 === 'function' ? arg3 : (typeof arg4 === 'function' ? arg4 : null);
  const dbCandidate = (arg3 && typeof arg3 === 'object' && typeof arg3 !== 'function') ? arg3 : ((arg4 && typeof arg4 === 'object' && typeof arg4 !== 'function') ? arg4 : arg5);
  const db = (dbCandidate && typeof dbCandidate === 'object') ? dbCandidate : prisma;
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
    const room = await roomRepository.findRoomById(roomId, db || prisma);
    if (!room) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_FOUND, message: 'Room not found' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (room.status && !['LIVE', 'ACTIVE', 'OPEN'].includes(room.status.toUpperCase())) {
      const err = { success: false, error: { code: SOCKET_ERRORS.ROOM_NOT_LIVE, message: 'Room is not available or has ended' } };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    // 2. Immediately subscribe socket to room channel so broadcasts & chat are reliably delivered
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
      if (room.id !== roomId) {
        socket.join(`room:${room.id}`);
      }
    }
    socket.joinedRooms = socket.joinedRooms || new Set();
    socket.joinedRooms.add(roomId);
    socket.joinedRooms.add(room.id);

    // 3. Persistent RoomMember registration via authoritative Room Service
    let joinResult = null;
    try {
      joinResult = await roomService.joinRoom(room.id, userId, db || prisma);
    } catch (joinErr) {
      console.warn(`[RoomSocket] Warning joining room ${roomId} for user ${userId}:`, joinErr.message);
    }

    // Cancel any active host absence timer if host returned
    const isHostUser = room.creatorUserId === userId || room.creator?.id === userId;
    if (isHostUser) {
      clearHostAbsentTimer(room.id, io);
    }

    const clientUser = data?.user || {};
    const effectiveJoinedId = clientUser.id || clientUser.userId || socket.user?.id || userId;
    const fallbackGuestName = String(effectiveJoinedId).startsWith('guest_')
      ? `User_${String(effectiveJoinedId).replace('guest_', '').substring(0, 5)}`
      : `User_${String(effectiveJoinedId).substring(0, 6)}`;
    const effectiveJoinedName = clientUser.displayName || clientUser.name || clientUser.username || socket.user?.displayName || socket.user?.name || socket.user?.username || fallbackGuestName;
    const effectiveJoinedAvatar = clientUser.avatarUrl || socket.user?.avatarUrl || null;
    const effectiveJoinedVip = Boolean(clientUser.isVip || socket.user?.isVip);
    const effectiveJoinedNoble = clientUser.nobleTitle || socket.user?.nobleTitle || null;
    const isGuestUser = Boolean(socket.isGuest || String(effectiveJoinedId).startsWith('guest_'));

    // 4. Ephemeral Presence Tracking with rich user metadata
    let isFirstSocket = true;
    try {
      const pres = await presenceService.addSocketToRoom(room.id, effectiveJoinedId, socket.id, {
        displayName: effectiveJoinedName,
        avatarUrl: effectiveJoinedAvatar,
        isGuest: isGuestUser,
        joinedAt: new Date().toISOString(),
      });
      isFirstSocket = pres?.isFirstSocket ?? true;
    } catch (_) {}

    // 5. Generate and Send Authoritative Room Snapshot
    let currentCount = 0;
    try {
      currentCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    } catch (_) {
      currentCount = typeof joinResult?.currentViewersCount === 'number'
        ? joinResult.currentViewersCount
        : (typeof room.currentViewersCount === 'number' ? room.currentViewersCount : 1);
    }

    let activeUsers = [];
    try {
      activeUsers = await presenceService.getRoomActiveUsers(room.id);
    } catch (_) {}

    const snapshot = buildRoomSnapshot(room, currentCount, activeUsers);
    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, {
      room: snapshot,
      ...snapshot,
      seats: snapshot.seats || [],
      members: snapshot.members || [],
      currentViewersCount: currentCount,
      viewerCount: currentCount,
    });

    // 6. Broadcast user joined event ONLY on genuine initial entry (not reconnects/pings)
    if (isFirstSocket) {
      const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
      const userPayload = {
        roomId: room.id,
        clientRoomId: roomId,
        userId: effectiveJoinedId,
        id: effectiveJoinedId,
        user: {
          id: effectiveJoinedId,
          userId: effectiveJoinedId,
          username: clientUser.username || socket.user?.username || effectiveJoinedName,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
          nobleTitle: effectiveJoinedNoble,
          isGuest: isGuestUser,
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

      if (room.id !== roomId && io) {
        io.to(`room:${room.id}`).emit(SOCKET_EVENTS.ROOM_USER_JOINED, userPayload);
        io.to(`room:${room.id}`).emit('room:user_joined', userPayload);
      }

      const viewerPayload = {
        roomId: room.id,
        clientRoomId: roomId,
        viewerCount: currentCount,
        count: currentCount,
        currentViewersCount: currentCount,
      };
      broadcastTarget.emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
      broadcastTarget.emit('room:viewer_count_changed', viewerPayload);
      broadcastTarget.emit('room:viewer_count', viewerPayload);
      broadcastTarget.emit('viewer_count_changed', viewerPayload);

      if (room.id !== roomId && io) {
        io.to(`room:${room.id}`).emit(SOCKET_EVENTS.ROOM_VIEWER_COUNT_CHANGED, viewerPayload);
      }

      // 7. Broadcast system chat announcement so all room participants see "[User] has joined the party"
      const chatPayload = {
        id: `sys_join_${Date.now()}_${effectiveJoinedId}`,
        roomId: room.id,
        clientRoomId: roomId,
        userId: effectiveJoinedId,
        sender: {
          id: effectiveJoinedId,
          username: clientUser.username || socket.user?.username || effectiveJoinedName,
          name: effectiveJoinedName,
          displayName: effectiveJoinedName,
          avatarUrl: effectiveJoinedAvatar,
          isVip: effectiveJoinedVip,
          nobleLevel: effectiveJoinedNoble,
        },
        text: `${effectiveJoinedName} has joined the party 🎉`,
        type: 'SYSTEM',
        isSystemMessage: true,
        timestamp: new Date().toISOString(),
      };
      broadcastTarget.emit(SOCKET_EVENTS.ROOM_CHAT_RECEIVE, chatPayload);
      broadcastTarget.emit('room:chat_message', chatPayload);
      broadcastTarget.emit('room:chat', chatPayload);
      broadcastTarget.emit('chat_message', chatPayload);

      if (room.id !== roomId && io) {
        io.to(`room:${room.id}`).emit(SOCKET_EVENTS.ROOM_CHAT_RECEIVE, chatPayload);
        io.to(`room:${room.id}`).emit('room:chat_message', chatPayload);
      }
    }

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
    if (socket.joinedRooms) {
      socket.joinedRooms.delete(roomId);
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
      const room = await roomRepository.findRoomById(roomId, db);
      const isHostUser = room && (room.creatorUserId === userId || room.creator?.id === userId);

      let leaveResult = null;
      try {
        leaveResult = await roomService.leaveRoom(roomId, userId, db);
      } catch (leaveErr) {
        // Safe fallback
      }

      try {
        updatedViewerCount = await presenceService.getRoomViewerCount(roomId, room?.creatorUserId);
      } catch (_) {
        updatedViewerCount = leaveResult?.currentViewersCount || 0;
      }

      const isRoomEnded = leaveResult?.status === 'ENDED';
      const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);

      if (isRoomEnded) {
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_CLOSED, {
          roomId,
          status: 'ENDED',
          reason: 'NO_MEMBERS_REMAINING',
        });
        if (io) {
          io.emit('room:closed', { roomId, status: 'ENDED' });
          io.emit('room:deleted', { roomId });
        }
      } else if (isHostUser && room) {
        // Host has left/disconnected: Room stays alive as long as viewers/speakers remain.
        const hostAwayPayload = {
          roomId,
          userId,
          status: 'LIVE',
          reason: 'HOST_AWAY',
          message: 'Host has temporarily stepped away.',
        };
        broadcastTarget.emit('room:host_away', hostAwayPayload);
        broadcastTarget.emit('room:host_left', hostAwayPayload);
        startHostAbsentTimer(roomId, room.roomType || 'LIVE_VIDEO', userId, io);
      } else {
        const leftPayload = {
          roomId: room ? room.id : roomId,
          clientRoomId: roomId,
          userId,
          id: userId,
          viewerCount: updatedViewerCount,
          count: updatedViewerCount,
          currentViewersCount: updatedViewerCount,
          user: {
            id: userId,
            displayName: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
            name: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
            username: socket.user?.username || 'user',
            avatarUrl: socket.user?.avatarUrl || null,
            isGuest: Boolean(socket.isGuest || String(userId).startsWith('guest_')),
          },
        };
        broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, leftPayload);
        broadcastTarget.emit('room:user_left', leftPayload);
        broadcastTarget.emit('user_left', leftPayload);
        broadcastTarget.emit('user:left', leftPayload);
        broadcastTarget.emit('room_user_left', leftPayload);

        const countPayload = {
          roomId: room ? room.id : roomId,
          clientRoomId: roomId,
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

export async function onSocketDisconnect(io, socket, db) {
  try {
    const userId = socket.userId;
    if (!userId) return;

    // Track rooms cleaned up for this socket to ensure idempotency across 'disconnecting' and 'disconnect'
    socket._cleanedRooms = socket._cleanedRooms || new Set();

    const roomCandidates = new Set();
    if (socket.rooms) {
      for (const r of socket.rooms) {
        if (typeof r === 'string' && r.startsWith('room:')) {
          roomCandidates.add(r.replace(/^room:/, ''));
        }
      }
    }
    if (socket.joinedRooms) {
      for (const r of socket.joinedRooms) {
        if (typeof r === 'string') {
          roomCandidates.add(r.replace(/^room:/, ''));
        }
      }
      socket.joinedRooms.clear();
    }

    const joinedRooms = Array.from(roomCandidates);

    for (const roomId of joinedRooms) {
      if (socket._cleanedRooms.has(roomId)) {
        continue;
      }
      socket._cleanedRooms.add(roomId);

      try {
        let isLastSocket = true;
        try {
          const pres = await presenceService.removeSocketFromRoom(roomId, userId, socket.id);
          isLastSocket = pres?.isLastSocket ?? true;
        } catch {}

        if (isLastSocket) {
          const room = await roomRepository.findRoomById(roomId, db);
          if (!room || room.status !== 'LIVE') continue;

          const isHostUser = room.creatorUserId === userId || room.creator?.id === userId;
          const leaveResult = await roomService.leaveRoom(roomId, userId, db).catch(() => null);
          let updatedViewerCount = 0;
          try {
            updatedViewerCount = await presenceService.getRoomViewerCount(roomId, room.creatorUserId);
          } catch (_) {
            updatedViewerCount = leaveResult?.currentViewersCount || 0;
          }
          const broadcastTarget = io ? io.to(`room:${roomId}`) : socket;

          if (isHostUser) {
            const isAudioParty = (room.roomType || '').toUpperCase().includes('AUDIO') || (room.roomType || '').toUpperCase().includes('PARTY');
            if (isAudioParty) {
              startHostAbsentTimer(roomId, 'AUDIO_PARTY', userId, io);
            } else {
              const hostLeftPayload = {
                roomId,
                status: 'ENDED',
                reason: 'HOST_LEFT',
                message: 'The live stream has ended by the host.',
              };
              broadcastTarget.emit(SOCKET_EVENTS.ROOM_CLOSED, hostLeftPayload);
              broadcastTarget.emit('room:closed', hostLeftPayload);
              broadcastTarget.emit('room_closed', hostLeftPayload);
              broadcastTarget.emit('stream:ended', hostLeftPayload);
              broadcastTarget.emit('room:host_left', hostLeftPayload);
              startHostAbsentTimer(roomId, 'LIVE_VIDEO', userId, io);
            }
          } else {
            const leftPayload = {
              roomId: room.id,
              clientRoomId: roomId,
              userId,
              id: userId,
              viewerCount: updatedViewerCount,
              count: updatedViewerCount,
              currentViewersCount: updatedViewerCount,
              user: {
                id: userId,
                displayName: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
                name: socket.user?.displayName || socket.user?.name || (socket.isGuest ? `User_${String(userId).replace('guest_', '').substring(0, 5)}` : 'Viewer'),
                username: socket.user?.username || 'user',
                avatarUrl: socket.user?.avatarUrl || null,
                isGuest: Boolean(socket.isGuest || String(userId).startsWith('guest_')),
              },
            };
            broadcastTarget.emit(SOCKET_EVENTS.ROOM_USER_LEFT, leftPayload);
            broadcastTarget.emit('room:user_left', leftPayload);
            broadcastTarget.emit('user_left', leftPayload);
            broadcastTarget.emit('user:left', leftPayload);
            broadcastTarget.emit('room_user_left', leftPayload);

            const countPayload = {
              roomId: room.id,
              clientRoomId: roomId,
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
      } catch (innerErr) {
        console.warn(`[RoomSocket] Error handling disconnect for room ${roomId}:`, innerErr?.message);
      }
    }
  } catch (err) {
    console.error('[RoomSocket] onSocketDisconnect root error:', err);
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

    let viewerCount = 0;
    try {
      viewerCount = await presenceService.getRoomViewerCount(room.id, room.creatorUserId);
    } catch (_) {
      viewerCount = room.currentViewersCount || 0;
    }

    let activeUsers = [];
    try {
      activeUsers = await presenceService.getRoomActiveUsers(room.id);
    } catch (_) {}

    const snapshot = buildRoomSnapshot(room, viewerCount, activeUsers);
    const responsePayload = {
      room: snapshot,
      ...snapshot,
      host: snapshot.host,
      seats: snapshot.seats || [],
      members: snapshot.members || [],
      currentViewersCount: viewerCount,
      viewerCount,
      timestamp: new Date().toISOString(),
    };

    socket.emit(SOCKET_EVENTS.ROOM_SNAPSHOT, responsePayload);

    if (typeof callback === 'function') {
      return callback({ success: true, data: responsePayload });
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

export async function onRequestActiveRooms(socket, data, callback, db = prisma) {
  try {
    const filters = {
      roomType: data?.roomType,
      category: data?.category,
      search: data?.search,
      page: data?.page || 1,
      limit: data?.limit || 50,
      isPrivate: false,
    };

    const result = await roomService.getActiveRooms(filters, db);
    const payload = {
      success: true,
      data: result.rooms,
      rooms: result.rooms,
      pagination: result.pagination,
      timestamp: new Date().toISOString(),
    };

    if (typeof callback === 'function') {
      return callback(payload);
    }
    socket.emit('rooms:active_list', payload);
    socket.emit('rooms_active_list', payload);
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to retrieve active rooms',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
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
  const { io, socket, data, callback, db } = resolveArgs(arg1, arg2, arg3, arg4, arg5);
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

    // Resolve canonical room ID if short ID was passed
    let canonicalRoomId = roomId;
    if (roomId && roomId.length <= 16) {
      try {
        const found = await roomRepository.findRoomById(roomId, db || prisma);
        if (found) {
          canonicalRoomId = found.id;
        }
      } catch (_) {}
    }

    // Ensure socket is joined to room channel
    if (typeof socket.join === 'function') {
      socket.join(`room:${roomId}`);
      if (canonicalRoomId !== roomId) {
        socket.join(`room:${canonicalRoomId}`);
      }
    }

    const clientSender = data?.sender || data?.user || {};
    const senderId = clientSender.id || clientSender.userId || socket.user?.id || socket.userId;
    let senderName = clientSender.displayName || clientSender.name || clientSender.username || socket.user?.displayName || socket.user?.name || socket.user?.username;
    let senderAvatar = clientSender.avatarUrl || socket.user?.avatarUrl;
    let senderVip = Boolean(clientSender.isVip || socket.user?.isVip);
    let senderNoble = clientSender.nobleTitle || clientSender.nobleLevel || socket.user?.nobleTitle || socket.user?.nobleLevel;
    let senderRole = clientSender.role || socket.user?.role;
    let senderFrame = clientSender.avatarFrame || clientSender.frameUrl || socket.user?.avatarFrame;
    let senderBubble = clientSender.chatBubble || clientSender.bubbleUrl || socket.user?.chatBubble;

    if (!senderName || senderName === 'User' || senderName === 'ZeParty Member' || senderName.startsWith('guest_')) {
      try {
        if (senderId && !String(senderId).startsWith('guest_')) {
          const dbUser = await userRepository.findById(senderId);
          if (dbUser) {
            senderName = dbUser.profile?.displayName || dbUser.name || dbUser.username || senderName;
            senderAvatar = dbUser.profile?.avatarUrl || dbUser.avatarUrl || senderAvatar;
            senderVip = Boolean(dbUser.profile?.vipLevel > 0 || dbUser.profile?.svipLevel > 0);
            senderNoble = dbUser.profile?.nobleRank || senderNoble;
            senderRole = dbUser.userType || senderRole;
          }
        }
      } catch (_) {}
    }

    if (!senderName || senderName === 'ZeParty Member') {
      senderName = `User_${String(senderId).replace('guest_', '').substring(0, 5)}`;
    }

    const payload = {
      id: data?.id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      senderUserId: senderId,
      sender: {
        id: senderId,
        userId: senderId,
        username: clientSender.username || socket.user?.username || senderName,
        name: senderName || 'User',
        displayName: senderName || 'User',
        avatarUrl: senderAvatar || null,
        avatarFrame: senderFrame || null,
        chatBubble: senderBubble || null,
        isVip: senderVip,
        nobleLevel: senderNoble || null,
        nobleTitle: senderNoble || null,
        role: senderRole || null,
      },
      text: text.substring(0, 500),
      timestamp: new Date().toISOString(),
      type: data?.type || 'text',
    };

    const broadcastTarget = io ? io.to(`room:${roomId}`) : (socket.to ? socket.to(`room:${roomId}`) : socket);
    broadcastTarget.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
    broadcastTarget.emit('room:chat_message', payload);
    broadcastTarget.emit('room_chat_message', payload);
    broadcastTarget.emit('chat_message', payload);
    broadcastTarget.emit('room:comment', payload);

    if (io && canonicalRoomId !== roomId) {
      io.to(`room:${canonicalRoomId}`).emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      io.to(`room:${canonicalRoomId}`).emit('room:chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('room_chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('chat_message', payload);
      io.to(`room:${canonicalRoomId}`).emit('room:comment', payload);
    }

    if (!io && socket && typeof socket.emit === 'function') {
      socket.emit(SOCKET_EVENTS.ROOM_CHAT_MESSAGE, payload);
      socket.emit('room:chat_message', payload);
      socket.emit('room_chat_message', payload);
      socket.emit('chat_message', payload);
      socket.emit('room:comment', payload);
    }

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

    const broadcastTarget = socket.to ? socket.to(`room:${roomId}`) : (io ? io.to(`room:${roomId}`) : socket);
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

  // Authoritative Active Rooms Snapshot Request for newly connected or reconnecting clients
  socket.on(
    'rooms:get_active',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );
  socket.on(
    'rooms_get_active',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );
  socket.on(
    'rooms:list',
    withRateLimit('ROOM_ACTIVE_LIST', 15, 1000, (s, d, cb) => onRequestActiveRooms(s, d, cb))
  );

  // Handle both disconnecting (before leaveAll) and disconnect (as safety fallback)
  socket.on('disconnecting', () => onSocketDisconnect(io, socket));
  socket.on(SOCKET_EVENTS.DISCONNECT, () => onSocketDisconnect(io, socket));
}

export default {
  buildRoomSnapshot,
  onJoinRoom,
  onLeaveRoom,
  onRequestSnapshot,
  onRequestActiveRooms,
  onSendRoomChat,
  onSendRoomEmoji,
  onSendRoomLike,
  onKickUser,
  onSocketDisconnect,
  registerRoomHandlers,
};
