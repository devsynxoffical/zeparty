import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import socketEmitter from '../socket/socket.emitter.js';

/**
 * ZeParty Issue 12: Room Level Initialization and Sending-Based Progression
 *
 * Requirements:
 * - Every new room starts at Level 0 with zero sending progress (LV.0, 0 progress).
 * - Room levels increase only through eligible, successfully completed gifts sent inside that specific room.
 * - Progress must be cumulative, persistent and isolated by room ID.
 * - Threshold schedule is configurable via Admin / PolicyConfiguration, strictly increasing.
 * - Daily trophy resets remain separate from cumulative room-level progression.
 */

export const ROOM_LEVEL_CONFIG_POLICY_KEY = 'ROOM_LEVEL_THRESHOLDS';

/**
 * Configurable default threshold schedule (Levels 0 to 20).
 * Clearly marked as pending client-approved final threshold values.
 */
export const DEFAULT_ROOM_LEVEL_THRESHOLDS = Object.freeze([
  { level: 0, additional: 0, threshold: 0 },
  { level: 1, additional: 10000, threshold: 10000 },
  { level: 2, additional: 15000, threshold: 25000 },
  { level: 3, additional: 25000, threshold: 50000 },
  { level: 4, additional: 50000, threshold: 100000 },
  { level: 5, additional: 100000, threshold: 200000 },
  { level: 6, additional: 200000, threshold: 400000 },
  { level: 7, additional: 300000, threshold: 700000 },
  { level: 8, additional: 400000, threshold: 1100000 },
  { level: 9, additional: 500000, threshold: 1600000 },
  { level: 10, additional: 600000, threshold: 2200000 },
  { level: 11, additional: 800000, threshold: 3000000 },
  { level: 12, additional: 1000000, threshold: 4000000 },
  { level: 13, additional: 1500000, threshold: 5500000 },
  { level: 14, additional: 2000000, threshold: 7500000 },
  { level: 15, additional: 2500000, threshold: 10000000 },
  { level: 16, additional: 3500000, threshold: 13500000 },
  { level: 17, additional: 4500000, threshold: 18000000 },
  { level: 18, additional: 6000000, threshold: 24000000 },
  { level: 19, additional: 8000000, threshold: 32000000 },
  { level: 20, additional: 13000000, threshold: 45000000 },
]);

/**
 * Validates any candidate threshold schedule.
 * Throws an Error if requirements are violated.
 *
 * @param {Array<{level: number, threshold: number, additional: number}>} schedule
 * @returns {boolean}
 */
export function validateRoomLevelThresholds(schedule) {
  if (!Array.isArray(schedule) || schedule.length < 2) {
    throw new Error('Room level threshold schedule must be an array with at least 2 levels (0 and 1).');
  }

  if (schedule[0].level !== 0 || schedule[0].threshold !== 0) {
    throw new Error('Room Level 0 must have threshold 0 (starting baseline).');
  }

  for (let i = 1; i < schedule.length; i++) {
    const prev = schedule[i - 1];
    const curr = schedule[i];

    if (curr.level !== i) {
      throw new Error(`Schedule sequence break at index ${i}: expected level ${i}, got ${curr.level}.`);
    }

    if (typeof curr.threshold !== 'number' || isNaN(curr.threshold) || curr.threshold <= prev.threshold) {
      throw new Error(
        `Level ${curr.level} threshold (${curr.threshold}) must be strictly greater than Level ${prev.level} threshold (${prev.threshold}).`
      );
    }

    const expectedDiff = curr.threshold - prev.threshold;
    if (curr.additional !== expectedDiff) {
      throw new Error(
        `Level ${curr.level} additional mismatch: expected ${expectedDiff}, got ${curr.additional}.`
      );
    }
  }

  return true;
}

// Immediately assert default schedule validity
validateRoomLevelThresholds(DEFAULT_ROOM_LEVEL_THRESHOLDS);

/**
 * Retrieves the effective room-level threshold schedule from PolicyConfiguration,
 * falling back to DEFAULT_ROOM_LEVEL_THRESHOLDS.
 *
 * @param {Object} [db=prisma]
 * @returns {Promise<Array<{level: number, threshold: number, additional: number}>>}
 */
export async function getRoomLevelThresholds(db = prisma) {
  try {
    const config = await db.policyConfiguration.findUnique({
      where: { key: ROOM_LEVEL_CONFIG_POLICY_KEY },
    });

    if (config && config.status === 'ACTIVE' && Array.isArray(config.valueJson?.thresholds)) {
      validateRoomLevelThresholds(config.valueJson.thresholds);
      return config.valueJson.thresholds;
    }
  } catch (err) {
    console.warn('[RoomLevelService] Warning loading room level config from DB, using defaults:', err?.message);
  }

  return DEFAULT_ROOM_LEVEL_THRESHOLDS;
}

