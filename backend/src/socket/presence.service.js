import redisClient from '../config/redis.js';
import prisma from '../config/database.js';

// Ephemeral in-memory fallback store when Redis is disconnected (e.g. isolated test environments)
// memoryRoomUsers: roomId -> Map<userId, { sockets: Set<socketId>, userInfo: object }>
const memoryRoomUsers = new Map();
// memorySocketMap: socketId -> { roomId, userId }
const memorySocketMap = new Map();

// Global user connection tracking across devices & rooms
// memoryUserSockets: userId -> Set<socketId>
const memoryUserSockets = new Map();
// memorySocketUser: socketId -> userId
const memorySocketUser = new Map();
// memoryUserRoom: userId -> roomId
const memoryUserRoom = new Map();
// memoryUserLastSeen: userId -> ISO timestamp
const memoryUserLastSeen = new Map();
// memoryRoomFeedCleared: roomId -> ISO timestamp
const memoryRoomFeedCleared = new Map();

/**
 * Realtime Presence Service supporting:
 * 1. Global user connection & socket registry (ONLINE vs OFFLINE)
 * 2. Multi-device / multi-socket safety:
 *    - A user with multiple connected sockets remains ONLINE when one disconnects
 *    - A user becomes OFFLINE only when ALL active sockets disconnect
 * 3. Authoritative active room presence (IN_ROOM)
 *    - Set only when confirmed connection + active room membership
 *    - NEVER inferred from room ownership or host badge
 * 4. Preserved room presence while room is minimized
 * 5. Immediate state reconciliation on leave, kick, room close, logout, or disconnect
 * 6. Fallback to UNKNOWN state if presence lookup fails (NEVER default to Online)
 */

export async function registerUserSocket(userId, socketId) {
  if (!userId || !socketId) return { isFirstSocket: false, socketCount: 0 };
  const uId = String(userId);
  const sId = String(socketId);

  const redisKey = `presence:user:${uId}:sockets`;
  const socketUserKey = `presence:socket:${sId}:user`;
  const lastSeenKey = `presence:user:${uId}:last_seen`;
  const now = new Date().toISOString();

  if (redisClient.isOpen) {
    try {
      await redisClient.sAdd(redisKey, sId);
      await redisClient.expire(redisKey, 86400);
      await redisClient.set(socketUserKey, uId, { EX: 86400 });
      await redisClient.set(lastSeenKey, now, { EX: 86400 * 30 });

      const count = await redisClient.sCard(redisKey);
      return {
        isFirstSocket: count === 1,
        socketCount: count,
      };
    } catch (err) {
      // Fall through to in-memory fallback
    }
  }

  // In-memory fallback
  if (!memoryUserSockets.has(uId)) {
    memoryUserSockets.set(uId, new Set());
  }
  const socketSet = memoryUserSockets.get(uId);
  const isFirst = socketSet.size === 0;
  socketSet.add(sId);
  memorySocketUser.set(sId, uId);
  memoryUserLastSeen.set(uId, now);

  return {
    isFirstSocket: isFirst,
    socketCount: socketSet.size,
  };
}

export async function unregisterUserSocket(userId, socketId) {
  if (!userId && !socketId) return { isLastSocket: true, remainingCount: 0 };
  const sId = String(socketId || '');
  let uId = userId ? String(userId) : null;

  if (!uId && sId) {
    if (redisClient.isOpen) {
      try {
        uId = await redisClient.get(`presence:socket:${sId}:user`);
      } catch (_) {}
    }
    if (!uId) {
      uId = memorySocketUser.get(sId);
    }
  }

  if (!uId) return { isLastSocket: true, remainingCount: 0 };

  const redisKey = `presence:user:${uId}:sockets`;
  const socketUserKey = `presence:socket:${sId}:user`;
  const lastSeenKey = `presence:user:${uId}:last_seen`;
  const now = new Date().toISOString();

  if (redisClient.isOpen) {
    try {
      await redisClient.del(socketUserKey);
      await redisClient.sRem(redisKey, sId);
      const remainingCount = await redisClient.sCard(redisKey);
      const isLast = remainingCount === 0;

      await redisClient.set(lastSeenKey, now, { EX: 86400 * 30 });
      if (isLast) {
        await redisClient.del(redisKey);
      }

      return {
        isLastSocket: isLast,
        remainingCount,
        userId: uId,
      };
    } catch (err) {
      // Fall through to memory
    }
  }

  // In-memory fallback
  memorySocketUser.delete(sId);
  const socketSet = memoryUserSockets.get(uId);
  if (!socketSet) {
    return { isLastSocket: true, remainingCount: 0, userId: uId };
  }

  socketSet.delete(sId);
  const remainingCount = socketSet.size;
  const isLast = remainingCount === 0;
  memoryUserLastSeen.set(uId, now);

  if (isLast) {
    memoryUserSockets.delete(uId);
  }

  return {
    isLastSocket: isLast,
    remainingCount,
    userId: uId,
  };
}

