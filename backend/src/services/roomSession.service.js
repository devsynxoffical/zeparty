import prisma from '../config/database.js';
import crypto from 'crypto';

/**
 * Authoritative Party Room Session Score & Lifecycle Service
 *
 * Implements strict session-based score aggregation and lifecycle boundaries:
 * - When a Party room is sleeping (status != 'LIVE'), its session score is 0.
 * - When a sleeping room wakes or a new session starts, a new activeSessionId & sessionStartedAt are created.
 * - Gifts are isolated to the active session; gifts from prior sleeping sessions cannot contribute.
 * - When participants leave and rejoin while the room remains awake, the session score is preserved.
 * - Concurrency-safe: multiple concurrent wake requests atomically join the single active session.
 */

/**
 * Calculates the authoritative gifting score for a room's active session.
 *
 * @param {string|Object} roomOrRoomId - Room ID or Room record
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>} Authoritative score snapshot
 */
export async function getAuthoritativeRoomSessionScore(roomOrRoomId, db = prisma) {
  let room = null;
  const roomId = typeof roomOrRoomId === 'object' && roomOrRoomId !== null ? roomOrRoomId.id : roomOrRoomId;

  if (typeof roomOrRoomId === 'object' && roomOrRoomId !== null && roomOrRoomId.status) {
    room = roomOrRoomId;
  } else if (roomId) {
    try {
      room = await db.room.findUnique({
        where: { id: roomId },
        select: {
          id: true,
          roomType: true,
          status: true,
          activeSessionId: true,
          sessionStartedAt: true,
          createdAt: true,
        },
      });
    } catch (err) {
      console.warn(`[RoomSessionService] Error fetching room for score (${roomId}):`, err?.message);
    }
  }

  if (!room) {
    return {
      roomId: roomId || null,
      sessionId: null,
      sessionStartedAt: null,
      sessionScore: 0,
      roomSendingTotal: 0,
      dailySendingTotal: 0,
      trophyCoins: 0,
      totalCoins: 0,
      totalGifts: 0,
      giftsReceivedCoins: 0,
      transactionCount: 0,
      isSleeping: true,
      status: 'NOT_FOUND',
    };
  }

  // If the room is sleeping or ended, active session score is 0
  const isLive = room.status === 'LIVE';
  if (!isLive) {
    return {
      roomId: room.id,
      sessionId: null,
      sessionStartedAt: null,
      sessionScore: 0,
      roomSendingTotal: 0,
      dailySendingTotal: 0,
      trophyCoins: 0,
      totalCoins: 0,
      totalGifts: 0,
      giftsReceivedCoins: 0,
      transactionCount: 0,
      isSleeping: true,
      status: room.status,
    };
  }

  // Build boundary condition: isolate gifts to current active session
  const whereCondition = { roomId: room.id };
  if (room.activeSessionId && room.sessionStartedAt) {
    whereCondition.OR = [
      { sessionId: room.activeSessionId },
      {
        AND: [
          { sessionId: null },
          { createdAt: { gte: room.sessionStartedAt } },
        ],
      },
    ];
  } else if (room.activeSessionId) {
    whereCondition.sessionId = room.activeSessionId;
  } else if (room.sessionStartedAt) {
    whereCondition.createdAt = { gte: room.sessionStartedAt };
  } else if (room.createdAt) {
    whereCondition.createdAt = { gte: room.createdAt };
  }

  let sessionTotal = 0;
  let txCount = 0;
  try {
    const aggr = await db.giftTransaction.aggregate({
      where: whereCondition,
      _sum: { totalCoins: true },
      _count: { id: true },
    });
    sessionTotal = Number(aggr._sum?.totalCoins || 0);
    txCount = Number(aggr._count?.id || 0);
  } catch (err) {
    console.warn(`[RoomSessionService] Error calculating score for room ${room.id}:`, err?.message);
  }

  return {
    roomId: room.id,
    sessionId: room.activeSessionId || null,
    sessionStartedAt: room.sessionStartedAt ? new Date(room.sessionStartedAt).toISOString() : null,
    sessionScore: sessionTotal,
    roomSendingTotal: sessionTotal,
    dailySendingTotal: sessionTotal,
    trophyCoins: sessionTotal,
    totalCoins: sessionTotal,
    totalGifts: sessionTotal,
    giftsReceivedCoins: sessionTotal,
    transactionCount: txCount,
    isSleeping: false,
    status: room.status,
  };
}

