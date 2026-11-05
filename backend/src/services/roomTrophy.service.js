import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import socketEmitter from '../socket/socket.emitter.js';

/**
 * Computes the authoritative daily ranking and trophy period boundaries (UTC).
 * Daily period starts at 00:00:00.000 UTC and ends at 23:59:59.999 UTC.
 *
 * @param {Date} [now=new Date()]
 * @returns {{ start: Date, end: Date, periodKey: string }}
 */
export function getRoomDailyPeriod(now = new Date()) {
  const start = new Date(now);
  start.setUTCHours(0, 0, 0, 0);

  const end = new Date(now);
  end.setUTCHours(23, 59, 59, 999);

  const dateStr = start.toISOString().split('T')[0];
  const periodKey = `daily_${dateStr}`;

  return {
    start,
    end,
    periodStart: start.toISOString(),
    periodEnd: end.toISOString(),
    periodKey,
  };
}

/**
 * Computes the authoritative room sending / trophy aggregate from completed GiftTransactions.
 * Directly queries the PostgreSQL ledger for completed transactions within the current period.
 * Caches in Redis with 60s TTL for fast concurrent responses.
 *
 * @param {string} roomId
 * @param {Object} [options]
 * @param {Date} [options.targetDate=new Date()]
 * @param {boolean} [options.skipCache=false]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getAuthoritativeRoomTrophy(
  roomId,
  { targetDate = new Date(), skipCache = false } = {},
  db = prisma
) {
  if (!roomId) {
    return {
      roomId: null,
      trophyCoins: 0,
      dailySendingTotal: 0,
      periodTotalCoins: 0,
      periodKey: null,
      status: 'EMPTY',
    };
  }

  const { start, end, periodKey } = getRoomDailyPeriod(targetDate);
  const cacheKey = `room:trophy:${roomId}:${periodKey}`;

  // 1. Try Redis cache if available and not skipped
  if (!skipCache) {
    try {
      if (redisClient && redisClient.isOpen) {
        const cached = await redisClient.get(cacheKey);
        if (cached) {
          const parsed = JSON.parse(cached);
          return {
            ...parsed,
            fromCache: true,
          };
        }
      }
    } catch (_) {}
  }

  // 2. Query authoritative completed transactions from database ledger
  let totalCoinsNum = 0;
  let transactionCount = 0;

  try {
    const aggr = await db.giftTransaction.aggregate({
      where: {
        roomId,
        createdAt: {
          gte: start,
          lte: end,
        },
      },
      _sum: { totalCoins: true },
      _count: { id: true },
    });

    totalCoinsNum = Number(aggr._sum?.totalCoins || 0);
    transactionCount = aggr._count?.id || 0;
  } catch (err) {
    console.warn(`[RoomTrophyService] Database error calculating trophy for ${roomId}:`, err?.message);
  }

  const formattedDisplay = Number(totalCoinsNum).toLocaleString('en-US');

  const result = {
    roomId,
    trophyCoins: totalCoinsNum,
    dailyCoins: totalCoinsNum,
    dailyTrophyCoins: totalCoinsNum,
    dailySendingTotal: totalCoinsNum,
    roomSendingTotal: totalCoinsNum,
    periodTotalCoins: totalCoinsNum,
    totalCoins: totalCoinsNum,
    trophyDisplay: formattedDisplay,
    dailyTrophyDisplay: formattedDisplay,
    transactionCount,
    periodStart: start.toISOString(),
    periodEnd: end.toISOString(),
    periodKey,
    status: 'AVAILABLE',
    isAudited: true,
    updatedAt: new Date().toISOString(),
  };

  // 3. Write to Redis cache with 60s TTL
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.setEx(cacheKey, 60, JSON.stringify(result));
    }
  } catch (_) {}

  return result;
}

/**
 * Invalidation and real-time broadcast triggered on every completed gift inside a room.
 *
 * @param {string} roomId
 * @param {number} coins
 * @param {Object} [txDetails]
 * @param {Object} [db=prisma]
 */
export async function recordRoomGiftTrophy(roomId, coins, txDetails = {}, db = prisma) {
  if (!roomId) return null;

  const { periodKey } = getRoomDailyPeriod();
  const cacheKey = `room:trophy:${roomId}:${periodKey}`;

  // Purge cache to force fresh calculation
  try {
    if (redisClient && redisClient.isOpen) {
      await redisClient.del(cacheKey);
    }
  } catch (_) {}

  // Recalculate authoritative total
  const updatedTrophy = await getAuthoritativeRoomTrophy(roomId, { skipCache: true }, db);

  // Broadcast realtime events to all connected clients in the room
  try {
    if (socketEmitter) {
      const payload = {
        roomId,
        trophyCoins: updatedTrophy.trophyCoins,
        dailySendingTotal: updatedTrophy.dailySendingTotal,
        roomSendingTotal: updatedTrophy.roomSendingTotal,
        periodTotalCoins: updatedTrophy.periodTotalCoins,
        transactionCount: updatedTrophy.transactionCount,
        addedCoins: Number(coins || 0),
        transactionId: txDetails?.id || null,
        timestamp: new Date().toISOString(),
      };

      socketEmitter.emitToRoom(roomId, 'room:trophy_updated', payload);
      socketEmitter.emitToRoom(roomId, 'room:progress_updated', payload);
    }
  } catch (_) {}

  return updatedTrophy;
}