export async function hasActiveSocket(userId) {
  if (!userId) return false;
  const uId = String(userId);
  const redisKey = `presence:user:${uId}:sockets`;

  if (redisClient.isOpen) {
    try {
      const count = await redisClient.sCard(redisKey);
      return count > 0;
    } catch (_) {}
  }

  const socketSet = memoryUserSockets.get(uId);
  return Boolean(socketSet && socketSet.size > 0);
}

export async function getUserSocketCount(userId) {
  if (!userId) return 0;
  const uId = String(userId);
  const redisKey = `presence:user:${uId}:sockets`;

  if (redisClient.isOpen) {
    try {
      return await redisClient.sCard(redisKey);
    } catch (_) {}
  }

  const socketSet = memoryUserSockets.get(uId);
  return socketSet ? socketSet.size : 0;
}

export async function setUserActiveRoom(userId, roomId) {
  if (!userId || !roomId) return;
  const uId = String(userId);
  const rId = String(roomId);

  if (redisClient.isOpen) {
    try {
      await redisClient.set(`presence:user:${uId}:room`, rId, { EX: 86400 });
    } catch (_) {}
  }

  memoryUserRoom.set(uId, rId);
}

export async function clearUserActiveRoom(userId, roomId = null) {
  if (!userId) return;
  const uId = String(userId);
  const key = `presence:user:${uId}:room`;

  if (redisClient.isOpen) {
    try {
      if (roomId) {
        const current = await redisClient.get(key);
        if (current === String(roomId)) {
          await redisClient.del(key);
        }
      } else {
        await redisClient.del(key);
      }
    } catch (_) {}
  }

  if (roomId) {
    if (memoryUserRoom.get(uId) === String(roomId)) {
      memoryUserRoom.delete(uId);
    }
  } else {
    memoryUserRoom.delete(uId);
  }
}

export async function getUserActiveRoom(userId) {
  if (!userId) return null;
  const uId = String(userId);

  if (redisClient.isOpen) {
    try {
      const val = await redisClient.get(`presence:user:${uId}:room`);
      if (val) return val;
    } catch (_) {}
  }

  return memoryUserRoom.get(uId) || null;
}

export async function getUserLastSeen(userId, db = prisma) {
  if (!userId) return null;
  const uId = String(userId);

  if (redisClient.isOpen) {
    try {
      const val = await redisClient.get(`presence:user:${uId}:last_seen`);
      if (val) return val;
    } catch (_) {}
  }

  const inMem = memoryUserLastSeen.get(uId);
  if (inMem) return inMem;

  // Check persistent DB user device or session
  try {
    const dev = await db.userDevice?.findFirst?.({
      where: { userId: uId },
      orderBy: { lastSeenAt: 'desc' },
      select: { lastSeenAt: true },
    });
    if (dev?.lastSeenAt) return dev.lastSeenAt.toISOString();

    const sess = await db.userSession?.findFirst?.({
      where: { userId: uId },
      orderBy: { createdAt: 'desc' },
      select: { createdAt: true },
    });
    if (sess?.createdAt) return sess.createdAt.toISOString();
  } catch (_) {}

  return null;
}

export async function clearUserPresence(userId) {
  if (!userId) return;
  const uId = String(userId);

  if (redisClient.isOpen) {
    try {
      await redisClient.del(`presence:user:${uId}:sockets`);
      await redisClient.del(`presence:user:${uId}:room`);
    } catch (_) {}
  }

  memoryUserSockets.delete(uId);
  memoryUserRoom.delete(uId);
}