/**
 * Concurrency-safe activation of a room session.
 * If the room is sleeping (status != 'LIVE'), starts a fresh session with a new activeSessionId & sessionStartedAt.
 * If the room is already LIVE, retains the active session without overwriting.
 *
 * @param {string} roomId
 * @param {Object} [options]
 * @param {boolean} [options.forceNew=false]
 * @param {Object} [db=prisma]
 * @returns {Promise<{ room: Object, isNewSession: boolean }>}
 */
export async function ensureActiveRoomSession(roomId, { forceNew = false } = {}, db = prisma) {
  if (!roomId) throw new Error('roomId is required');

  const current = await db.room.findUnique({
    where: { id: roomId },
    select: { id: true, status: true, activeSessionId: true, sessionStartedAt: true },
  });

  if (!current) {
    const err = new Error('Room not found');
    err.statusCode = 404;
    err.code = 'ROOM_NOT_FOUND';
    throw err;
  }

  const isAlreadyLive = current.status === 'LIVE' && current.activeSessionId;

  if (isAlreadyLive && !forceNew) {
    return {
      room: current,
      isNewSession: false,
      sessionId: current.activeSessionId,
      sessionStartedAt: current.sessionStartedAt,
    };
  }

  // Reject activation if room was closed by administration or moderation
  if (['CLOSED_BY_ADMIN', 'HOST_KICKED'].includes(current.status)) {
    const err = new Error('Room is closed by moderation and cannot be activated');
    err.statusCode = 403;
    err.code = 'ROOM_CLOSED_BY_ADMIN';
    throw err;
  }

  // Only legitimately sleeping rooms (ENDED) or forced new sessions are eligible to activate
  if (current.status !== 'ENDED' && !forceNew) {
    const err = new Error(`Room cannot be activated from status: ${current.status}`);
    err.statusCode = 400;
    err.code = 'ROOM_NOT_ELIGIBLE_FOR_WAKE';
    throw err;
  }

  // Generate new session tokens
  const newSessionId = crypto.randomUUID();
  const sessionStartedAt = new Date();

  // Concurrency-safe atomic conditional update:
  // Only transitions legitimately sleeping rooms (status === 'ENDED')
  if (forceNew) {
    await db.room.update({
      where: { id: roomId },
      data: {
        status: 'LIVE',
        endedAt: null,
        activeSessionId: newSessionId,
        sessionStartedAt,
      },
    });
  } else {
    await db.room.updateMany({
      where: {
        id: roomId,
        status: 'ENDED', // Strictly restrict wake eligibility to ENDED
      },
      data: {
        status: 'LIVE',
        endedAt: null,
        activeSessionId: newSessionId,
        sessionStartedAt,
      },
    });
  }

  const refreshed = await db.room.findUnique({
    where: { id: roomId },
  });

  // Verify the room's current state post-update
  if (!refreshed || refreshed.status !== 'LIVE') {
    if (['CLOSED_BY_ADMIN', 'HOST_KICKED'].includes(refreshed?.status)) {
      const err = new Error('Room is closed by moderation and cannot be activated');
      err.statusCode = 403;
      err.code = 'ROOM_CLOSED_BY_ADMIN';
      throw err;
    }
    const err = new Error('Failed to activate room session');
    err.statusCode = 400;
    err.code = 'ROOM_ACTIVATION_FAILED';
    throw err;
  }

  return {
    room: refreshed,
    isNewSession: refreshed.activeSessionId === newSessionId,
    sessionId: refreshed.activeSessionId,
    sessionStartedAt: refreshed.sessionStartedAt,
  };
}

/**
 * Transitions a room to sleeping / inactive state and seals the active session.
 *
 * @param {string} roomId
 * @param {string} [reason='ALL_PARTICIPANTS_LEFT']
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function transitionRoomToSleeping(roomId, reason = 'ALL_PARTICIPANTS_LEFT', db = prisma) {
  if (!roomId) return null;

  const endedAt = new Date();
  await db.room.updateMany({
    where: { id: roomId, status: 'LIVE' },
    data: {
      status: 'ENDED',
      endedAt,
      lastSessionEndedAt: endedAt,
      currentViewersCount: 0,
    },
  });

  return await db.room.findUnique({ where: { id: roomId } });
}

export default {
  getAuthoritativeRoomSessionScore,
  ensureActiveRoomSession,
  transitionRoomToSleeping,
};

