/**
 * Authoritative Wealth Level Progression Service (Levels 1–100)
 *
 * Implements the complete revised 100-level sending threshold schedule
 * approved by the client / product owner (November 2026).
 *
 * Rules & Invariants:
 * - Level 1 starts at zero lifetime eligible sending.
 * - Maximum level is 100 (cumulative threshold: 250,000,000 coins).
 * - No Level 0, Level 101, or level > 100.
 * - Each Additional value equals the difference between current and preceding Total values.
 * - All server-side surfaces (Profile, Mini Profile, Level Center, Rankings, Room Seats)
 *   derive their level authoritatively from this service.
 */

import prisma from '../config/prisma.js';
import socketEmitter from '../socket/socket.emitter.js';
import redisClient from '../config/redis.js';

export const MAX_WEALTH_LEVEL = 100;
export const MAX_WEALTH_THRESHOLD = 250000000;

export const WEALTH_LEVEL_SCHEDULE = Object.freeze([
  { level: 1, additional: 0, total: 0 },
  { level: 2, additional: 10000, total: 10000 },
  { level: 3, additional: 20000, total: 30000 },
  { level: 4, additional: 40000, total: 70000 },
  { level: 5, additional: 67000, total: 137000 },
  { level: 6, additional: 97000, total: 234000 },
  { level: 7, additional: 129000, total: 363000 },
  { level: 8, additional: 163000, total: 526000 },
  { level: 9, additional: 198000, total: 724000 },
  { level: 10, additional: 235000, total: 959000 },
  { level: 11, additional: 273000, total: 1232000 },
  { level: 12, additional: 312000, total: 1544000 },
  { level: 13, additional: 352000, total: 1896000 },
  { level: 14, additional: 394000, total: 2290000 },
  { level: 15, additional: 436000, total: 2726000 },
  { level: 16, additional: 479000, total: 3205000 },
  { level: 17, additional: 523000, total: 3728000 },
  { level: 18, additional: 568000, total: 4296000 },
  { level: 19, additional: 614000, total: 4910000 },
  { level: 20, additional: 660000, total: 5570000 },
  { level: 21, additional: 707000, total: 6277000 },
  { level: 22, additional: 755000, total: 7032000 },
  { level: 23, additional: 804000, total: 7836000 },
  { level: 24, additional: 853000, total: 8689000 },
  { level: 25, additional: 903000, total: 9592000 },
  { level: 26, additional: 953000, total: 10545000 },
  { level: 27, additional: 1004000, total: 11549000 },
  { level: 28, additional: 1056000, total: 12605000 },
  { level: 29, additional: 1108000, total: 13713000 },
  { level: 30, additional: 1160000, total: 14873000 },
  { level: 31, additional: 1213000, total: 16086000 },
  { level: 32, additional: 1267000, total: 17353000 },
  { level: 33, additional: 1321000, total: 18674000 },
  { level: 34, additional: 1376000, total: 20050000 },
  { level: 35, additional: 1431000, total: 21481000 },
  { level: 36, additional: 1487000, total: 22968000 },
  { level: 37, additional: 1543000, total: 24511000 },
  { level: 38, additional: 1599000, total: 26110000 },
  { level: 39, additional: 1656000, total: 27766000 },
  { level: 40, additional: 1713000, total: 29479000 },
  { level: 41, additional: 1771000, total: 31250000 },
  { level: 42, additional: 1829000, total: 33079000 },
  { level: 43, additional: 1888000, total: 34967000 },
  { level: 44, additional: 1947000, total: 36914000 },
  { level: 45, additional: 2006000, total: 38920000 },
  { level: 46, additional: 2066000, total: 40986000 },
  { level: 47, additional: 2126000, total: 43112000 },
  { level: 48, additional: 2186000, total: 45298000 },
  { level: 49, additional: 2247000, total: 47545000 },
  { level: 50, additional: 2308000, total: 49853000 },
  { level: 51, additional: 2370000, total: 52223000 },
  { level: 52, additional: 2432000, total: 54655000 },
  { level: 53, additional: 2494000, total: 57149000 },
  { level: 54, additional: 2556000, total: 59705000 },
  { level: 55, additional: 2619000, total: 62324000 },
  { level: 56, additional: 2683000, total: 65007000 },
  { level: 57, additional: 2746000, total: 67753000 },
  { level: 58, additional: 2810000, total: 70563000 },
  { level: 59, additional: 2874000, total: 73437000 },
  { level: 60, additional: 2939000, total: 76376000 },
  { level: 61, additional: 3004000, total: 79380000 },
  { level: 62, additional: 3069000, total: 82449000 },
  { level: 63, additional: 3134000, total: 85583000 },
  { level: 64, additional: 3200000, total: 88783000 },
  { level: 65, additional: 3266000, total: 92049000 },
  { level: 66, additional: 3332000, total: 95381000 },
  { level: 67, additional: 3399000, total: 98780000 },
  { level: 68, additional: 3466000, total: 102246000 },
  { level: 69, additional: 3533000, total: 105779000 },
  { level: 70, additional: 3600000, total: 109379000 },
  { level: 71, additional: 3668000, total: 113047000 },
  { level: 72, additional: 3736000, total: 116783000 },
  { level: 73, additional: 3804000, total: 120587000 },
  { level: 74, additional: 3872000, total: 124459000 },
  { level: 75, additional: 3941000, total: 128400000 },
  { level: 76, additional: 4010000, total: 132410000 },
  { level: 77, additional: 4080000, total: 136490000 },
  { level: 78, additional: 4149000, total: 140639000 },
  { level: 79, additional: 4219000, total: 144858000 },
  { level: 80, additional: 4289000, total: 149147000 },
  { level: 81, additional: 4359000, total: 153506000 },
  { level: 82, additional: 4430000, total: 157936000 },
  { level: 83, additional: 4500000, total: 162436000 },
  { level: 84, additional: 4572000, total: 167008000 },
  { level: 85, additional: 4643000, total: 171651000 },
  { level: 86, additional: 4714000, total: 176365000 },
  { level: 87, additional: 4786000, total: 181151000 },
  { level: 88, additional: 4858000, total: 186009000 },
  { level: 89, additional: 4930000, total: 190939000 },
  { level: 90, additional: 5003000, total: 195942000 },
  { level: 91, additional: 5075000, total: 201017000 },
  { level: 92, additional: 5148000, total: 206165000 },
  { level: 93, additional: 5221000, total: 211386000 },
  { level: 94, additional: 5295000, total: 216681000 },
  { level: 95, additional: 5368000, total: 222049000 },
  { level: 96, additional: 5442000, total: 227491000 },
  { level: 97, additional: 5516000, total: 233007000 },
  { level: 98, additional: 5590000, total: 238597000 },
  { level: 99, additional: 5664000, total: 244261000 },
  { level: 100, additional: 5739000, total: 250000000 },
]);