/**
 * Authoritative Central Presence Service:
 * Resolves consistent presence state (IN_ROOM, ONLINE, OFFLINE, UNKNOWN).
 * 
 * Rules:
 * 1. IN_ROOM: Valid active socket connection AND verified membership in active LIVE room.
 * 2. ONLINE: Valid active socket connection outside any active room.
 * 3. OFFLINE: No valid active socket connection.
 * 4. UNKNOWN: Presence cannot be determined or lookup failed (never defaults to ONLINE).
 * 5. Presence is NEVER inferred from room ownership, host badges, or stale flags.
 */
export async function getUserPresence(userId, db = prisma) {
  if (!userId) {
    return {
      userId: null,
      presenceStatus: 'OFFLINE',
      isOnline: false,
      online: false,
      isInRoom: false,
      currentRoomId: null,
      currentRoomTitle: null,
      currentRoomSessionId: null,
      currentRoom: null,
      inRoomAvailable: false,
      lastSeenAt: null,
      lastActiveAt: null,
      lastSeen: null,
      timestamp: new Date().toISOString(),
    };
  }

  const uId = String(userId);

  try {
    const isConnected = await hasActiveSocket(uId);

    if (!isConnected) {
      const lastSeenAt = await getUserLastSeen(uId, db);
      return {
        userId: uId,
        presenceStatus: 'OFFLINE',
        isOnline: false,
        online: false,
        isInRoom: false,
        currentRoomId: null,
        currentRoomTitle: null,
        currentRoomSessionId: null,
        currentRoom: null,
        inRoomAvailable: false,
        lastSeenAt,
        lastActiveAt: lastSeenAt,
        lastSeen: lastSeenAt,
        timestamp: new Date().toISOString(),
      };
    }

    // User is connected! Check if user is in an active room
    const activeRoomId = await getUserActiveRoom(uId);
    if (activeRoomId) {
      try {
        const room = await db.room.findUnique({
          where: { id: activeRoomId },
          select: {
            id: true,
            title: true,
            coverImageUrl: true,
            roomType: true,
            status: true,
            currentViewersCount: true,
            creatorUserId: true,
          },
        });

        const isLive = room && ['LIVE', 'ACTIVE', 'OPEN'].includes(String(room.status).toUpperCase());
        const inPresence = isLive && (await isUserInRoom(activeRoomId, uId));

        if (isLive && inPresence) {
          const nowStr = new Date().toISOString();
          return {
            userId: uId,
            presenceStatus: 'IN_ROOM',
            isOnline: true,
            online: true,
            isInRoom: true,
            currentRoomId: room.id,
            currentRoomTitle: room.title,
            currentRoomSessionId: room.id,
            currentRoom: {
              id: room.id,
              title: room.title,
              coverImageUrl: room.coverImageUrl,
              roomType: room.roomType,
              status: room.status,
              currentViewersCount: room.currentViewersCount || 1,
              isHost: room.creatorUserId === uId,
            },
            inRoomAvailable: true,
            lastSeenAt: nowStr,
            lastActiveAt: nowStr,
            lastSeen: nowStr,
            timestamp: nowStr,
          };
        } else {
          // Room has ended or user is no longer in room presence: clean up stale pointer
          await clearUserActiveRoom(uId, activeRoomId);
        }
      } catch (roomErr) {
        console.warn(`[PresenceService] Warning checking room ${activeRoomId} for user ${uId}:`, roomErr.message);
      }
    }

    // User is connected outside any active room
    const nowOnlineStr = new Date().toISOString();
    return {
      userId: uId,
      presenceStatus: 'ONLINE',
      isOnline: true,
      online: true,
      isInRoom: false,
      currentRoomId: null,
      currentRoomTitle: null,
      currentRoomSessionId: null,
      currentRoom: null,
      inRoomAvailable: false,
      lastSeenAt: nowOnlineStr,
      lastActiveAt: nowOnlineStr,
      lastSeen: nowOnlineStr,
      timestamp: nowOnlineStr,
    };
  } catch (err) {
    console.error(`[PresenceService] Critical error checking presence for user ${uId}:`, err.message);
    // Never default an unverified user to Online on failure
    return {
      userId: uId,
      presenceStatus: 'UNKNOWN',
      isOnline: false,
      online: false,
      isInRoom: false,
      currentRoomId: null,
      currentRoomTitle: null,
      currentRoomSessionId: null,
      currentRoom: null,
      inRoomAvailable: false,
      lastSeenAt: null,
      lastActiveAt: null,
      lastSeen: null,
      timestamp: new Date().toISOString(),
      error: 'Presence lookup failed',
    };
  }
}

