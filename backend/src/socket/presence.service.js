import redisClient from '../config/redis.js';

// Ephemeral in-memory fallback store when Redis is disconnected (e.g. isolated test environments)
// memoryRoomUsers: roomId -> Map<userId, { sockets: Set<socketId>, userInfo: object }>
const memoryRoomUsers = new Map();
// memorySocketMap: socketId -> { roomId, userId }
const memorySocketMap = new Map();

/**
 * Realtime Presence Service supporting multi-device / multi-socket connection tracking per user,
 * guest identity tracking, and authoritative room viewer count calculations.
 * 
 * Rules:
 * 1. Redis sets track active socket connections: key `presence:room:{roomId}:user:{userId}` -> Set<socketId>
 * 2. Key `presence:room:{roomId}:users` -> Set<userId> tracks distinct active users.
 * 3. Key `presence:room:{roomId}:user_info:{userId}` stores metadata (displayName, avatarUrl, isGuest).
 * 4. Multi-device safety: `isFirstSocket` indicates if user just entered (first connection).
 * 5. Disconnect safety: `isLastSocket` indicates if all devices/connections for this user have disconnected.
 * 6. Distinct user count tracks real active users, not raw socket counts.
 * 7. Viewer count calculates audience presence excluding the active room host.
 */

export async function addSocketToRoom(roomId, userId, socketId, userInfo = null) {
  if (!roomId || !userId || !socketId) return { isFirstSocket: false, activeUserCount: 0 };

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
      }
      await redisClient.del(roomUsersKey);
    } catch (err) {}
  }

  memoryRoomUsers.delete(roomId);
}

export default {
  addSocketToRoom,
  removeSocketFromRoom,
  getRoomActiveUserCount,
  getRoomViewerCount,
  getRoomActiveUsers,
  isUserInRoom,
  clearRoomPresence,
};