/**
 * Validates the in-memory 100-level schedule. Throws an Error if any invariant fails.
 */
export function validateWealthSchedule() {
  if (WEALTH_LEVEL_SCHEDULE.length !== 100) {
    throw new Error(`WEALTH_LEVEL_SCHEDULE must contain exactly 100 levels, found ${WEALTH_LEVEL_SCHEDULE.length}`);
  }
  if (WEALTH_LEVEL_SCHEDULE[0].level !== 1 || WEALTH_LEVEL_SCHEDULE[0].total !== 0 || WEALTH_LEVEL_SCHEDULE[0].additional !== 0) {
    throw new Error(`Level 1 must have total 0 and additional 0`);
  }
  for (let i = 1; i < WEALTH_LEVEL_SCHEDULE.length; i++) {
    const prev = WEALTH_LEVEL_SCHEDULE[i - 1];
    const curr = WEALTH_LEVEL_SCHEDULE[i];
    if (curr.level !== i + 1) {
      throw new Error(`Schedule sequence break at index ${i}: expected level ${i + 1}, got ${curr.level}`);
    }
    if (curr.total <= prev.total) {
      throw new Error(`Level ${curr.level} total (${curr.total}) must be strictly greater than Level ${prev.level} (${prev.total})`);
    }
    const diff = curr.total - prev.total;
    if (curr.additional !== diff) {
      throw new Error(`Level ${curr.level} additional mismatch: expected ${diff}, got ${curr.additional}`);
    }
  }
  const maxRow = WEALTH_LEVEL_SCHEDULE[99];
  if (maxRow.level !== 100 || maxRow.total !== MAX_WEALTH_THRESHOLD) {
    throw new Error(`Level 100 total must be exactly ${MAX_WEALTH_THRESHOLD}, got ${maxRow.total}`);
  }
  return true;
}

// Run validation immediately on module load
validateWealthSchedule();

/**
 * Safely parses any numeric/BigInt/String coin representation into a non-negative number.
 *
 * @param {number|string|BigInt} val
 * @returns {number}
 */
export function normalizeCoinValue(val) {
  if (val == null) return 0;
  if (typeof val === 'bigint') {
    return Number(val < 0n ? 0n : val);
  }
  const n = Number(val);
  if (isNaN(n) || n < 0) return 0;
  return Math.floor(n);
}

/**
 * Calculates the authoritative Wealth level (1–100) for a given cumulative coin sending total.
 *
 * @param {number|string|BigInt} cumulativeCoins
 * @returns {number} Level integer between 1 and 100 (inclusive)
 */