/**
 * Broadcasts authoritative presence state to all connected clients and the user's private channel.
 */
export function broadcastPresenceChange(io, userId, presenceData) {
  if (!io || !userId || !presenceData) return;
  const payload = {
    userId: String(userId),
    id: String(userId),
    presenceStatus: presenceData.presenceStatus,
    status: presenceData.presenceStatus,
    isOnline: Boolean(presenceData.isOnline),
    online: Boolean(presenceData.isOnline),
    isInRoom: Boolean(presenceData.isInRoom),
    currentRoomId: presenceData.currentRoomId || null,
    currentRoomTitle: presenceData.currentRoomTitle || null,
    currentRoom: presenceData.currentRoom || null,
    inRoomAvailable: Boolean(presenceData.inRoomAvailable),
    lastSeenAt: presenceData.lastSeenAt || null,
    timestamp: presenceData.timestamp || new Date().toISOString(),
  };

  // Broadcast to global presence listeners & open inbox sessions
  io.emit('user:presence_changed', payload);
  io.emit('presence:changed', payload);
  io.emit('user_presence_update', payload);
  io.emit('presence_update', payload);
  io.emit('user:presence', payload);
  io.emit('inbox:presence_update', payload);

  // Deliver directly to target user's personal channel
  io.to(`user:${userId}`).emit('user:presence_changed', payload);
  io.to(`user:${userId}`).emit('presence:self_update', payload);
}

export async function addSocketToRoom(roomId, userId, socketId, userInfo = null) {
  if (!roomId || !userId || !socketId) return { isFirstSocket: false, activeUserCount: 0 };

  try {
    await setUserActiveRoom(userId, roomId);
  } catch (_) {}

  const redisKey = `presence:room:${roomId}:user:${userId}`;
  const roomUsersKey = `presence:room:${roomId}:users`;
  const infoKey = `presence:room:${roomId}:user_info:${userId}`;

  if (redisClient.isOpen) {
    try {
      await redisClient.sAdd(redisKey, socketId);
      await redisClient.expire(redisKey, 86400);
      await redisClient.sAdd(roomUsersKey, userId);
      await redisClient.expire(roomUsersKey, 86400);

      if (userInfo) {
        await redisClient.set(infoKey, JSON.stringify({
          userId,
          displayName: userInfo.displayName || userInfo.name || `User_${String(userId).substring(0, 6)}`,
          avatarUrl: userInfo.avatarUrl || null,
          isGuest: Boolean(userInfo.isGuest || String(userId).startsWith('guest_')),
          joinedAt: userInfo.joinedAt || new Date().toISOString(),
        }), { EX: 86400 });
      }

      const count = await redisClient.sCard(redisKey);
      const activeUserCount = await redisClient.sCard(roomUsersKey);

      return {
        isFirstSocket: count === 1,
        socketCount: count,
        activeUserCount,
      };
    } catch (err) {
      // Fall through to in-memory fallback
    }
  }

  // In-memory fallback
  if (!memoryRoomUsers.has(roomId)) {
    memoryRoomUsers.set(roomId, new Map());
  }
  const userMap = memoryRoomUsers.get(roomId);
  if (!userMap.has(userId)) {
    userMap.set(userId, {
      sockets: new Set(),
      userInfo: userInfo ? {
        userId,
        displayName: userInfo.displayName || userInfo.name || `User_${String(userId).substring(0, 6)}`,
        avatarUrl: userInfo.avatarUrl || null,
        isGuest: Boolean(userInfo.isGuest || String(userId).startsWith('guest_')),
        joinedAt: userInfo.joinedAt || new Date().toISOString(),
      } : {
        userId,
        displayName: `User_${String(userId).substring(0, 6)}`,
        avatarUrl: null,
        isGuest: Boolean(String(userId).startsWith('guest_')),
        joinedAt: new Date().toISOString(),
      },
    });
  }

  const record = userMap.get(userId);
  const isFirst = record.sockets.size === 0;
  record.sockets.add(socketId);
  if (userInfo) {
    record.userInfo = {
      ...record.userInfo,
      ...userInfo,
      userId,
      isGuest: Boolean(userInfo.isGuest || String(userId).startsWith('guest_')),
    };
  }
  memorySocketMap.set(socketId, { roomId, userId });

  return {
    isFirstSocket: isFirst,
    socketCount: record.sockets.size,
    activeUserCount: userMap.size,
  };
}

