import presenceService from './presence.service.js';
import userRepository from '../repositories/user.repository.js';
import { deriveAgoraUid } from '../utils/agoraToken.util.js';

let ioInstance = null;

/**
 * A Socket.IO packet whose event name is not a string is rejected by every client as a
 * "parse error", and the client then drops the whole connection. An undefined constant
 * emitted after each gift did exactly that to every socket in the room (the host stopped
 * receiving joins, chats and gifts until they re-entered). Never let that happen again.
 */
function validEvent(event, where) {
  if (typeof event === 'string' && event.length > 0) return true;
  console.error(`[SocketEmitter] refusing to ${where} an event with an invalid name:`, event, new Error().stack?.split('\n')[2]?.trim());
  return false;
}

/**
 * Sets the global Socket.IO server instance.
 */
export function setSocketServerInstance(io) {
  ioInstance = io;
}

/**
 * Gets the global Socket.IO server instance.
 */
export function getSocketServerInstance() {
  return ioInstance;
}

/**
 * Emits an event to all connected sockets in a specific room.
 * 
 * @param {string} roomId - Room identifier
 * @param {string} event - Event name from SOCKET_EVENTS
 * @param {Object} payload - Event payload
 */
export function emitToRoom(roomId, event, payload) {
  if (!ioInstance || !roomId || !validEvent(event, 'emitToRoom')) return false;
  try {
    ioInstance.to(`room:${roomId}`).emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Emits an event to all connected sockets for a specific user.
 * 
 * @param {string} userId - User identifier
 * @param {string} event - Event name from SOCKET_EVENTS
 * @param {Object} payload - Event payload
 */
export function emitToUser(userId, event, payload) {
  if (!ioInstance || !userId || !validEvent(event, 'emitToUser')) return false;
  try {
    ioInstance.to(`user:${userId}`).emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Broadcasts an event globally to all connected sockets on the server.
 * 
 * @param {string} event - Event name
 * @param {Object} payload - Event payload
 */
export function broadcastGlobal(event, payload) {
  if (!ioInstance || !validEvent(event, 'broadcastGlobal')) return false;
  try {
    ioInstance.emit(event, payload);
    return true;
  } catch (err) {
    return false;
  }
}

export const emitToAll = broadcastGlobal;

/**
 * Subscribes all active Socket.IO connections of `userId` to `room:${roomId}`
 * and registers their presence in the room.
 * Ensures that hosts creating rooms via REST or viewers joining via REST
 * immediately receive all real-time room events (`room:gift_sent`, `room:chat_message`, `room:emoji`, etc.)
 * even if their client `room:join` socket packet raced with connection setup.
 */
export async function joinUserSocketsToRoom(userId, roomId, userInfo = null) {
  if (!userId || !roomId) return false;
  const uId = String(userId);
  const rId = String(roomId);

  try {
    await presenceService.setUserActiveRoom(uId, rId);
  } catch (_) {}

  if (!ioInstance) return false;

  try {
    // Join all sockets in user's personal room to the canonical room channel
    ioInstance.in(`user:${uId}`).socketsJoin(`room:${rId}`);

    const socketsMap = new Map();
    if (ioInstance.sockets?.sockets) {
      for (const [sid, s] of ioInstance.sockets.sockets) {
        if (String(s.userId || s.user?.id || '') === uId) {
          socketsMap.set(sid, s);
        }
      }
    }
    if (socketsMap.size === 0 && typeof ioInstance.in === 'function') {
      const fetched = await ioInstance.in(`user:${uId}`).fetchSockets().catch(() => []);
      for (const fs of fetched) {
        socketsMap.set(fs.id, ioInstance.sockets?.sockets?.get(fs.id) || fs);
      }
    }

    let fallbackDbUser = null;
    for (const [, sock] of socketsMap) {
      const localSock = ioInstance.sockets?.sockets?.get(sock.id) || sock;
      localSock.currentRoomId = rId;
      sock.currentRoomId = rId;
      if (typeof localSock.join === 'function') {
        await localSock.join(`room:${rId}`);
      }
      const sockUser = localSock.user || sock.data?.user || null;

      let effectiveInfo = userInfo || (sockUser ? {
        id: sockUser.id || uId,
        userId: sockUser.userId || uId,
        agoraUid: sockUser.agoraUid || localSock.agoraUid || sock.data?.agoraUid || deriveAgoraUid(uId),
        uid: sockUser.uid || localSock.agoraUid || sock.data?.agoraUid || deriveAgoraUid(uId),
        username: sockUser.username,
        displayName: sockUser.displayName || sockUser.name || sockUser.username,
        name: sockUser.name || sockUser.displayName || sockUser.username,
        avatarUrl: sockUser.avatarUrl || sockUser.profile?.avatarUrl || null,
        avatarFrame: sockUser.avatarFrame || null,
        nobleRank: sockUser.nobleRank || sockUser.nobleTitle || null,
        vipLevel: sockUser.vipLevel || 0,
        svipLevel: sockUser.svipLevel || 0,
        isGuest: Boolean(localSock.isGuest),
      } : null);

      if (!effectiveInfo && !String(uId).startsWith('guest_')) {
        if (!fallbackDbUser) {
          fallbackDbUser = await userRepository.findById(uId).catch(() => null);
        }
        if (fallbackDbUser) {
          const agUid = deriveAgoraUid(uId);
          effectiveInfo = {
            id: fallbackDbUser.id,
            userId: fallbackDbUser.id,
            agoraUid: agUid,
            uid: agUid,
            username: fallbackDbUser.username,
            displayName: fallbackDbUser.profile?.displayName || fallbackDbUser.username,
            name: fallbackDbUser.profile?.displayName || fallbackDbUser.username,
            avatarUrl: fallbackDbUser.avatarUrl || fallbackDbUser.profile?.avatarUrl || null,
            nobleRank: fallbackDbUser.profile?.nobleRank || null,
            vipLevel: fallbackDbUser.profile?.vipLevel || 0,
            svipLevel: fallbackDbUser.profile?.svipLevel || 0,
            level: fallbackDbUser.profile?.level || 1,
            isGuest: false,
          };
        }
      }

      await presenceService.addSocketToRoom(rId, uId, sock.id, effectiveInfo);
    }
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Unsubscribes all active Socket.IO connections of `userId` from `room:${roomId}`.
 * Prevents stale room membership from receiving events after leave or kick.
 */
export async function leaveUserSocketsFromRoom(userId, roomId) {
  if (!userId || !roomId) return false;
  const uId = String(userId);
  const rId = String(roomId);

  try {
    await presenceService.leaveRoomPresence(rId, uId);
  } catch (_) {}

  if (!ioInstance) return false;

  try {
    const socketsMap = new Map();
    if (ioInstance.sockets?.sockets) {
      for (const [sid, s] of ioInstance.sockets.sockets) {
        if (String(s.userId || s.user?.id || '') === uId) {
          socketsMap.set(sid, s);
        }
      }
    }
    if (socketsMap.size === 0 && typeof ioInstance.in === 'function') {
      const fetched = await ioInstance.in(`user:${uId}`).fetchSockets().catch(() => []);
      for (const fs of fetched) {
        socketsMap.set(fs.id, ioInstance.sockets?.sockets?.get(fs.id) || fs);
      }
    }

    for (const [, sock] of socketsMap) {
      if (sock.currentRoomId === rId) {
        sock.currentRoomId = null;
      }
      if (typeof sock.leave === 'function') {
        await sock.leave(`room:${rId}`);
      }
      await presenceService.removeSocketFromRoom(rId, uId, sock.id);
    }
    ioInstance.in(`user:${uId}`).socketsLeave(`room:${rId}`);
    return true;
  } catch (err) {
    return false;
  }
}

/**
 * Evicts all sockets from `room:${roomId}` when a session closes/ends.
 */
export async function clearRoomSockets(roomId) {
  if (!roomId) return false;
  const rId = String(roomId);

  try {
    await presenceService.clearRoomPresence(rId);
  } catch (_) {}

  if (!ioInstance) return false;

  try {
    const sockets = await ioInstance.in(`room:${rId}`).fetchSockets();
    for (const sock of sockets) {
      if (sock.currentRoomId === rId) {
        sock.currentRoomId = null;
      }
    }
    ioInstance.in(`room:${rId}`).socketsLeave(`room:${rId}`);
    return true;
  } catch (err) {
    return false;
  }
}

export default {
  setSocketServerInstance,
  getSocketServerInstance,
  emitToRoom,
  emitToUser,
  broadcastGlobal,
  emitToAll,
  joinUserSocketsToRoom,
  leaveUserSocketsFromRoom,
  clearRoomSockets,
};