export function calculateWealthLevel(cumulativeCoins) {
  const coins = normalizeCoinValue(cumulativeCoins);
  if (coins >= MAX_WEALTH_THRESHOLD) {
    return MAX_WEALTH_LEVEL;
  }
  if (coins <= 0) {
    return 1;
  }

  // Binary search for highest qualifying level
  let low = 0;
  let high = WEALTH_LEVEL_SCHEDULE.length - 1;
  let matchedIndex = 0;

  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (coins >= WEALTH_LEVEL_SCHEDULE[mid].total) {
      matchedIndex = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return WEALTH_LEVEL_SCHEDULE[matchedIndex].level;
}

/**
 * Calculates complete progression details for a user's lifetime eligible sending.
 *
 * @param {number|string|BigInt} cumulativeCoins
 * @returns {Object} Rich progression information for Level Center, Profile, and APIs
 */
export function calculateWealthProgression(cumulativeCoins) {
  const coins = normalizeCoinValue(cumulativeCoins);
  const coinsStr = String(cumulativeCoins != null ? cumulativeCoins : '0');

  if (coins >= MAX_WEALTH_THRESHOLD) {
    const maxRow = WEALTH_LEVEL_SCHEDULE[99];
    return {
      level: MAX_WEALTH_LEVEL,
      isMaxLevel: true,
      lifetimeSendingCoins: coinsStr,
      lifetimeSendingNumber: coins,
      currentLevelThreshold: maxRow.total,
      nextLevelThreshold: null,
      additionalCoinsRequired: 0,
      progressCoins: 0,
      remainingCoins: 0,
      progressPercent: 100,
      status: 'MAX',
      displayLevel: `Lv. ${MAX_WEALTH_LEVEL}`,
    };
  }

  const level = calculateWealthLevel(coins);
  const currIndex = level - 1;
  const currRow = WEALTH_LEVEL_SCHEDULE[currIndex];
  const nextRow = WEALTH_LEVEL_SCHEDULE[currIndex + 1];

  const currentLevelThreshold = currRow.total;
  const nextLevelThreshold = nextRow.total;
  const additionalCoinsRequired = nextRow.additional;
  const progressCoins = Math.max(0, coins - currentLevelThreshold);
  const remainingCoins = Math.max(0, nextLevelThreshold - coins);

  const progressPercent = additionalCoinsRequired > 0
    ? Math.min(100, Math.floor((progressCoins * 100) / additionalCoinsRequired))
    : 100;

  return {
    level,
    isMaxLevel: false,
    lifetimeSendingCoins: coinsStr,
    lifetimeSendingNumber: coins,
    currentLevelThreshold,
    nextLevelThreshold,
    additionalCoinsRequired,
    progressCoins,
    remainingCoins,
    progressPercent,
    status: 'IN_PROGRESS',
    displayLevel: `Lv. ${level}`,
  };
}

/**
 * Calculates authoritative lifetime eligible sending for a user directly from
 * completed GiftTransactions in the database.
 *
 * @param {string} userId
 * @param {Object} [db=prisma]
 * @returns {Promise<BigInt>}
 */
export async function getVerifiedLifetimeSending(userId, db = prisma) {
  if (!userId) return 0n;
  const aggr = await db.giftTransaction.aggregate({
    where: { senderUserId: userId },
    _sum: { totalCoins: true },
  }).catch(() => null);

  return aggr?._sum?.totalCoins != null ? BigInt(aggr._sum.totalCoins) : 0n;
}

/**
 * Authoritatively calculates and optionally updates a single user's Wealth Level.
 *
 * @param {string} userId
 * @param {Object} [options]
 * @param {boolean} [options.dryRun=true]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reconcileUserWealth(userId, { dryRun = true } = {}, db = prisma) {
  if (!userId) {
    throw new Error('userId is required for wealth reconciliation');
  }

  const profile = await db.userProfile.findUnique({
    where: { userId },
  });

  const verifiedSending = await getVerifiedLifetimeSending(userId, db);

  // Source of truth for sending: the verified transaction sum if transactions exist,
  // or existing experiencePoints if transactions were purged/archived but XP preserved.
  const storedXp = BigInt(profile?.experiencePoints || 0n);
  const authoritativeSending = verifiedSending > storedXp ? verifiedSending : storedXp;

  const previousLevel = profile?.level || 1;
  const progression = calculateWealthProgression(authoritativeSending);
  const correctedLevel = progression.level;
  const isChanged = previousLevel !== correctedLevel || storedXp !== authoritativeSending;

  let updatedProfile = profile;
  if (!dryRun && isChanged) {
    updatedProfile = await db.userProfile.upsert({
      where: { userId },
      update: {
        level: correctedLevel,
        experiencePoints: authoritativeSending,
        totalSpentCoins: authoritativeSending,
      },
      create: {
        userId,
        level: correctedLevel,
        experiencePoints: authoritativeSending,
        totalSpentCoins: authoritativeSending,
      },
    });

    // Invalidate Redis profile presence / user cache
    try {
      if (redisClient && redisClient.isOpen) {
        await redisClient.del(`user:presence:${userId}`).catch(() => {});
        await redisClient.del(`user:profile:${userId}`).catch(() => {});
      }
    } catch (_) {}

    // Emit realtime level update event if level changed
    try {
      if (socketEmitter) {
        const payload = {
          userId,
          wealthLevel: correctedLevel,
          level: correctedLevel,
          previousLevel,
          progress: progression,
          timestamp: new Date().toISOString(),
        };
        socketEmitter.emitToUser(userId, 'user:level_updated', payload);
        socketEmitter.emitToUser(userId, 'user:wealth_level_updated', payload);
      }
    } catch (_) {}
  }

  return {
    userId,
    dryRun,
    previousLevel,
    correctedLevel,
    isChanged,
    verifiedSendingCoins: verifiedSending.toString(),
    authoritativeSendingCoins: authoritativeSending.toString(),
    progression,
    updated: !dryRun && isChanged,
  };
}

/**
 * Runs a batch historical reconciliation of all UserProfiles across the system.
 * By default runs in DRY_RUN mode to inspect and audit without making mutations.
 *
 * @param {Object} [options]
 * @param {boolean} [options.dryRun=true]
 * @param {number} [options.limit=1000]
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reconcileAllUserWealthLevels({ dryRun = true, limit = 1000 } = {}, db = prisma) {
  const profiles = await db.userProfile.findMany({
    take: limit,
    include: {
      user: {
        select: { id: true, username: true, status: true },
      },
    },
    orderBy: { createdAt: 'asc' },
  });

  // Pre-aggregate all verified sending across all users in one batch query
  const sendingAggregates = await db.giftTransaction.groupBy({
    by: ['senderUserId'],
    _sum: { totalCoins: true },
  }).catch(() => []);

  const sendingMap = new Map();
  for (const row of sendingAggregates) {
    if (row.senderUserId) {
      sendingMap.set(row.senderUserId, BigInt(row._sum?.totalCoins || 0n));
    }
  }

  const discrepancies = [];
  const correctCount = { unchanged: 0, changed: 0, inflated: 0, deflated: 0 };

  for (const p of profiles) {
    const verifiedSending = sendingMap.get(p.userId) || 0n;
    const storedXp = BigInt(p.experiencePoints || 0n);
    const effectiveCoins = verifiedSending > storedXp ? verifiedSending : storedXp;

    const previousLevel = p.level || 1;
    const progression = calculateWealthProgression(effectiveCoins);
    const correctedLevel = progression.level;

    if (previousLevel !== correctedLevel || storedXp !== effectiveCoins) {
      correctCount.changed++;
      if (previousLevel > correctedLevel) {
        correctCount.inflated++;
      } else if (previousLevel < correctedLevel) {
        correctCount.deflated++;
      }

      discrepancies.push({
        userId: p.userId,
        uniqueId: p.user?.username || null,
        username: p.user?.username || null,
        nickname: p.displayName || null,
        previousLevel,
        correctedLevel,
        levelDifference: previousLevel - correctedLevel,
        storedExperiencePoints: storedXp.toString(),
        verifiedSendingCoins: verifiedSending.toString(),
        authoritativeSendingCoins: effectiveCoins.toString(),
        progressPercent: progression.progressPercent,
        remainingCoins: progression.remainingCoins,
        nextLevelThreshold: progression.nextLevelThreshold,
        progression,
      });

      if (!dryRun && previousLevel !== correctedLevel) {
        await db.userProfile.update({
          where: { userId: p.userId },
          data: {
            level: correctedLevel,
            experiencePoints: effectiveCoins,
            totalSpentCoins: effectiveCoins,
          },
        });
      }
    } else {
      correctCount.unchanged++;
    }
  }

  return {
    success: true,
    executionMode: dryRun ? 'DRY_RUN' : 'LIVE_UPDATE',
    totalExamined: profiles.length,
    unchangedCount: correctCount.unchanged,
    discrepancyCount: correctCount.changed,
    inflatedCount: correctCount.inflated,
    deflatedCount: correctCount.deflated,
    discrepancies,
  };
}

export default {
  MAX_WEALTH_LEVEL,
  MAX_WEALTH_THRESHOLD,
  WEALTH_LEVEL_SCHEDULE,
  validateWealthSchedule,
  normalizeCoinValue,
  calculateWealthLevel,
  calculateWealthProgression,
  getVerifiedLifetimeSending,
  reconcileUserWealth,
  reconcileAllUserWealthLevels,
};