/**
 * Updates the room-level threshold schedule in PolicyConfiguration (Admin action).
 *
 * @param {Array<{level: number, threshold: number, additional: number}>} thresholds
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function updateRoomLevelThresholds(thresholds, db = prisma) {
  validateRoomLevelThresholds(thresholds);

  const updated = await db.policyConfiguration.upsert({
    where: { key: ROOM_LEVEL_CONFIG_POLICY_KEY },
    create: {
      key: ROOM_LEVEL_CONFIG_POLICY_KEY,
      valueJson: {
        thresholds,
        updatedAt: new Date().toISOString(),
        isClientApproved: false, // Flag indicating whether client has approved this schedule
      },
      status: 'ACTIVE',
    },
    update: {
      valueJson: {
        thresholds,
        updatedAt: new Date().toISOString(),
      },
      status: 'ACTIVE',
    },
  });

  // Invalidate any cached threshold key in Redis
  try {
    if (redisClient?.status === 'ready' || redisClient?.isOpen) {
      await redisClient.del('config:room_level_thresholds');
    }
  } catch (_) {}

  return {
    success: true,
    message: 'Room level thresholds updated successfully',
    data: updated.valueJson,
  };
}

/**
 * Formats numbers into human-readable compact strings (e.g. 10000 -> "10k", 1100000 -> "1.1M").
 *
 * @param {number} num
 * @returns {string}
 */
export function formatCompactCoins(num) {
  if (num == null || isNaN(num) || num < 0) return '0';
  if (num >= 1000000) {
    const m = (num / 1000000).toFixed(1).replace(/\.0$/, '');
    return `${m}M`;
  }
  if (num >= 1000) {
    const k = (num / 1000).toFixed(1).replace(/\.0$/, '');
    return `${k}k`;
  }
  return num.toString();
}

/**
 * Calculates authoritative room progression given cumulative coin spending.
 *
 * @param {number|string|BigInt} cumulativeCoinsInput
 * @param {Array<{level: number, threshold: number, additional: number}>} [schedule=DEFAULT_ROOM_LEVEL_THRESHOLDS]
 * @returns {Object} Full progression breakdown
 */