export async function removeSocketFromRoom(roomId, userId, socketId) {
  if (!roomId || !userId || !socketId) return { isLastSocket: true, remainingSocketCount: 0, activeUserCount: 0 };

  const redisKey = `presence:room:${roomId}:user:${userId}`;
  const roomUsersKey = `presence:room:${roomId}:users`;
  const infoKey = `presence:room:${roomId}:user_info:${userId}`;

  if (redisClient.isOpen) {
    try {
      await redisClient.sRem(redisKey, socketId);
      const remainingSockets = await redisClient.sCard(redisKey);
      let isLast = false;

      if (remainingSockets === 0) {
        isLast = true;
        await redisClient.del(redisKey);
        await redisClient.del(infoKey);
        await redisClient.sRem(roomUsersKey, userId);
        try {
          await clearUserActiveRoom(userId, roomId);
        } catch (_) {}
      }

      const activeUserCount = await redisClient.sCard(roomUsersKey);

      return {
        isLastSocket: isLast,
        remainingSocketCount: remainingSockets,
        activeUserCount,
      };
    } catch (err) {
      // Fall through to memory
    }
  }

  // In-memory fallback
  memorySocketMap.delete(socketId);
  const userMap = memoryRoomUsers.get(roomId);
  if (!userMap) return { isLastSocket: true, remainingSocketCount: 0, activeUserCount: 0 };

  const record = userMap.get(userId);
  if (!record) return { isLastSocket: true, remainingSocketCount: 0, activeUserCount: userMap.size };

  record.sockets.delete(socketId);
  const remaining = record.sockets.size;
  const isLast = remaining === 0;

  if (isLast) {
    userMap.delete(userId);
    try {
      await clearUserActiveRoom(userId, roomId);
    } catch (_) {}
  }
  if (userMap.size === 0) {
    memoryRoomUsers.delete(roomId);
  }

  return {
    isLastSocket: isLast,
    remainingSocketCount: remaining,
    activeUserCount: userMap ? userMap.size : 0,
  };
}