/**
 * Reconciles Audio Party room historical sending records.
 * Finds fragmented party rooms belonging to a host and attributes or consolidates them
 * to the host's primary stable Audio Party room.
 *
 * @param {Object} [options]
 * @param {boolean} [options.dryRun=true]
 * @param {string} [options.targetUserId]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reconcileAudioPartyRooms({ dryRun = true, targetUserId = null } = {}, db = prisma) {
  const where = {
    roomType: 'AUDIO_PARTY',
    ...(targetUserId ? { creatorUserId: targetUserId } : {}),
  };

  const allAudioRooms = await db.room.findMany({
    where,
    include: {
      giftTransactions: {
        select: { id: true, totalCoins: true, createdAt: true },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  // Group rooms by creator
  const userRoomsMap = new Map();
  for (const r of allAudioRooms) {
    if (!userRoomsMap.has(r.creatorUserId)) {
      userRoomsMap.set(r.creatorUserId, []);
    }
    userRoomsMap.get(r.creatorUserId).push(r);
  }

  const reports = [];
  const now = new Date();
  const { start: todayStart } = getRoomDailyPeriod(now);

  for (const [creatorId, rooms] of userRoomsMap.entries()) {
    if (rooms.length <= 1) continue;

    // Identify primary party room: the one with the highest gift coins or earliest stable party room
    const sortedByCoins = [...rooms].sort((a, b) => {
      const aCoins = a.giftTransactions.reduce((sum, t) => sum + Number(t.totalCoins || 0), 0);
      const bCoins = b.giftTransactions.reduce((sum, t) => sum + Number(t.totalCoins || 0), 0);
      if (bCoins !== aCoins) return bCoins - aCoins;
      return new Date(a.createdAt) - new Date(b.createdAt);
    });

    const primaryRoom = sortedByCoins[0];
    const fragmentedRooms = rooms.filter((r) => r.id !== primaryRoom.id);

    // Sum transactions across fragmented rooms
    const fragmentedTxs = fragmentedRooms.flatMap((r) => r.giftTransactions);
    const fragmentedCoins = fragmentedTxs.reduce((sum, t) => sum + Number(t.totalCoins || 0), 0);

    const primaryCoins = primaryRoom.giftTransactions.reduce((sum, t) => sum + Number(t.totalCoins || 0), 0);
    const proposedTotalCoins = primaryCoins + fragmentedCoins;

    reports.push({
      creatorUserId: creatorId,
      primaryRoomId: primaryRoom.id,
      primaryRoomTitle: primaryRoom.title,
      totalRoomsCount: rooms.length,
      fragmentedRoomsCount: fragmentedRooms.length,
      primaryRoomCoins: primaryCoins,
      fragmentedCoins,
      proposedTotalCoins,
      fragmentedTransactionCount: fragmentedTxs.length,
      fragmentedRoomIds: fragmentedRooms.map((r) => r.id),
    });

    if (!dryRun && fragmentedTxs.length > 0) {
      // Re-attribute transactions from fragmented duplicate rooms to the primary room
      const txIds = fragmentedTxs.map((t) => t.id);
      await db.giftTransaction.updateMany({
        where: { id: { in: txIds } },
        data: { roomId: primaryRoom.id },
      });

      // Mark fragmented duplicate rooms as ENDED
      await db.room.updateMany({
        where: { id: { in: fragmentedRooms.map((r) => r.id) } },
        data: { status: 'ENDED', endedAt: now },
      });

      // Ensure primary room is LIVE or valid
      await db.room.update({
        where: { id: primaryRoom.id },
        data: { status: 'LIVE', endedAt: null },
      });
    }
  }

  const totalMigratedTxs = reports.reduce((sum, r) => sum + r.fragmentedTransactionCount, 0);
  const totalClosedRooms = reports.reduce((sum, r) => sum + r.fragmentedRoomsCount, 0);

  return {
    executionMode: dryRun ? 'DRY_RUN' : 'LIVE_UPDATE',
    hostsExamined: userRoomsMap.size,
    hostsWithFragmentedRooms: reports.length,
    migratedTransactionsCount: dryRun ? 0 : totalMigratedTxs,
    closedFragmentedRoomsCount: dryRun ? 0 : totalClosedRooms,
    reports,
  };
}

export default {
  getRoomDailyPeriod,
  getAuthoritativeRoomTrophy,
  recordRoomGiftTrophy,
  reconcileAudioPartyRooms,
};