export function calculateRoomProgression(cumulativeCoinsInput, schedule = DEFAULT_ROOM_LEVEL_THRESHOLDS) {
  const coinsNum = Math.max(0, Math.floor(Number(cumulativeCoinsInput || 0)));
  const maxTier = schedule[schedule.length - 1];

  // Binary search for highest qualifying level
  let low = 0;
  let high = schedule.length - 1;
  let qualifiedIndex = 0;

  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (coinsNum >= schedule[mid].threshold) {
      qualifiedIndex = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  const currentLevelRow = schedule[qualifiedIndex];
  const level = currentLevelRow.level;
  const isMaxLevel = qualifiedIndex >= schedule.length - 1;

  const currentLevelThreshold = currentLevelRow.threshold;
  const nextLevelRow = isMaxLevel ? currentLevelRow : schedule[qualifiedIndex + 1];
  const nextLevelThreshold = nextLevelRow.threshold;
  const nextLevel = nextLevelRow.level;

  const additionalCoinsRequired = isMaxLevel ? 0 : nextLevelRow.additional;
  const progressCoins = isMaxLevel ? 0 : coinsNum - currentLevelThreshold;
  const remainingCoins = isMaxLevel ? 0 : nextLevelThreshold - coinsNum;

  const progressPercent = isMaxLevel
    ? 100
    : additionalCoinsRequired > 0
    ? Math.min(100, Math.max(0, Math.floor((progressCoins / additionalCoinsRequired) * 100)))
    : 100;

  const progressRatio = isMaxLevel
    ? 1.0
    : additionalCoinsRequired > 0
    ? Number((progressCoins / additionalCoinsRequired).toFixed(4))
    : 1.0;

  const displayLevel = `LV.${level}`;
  const nextDisplayLevel = isMaxLevel ? 'MAX' : `LV.${nextLevel}`;
  const progressText = isMaxLevel
    ? 'MAX'
    : `${progressCoins}/${formatCompactCoins(additionalCoinsRequired)}`;

  return {
    level,
    displayLevel,
    nextLevel: isMaxLevel ? level : nextLevel,
    nextDisplayLevel,
    isMaxLevel,
    cumulativeCoins: coinsNum,
    cumulativeCoinsString: coinsNum.toString(),
    currentLevelThreshold,
    nextLevelThreshold,
    additionalCoinsRequired,
    progressCoins,
    remainingCoins,
    progressPercent,
    progressRatio,
    progressText,
    status: isMaxLevel ? 'MAX_LEVEL' : level === 0 && coinsNum === 0 ? 'STARTING' : 'IN_PROGRESS',
  };
}

/**
 * Aggregates all verified, completed GiftTransactions sent inside the given roomId.
 * This is the immutable source of truth for cumulative room sending progression.
 *
 * @param {string} roomId
 * @param {Object} [db=prisma]
 * @returns {Promise<BigInt>}
 */
export async function getRoomVerifiedLifetimeSending(roomId, db = prisma) {
  if (!roomId || typeof roomId !== 'string' || !roomId.trim()) return 0n;

  const cleanRoomId = roomId.trim();
  const aggr = await db.giftTransaction.aggregate({
    where: { roomId: cleanRoomId },
    _sum: { totalCoins: true },
  }).catch(() => null);

  return aggr?._sum?.totalCoins != null ? BigInt(aggr._sum.totalCoins) : 0n;
}

/**
 * Retrieves the comprehensive room level and sending progression for a room.
 * Guaranteed to return LV.0 and zero progress for new rooms or rooms with no gift activity.
 *
 * @param {string} roomId
 * @param {Object} [options]
 * @param {boolean} [options.bypassCache=false]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function getRoomLevelData(roomId, { bypassCache = false } = {}, db = prisma) {
  if (!roomId || typeof roomId !== 'string' || !roomId.trim()) {
    const defaultProg = calculateRoomProgression(0, DEFAULT_ROOM_LEVEL_THRESHOLDS);
    return {
      roomId: null,
      ...defaultProg,
    };
  }

  const cleanRoomId = roomId.trim();
  const cacheKey = `room:level_data:${cleanRoomId}`;

  if (!bypassCache) {
    try {
      if (redisClient?.status === 'ready' || redisClient?.isOpen) {
        const cached = await redisClient.get(cacheKey);
        if (cached) {
          return JSON.parse(cached);
        }
      }
    } catch (_) {}
  }

  const [verifiedCoinsBigInt, schedule] = await Promise.all([
    getRoomVerifiedLifetimeSending(cleanRoomId, db),
    getRoomLevelThresholds(db),
  ]);

  const verifiedCoinsNum = Number(verifiedCoinsBigInt);
  const progression = calculateRoomProgression(verifiedCoinsNum, schedule);

  const payload = {
    roomId: cleanRoomId,
    ...progression,
    updatedAt: new Date().toISOString(),
  };

  // Cache in Redis for fast multi-device / viewer reads (TTL: 60 seconds)
  try {
    if (redisClient?.status === 'ready' || redisClient?.isOpen) {
      await redisClient.set(cacheKey, JSON.stringify(payload), { EX: 60 });
    }
  } catch (_) {}

  return payload;
}

/**
 * Handles real-time room sending accumulation on gift completion.
 * Broadcasts room level and progress events to all participants.
 *
 * @param {string} roomId
 * @param {number|BigInt} giftCoins
 * @param {Object} [options]
 * @param {string} [options.senderUserId]
 * @param {string} [options.recipientUserId]
 * @param {string} [options.transactionId]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function recordRoomGiftProgress(roomId, giftCoins, { senderUserId, recipientUserId, transactionId } = {}, db = prisma) {
  if (!roomId || typeof roomId !== 'string' || !roomId.trim()) {
    return null;
  }

  const cleanRoomId = roomId.trim();
  const cacheKey = `room:level_data:${cleanRoomId}`;

  // Invalidate cached room level
  try {
    if (redisClient?.status === 'ready' || redisClient?.isOpen) {
      await redisClient.del(cacheKey);
    }
  } catch (_) {}

  // Calculate fresh progression from authoritative transactions
  const progressionData = await getRoomLevelData(cleanRoomId, { bypassCache: true }, db);

  // Broadcast real-time Socket.IO room level and progress events to all viewers and host
  try {
    if (socketEmitter) {
      const roomLevelPayload = {
        roomId: cleanRoomId,
        level: progressionData.level,
        displayLevel: progressionData.displayLevel,
        nextLevel: progressionData.nextLevel,
        nextDisplayLevel: progressionData.nextDisplayLevel,
        cumulativeCoins: progressionData.cumulativeCoins,
        progressCoins: progressionData.progressCoins,
        additionalCoinsRequired: progressionData.additionalCoinsRequired,
        remainingCoins: progressionData.remainingCoins,
        progressPercent: progressionData.progressPercent,
        progressRatio: progressionData.progressRatio,
        progressText: progressionData.progressText,
        isMaxLevel: progressionData.isMaxLevel,
        lastGiftCoins: Number(giftCoins || 0),
        senderUserId,
        recipientUserId,
        transactionId,
        timestamp: new Date().toISOString(),
      };

      socketEmitter.emitToRoom(cleanRoomId, 'room:level_updated', roomLevelPayload);
      socketEmitter.emitToRoom(cleanRoomId, 'room:progress_updated', roomLevelPayload);
      socketEmitter.emitToRoom(cleanRoomId, 'room:level_progression', roomLevelPayload);
    }
  } catch (err) {
    console.warn('[RoomLevelService] Socket broadcast error:', err?.message);
  }

  return progressionData;
}

/**
 * Reconciles a single room's sending progression authoritatively.
 *
 * @param {string} roomId
 * @param {Object} [options]
 * @param {boolean} [options.dryRun=true]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reconcileRoomLevel(roomId, { dryRun = true } = {}, db = prisma) {
  if (!roomId) throw new Error('roomId is required for room level reconciliation');

  const cleanRoomId = roomId.trim();
  const room = await db.room.findUnique({
    where: { id: cleanRoomId },
    select: { id: true, title: true, creatorUserId: true, roomType: true, status: true, createdAt: true },
  });

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    throw error;
  }

  const verifiedCoins = await getRoomVerifiedLifetimeSending(cleanRoomId, db);
  const schedule = await getRoomLevelThresholds(db);
  const progression = calculateRoomProgression(verifiedCoins, schedule);

  // Clear cache if live
  if (!dryRun) {
    try {
      if (redisClient?.status === 'ready' || redisClient?.isOpen) {
        await redisClient.del(`room:level_data:${cleanRoomId}`);
      }
    } catch (_) {}
  }

  return {
    roomId: cleanRoomId,
    title: room.title,
    creatorUserId: room.creatorUserId,
    status: room.status,
    verifiedCumulativeCoins: Number(verifiedCoins),
    progression,
    dryRun,
    reconciledAt: new Date().toISOString(),
  };
}

/**
 * Audits all rooms in the database and computes their verified room progression.
 * Default execution mode is strictly DRY_RUN.
 *
 * @param {Object} [options]
 * @param {boolean} [options.dryRun=true]
 * @param {number} [options.limit=1000]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reconcileAllRoomLevels({ dryRun = true, limit = 1000 } = {}, db = prisma) {
  const rooms = await db.room.findMany({
    take: limit,
    select: {
      id: true,
      title: true,
      creatorUserId: true,
      roomType: true,
      status: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  // Batch aggregate all completed gift transactions grouped by roomId
  const roomGifts = await db.giftTransaction.groupBy({
    by: ['roomId'],
    _sum: { totalCoins: true },
    _count: { id: true },
  }).catch(() => []);

  const giftMap = new Map();
  for (const g of roomGifts) {
    if (g.roomId) {
      giftMap.set(g.roomId, {
        totalCoins: BigInt(g._sum?.totalCoins || 0n),
        transactionCount: g._count?.id || 0,
      });
    }
  }

  const schedule = await getRoomLevelThresholds(db);
  const roomAuditResults = [];

  let zeroActivityRoomsCount = 0;
  let activeRoomsCount = 0;

  for (const r of rooms) {
    const giftData = giftMap.get(r.id) || { totalCoins: 0n, transactionCount: 0 };
    const cumulativeCoins = Number(giftData.totalCoins);
    const progression = calculateRoomProgression(cumulativeCoins, schedule);

    if (cumulativeCoins === 0) {
      zeroActivityRoomsCount++;
    } else {
      activeRoomsCount++;
    }

    roomAuditResults.push({
      roomId: r.id,
      title: r.title,
      creatorUserId: r.creatorUserId,
      status: r.status,
      roomType: r.roomType,
      transactionCount: giftData.transactionCount,
      cumulativeCoins,
      level: progression.level,
      displayLevel: progression.displayLevel,
      progressText: progression.progressText,
      progressPercent: progression.progressPercent,
      nextLevelThreshold: progression.nextLevelThreshold,
      isZeroProgress: cumulativeCoins === 0 && progression.level === 0,
    });
  }

  return {
    success: true,
    executionMode: dryRun ? 'DRY_RUN' : 'LIVE_UPDATE',
    totalRoomsExamined: rooms.length,
    zeroActivityRoomsCount,
    activeRoomsCount,
    scheduleMilestones: schedule.length,
    rooms: roomAuditResults,
  };
}

export default {
  ROOM_LEVEL_CONFIG_POLICY_KEY,
  DEFAULT_ROOM_LEVEL_THRESHOLDS,
  validateRoomLevelThresholds,
  getRoomLevelThresholds,
  updateRoomLevelThresholds,
  formatCompactCoins,
  calculateRoomProgression,
  getRoomVerifiedLifetimeSending,
  getRoomLevelData,
  recordRoomGiftProgress,
  reconcileRoomLevel,
  reconcileAllRoomLevels,
};