export async function getRoomActiveUserCount(roomId) {
  if (!roomId) return 0;
  const roomUsersKey = `presence:room:${roomId}:users`;

  if (redisClient.isOpen) {
    try {
      return await redisClient.sCard(roomUsersKey);
    } catch (err) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  return userMap ? userMap.size : 0;
}

/**
 * Authoritative viewer count calculation:
 * Distinct active users in the room, excluding the active host/creator.
 */
export async function getRoomViewerCount(roomId, hostUserId = null) {
  if (!roomId) return 0;
  const roomUsersKey = `presence:room:${roomId}:users`;

  if (redisClient.isOpen) {
    try {
      const totalUsers = await redisClient.sCard(roomUsersKey);
      if (hostUserId) {
        const isHostActive = await redisClient.sIsMember(roomUsersKey, hostUserId);
        return isHostActive ? Math.max(0, totalUsers - 1) : totalUsers;
      }
      return totalUsers;
    } catch (err) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  if (!userMap) return 0;
  const total = userMap.size;
  if (hostUserId && userMap.has(hostUserId)) {
    return Math.max(0, total - 1);
  }
  return total;
}

/**
 * Returns list of active users/participants currently in the room (both registered and guests).
 */
export async function getRoomActiveUsers(roomId) {
  if (!roomId) return [];
  const roomUsersKey = `presence:room:${roomId}:users`;

  if (redisClient.isOpen) {
    try {
      const userIds = await redisClient.sMembers(roomUsersKey);
      const result = [];
      for (const uId of userIds) {
        const infoKey = `presence:room:${roomId}:user_info:${uId}`;
        const raw = await redisClient.get(infoKey);
        if (raw) {
          try {
            result.push(JSON.parse(raw));
            continue;
          } catch (_) {}
        }
        result.push({
          userId: uId,
          displayName: String(uId).startsWith('guest_')
            ? `User_${String(uId).replace('guest_', '').substring(0, 5)}`
            : `User_${String(uId).substring(0, 6)}`,
          avatarUrl: null,
          isGuest: Boolean(String(uId).startsWith('guest_')),
          joinedAt: new Date().toISOString(),
        });
      }
      return result;
    } catch (err) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  if (!userMap) return [];
  return Array.from(userMap.values()).map((v) => v.userInfo).filter(Boolean);
}

export async function isUserInRoom(roomId, userId) {
  if (!roomId || !userId) return false;
  const roomUsersKey = `presence:room:${roomId}:users`;

  if (redisClient.isOpen) {
    try {
      return Boolean(await redisClient.sIsMember(roomUsersKey, userId));
    } catch (err) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  return Boolean(userMap && userMap.has(userId));
}

export async function clearRoomPresence(roomId) {
  if (!roomId) return;

  if (redisClient.isOpen) {
    try {
      const roomUsersKey = `presence:room:${roomId}:users`;
      const users = await redisClient.sMembers(roomUsersKey);
      for (const uId of users) {
        await redisClient.del(`presence:room:${roomId}:user:${uId}`);
        await redisClient.del(`presence:room:${roomId}:user_info:${uId}`);
        // Clear active room pointer for users who had this room set
        const userRoom = await redisClient.get(`presence:user:${uId}:room`);
        if (userRoom === String(roomId)) {
          await redisClient.del(`presence:user:${uId}:room`);
        }
      }
      await redisClient.del(roomUsersKey);
    } catch (err) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  if (userMap) {
    for (const uId of userMap.keys()) {
      if (memoryUserRoom.get(uId) === String(roomId)) {
        memoryUserRoom.delete(uId);
      }
    }
  }

  memoryRoomUsers.delete(roomId);
}

export async function leaveRoomPresence(roomId, userId) {
  if (!roomId || !userId) return;
  const uId = String(userId);
  await clearUserActiveRoom(uId, roomId);

  const roomUsersKey = `presence:room:${roomId}:users`;
  const infoKey = `presence:room:${roomId}:user_info:${uId}`;
  const userKey = `presence:room:${roomId}:user:${uId}`;

  if (redisClient.isOpen) {
    try {
      await redisClient.sRem(roomUsersKey, uId);
      await redisClient.del(infoKey);
      await redisClient.del(userKey);
    } catch (_) {}
  }

  const userMap = memoryRoomUsers.get(roomId);
  if (userMap) {
    userMap.delete(uId);
    if (userMap.size === 0) {
      memoryRoomUsers.delete(roomId);
    }
  }
}

export async function setRoomFeedClearedAt(roomId, timestamp = new Date().toISOString()) {
  if (!roomId) return null;
  const rId = String(roomId);
  const ts = typeof timestamp === 'string' ? timestamp : new Date(timestamp).toISOString();

  if (redisClient.isOpen) {
    try {
      await redisClient.set(`presence:room:${rId}:feed_cleared_at`, ts, { EX: 86400 * 7 });
    } catch (_) {}
  }
  memoryRoomFeedCleared.set(rId, ts);
  return ts;
}

export async function getRoomFeedClearedAt(roomId) {
  if (!roomId) return null;
  const rId = String(roomId);

  if (redisClient.isOpen) {
    try {
      const val = await redisClient.get(`presence:room:${rId}:feed_cleared_at`);
      if (val) return val;
    } catch (_) {}
  }
  return memoryRoomFeedCleared.get(rId) || null;
}

export default {
  registerUserSocket,
  unregisterUserSocket,
  hasActiveSocket,
  getUserSocketCount,
  setUserActiveRoom,
  clearUserActiveRoom,
  getUserActiveRoom,
  getUserLastSeen,
  clearUserPresence,
  getUserPresence,
  broadcastPresenceChange,
  addSocketToRoom,
  removeSocketFromRoom,
  leaveRoomPresence,
  getRoomActiveUserCount,
  getRoomViewerCount,
  getRoomActiveUsers,
  isUserInRoom,
  clearRoomPresence,
  setRoomFeedClearedAt,
  getRoomFeedClearedAt,
};
