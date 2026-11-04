import prisma from '../config/database.js';
import redisClient from '../config/redis.js';
import * as ledgerRepository from '../repositories/ledger.repository.js';
import * as walletRepository from '../repositories/wallet.repository.js';

/**
 * Daily Quests Configuration
 * Both quests must be tracked 100% independently:
 * - Quest A: PLAY_MINI_GAME (+150 ZeCoins) - Requires qualifying mini-game activity. Sending gifts NEVER completes this.
 * - Quest B: SEND_STREAM_GIFT (+250 ZeCoins) - Requires qualifying stream gift activity. Playing mini games NEVER completes this.
 */
export const QUEST_CONFIGS = {
  PLAY_MINI_GAME: {
    id: 'play_mini_game',
    key: 'PLAY_MINI_GAME',
    title: 'Play 1 Mini Game in Lobby',
    rewardCoins: 150,
    targetCount: 1,
    description: 'Play at least 1 mini game in the lobby',
  },
  SEND_STREAM_GIFT: {
    id: 'send_stream_gift',
    key: 'SEND_STREAM_GIFT',
    title: 'Send Gifts in Live Stream',
    rewardCoins: 250,
    targetCount: 1,
    description: 'Send gifts to broadcasters in any live room',
  },
};

// In-memory fallback sets for local/offline resilience and testing
const memoryActivities = new Map();
const memoryClaimed = new Map();

export function normalizeQuestId(rawId) {
  if (!rawId || typeof rawId !== 'string') return null;
  const clean = rawId.trim().toUpperCase().replace(/[-\s]/g, '_');
  if (clean.includes('GAME') || clean.includes('MINI')) {
    return 'PLAY_MINI_GAME';
  }
  if (clean.includes('GIFT') || clean.includes('STREAM')) {
    return 'SEND_STREAM_GIFT';
  }
  return null;
}

export function getTodayUtcString() {
  return new Date().toISOString().split('T')[0];
}

export function getDayUtcRange(dateStr = null) {
  const ds = dateStr || getTodayUtcString();
  const start = new Date(`${ds}T00:00:00.000Z`);
  const end = new Date(`${ds}T23:59:59.999Z`);
  return { start, end, dateStr: ds };
}

/**
 * Records activity independently for mini-games or gift sending.
 * @param {string} userId
 * @param {'MINI_GAME'|'STREAM_GIFT'} activityType
 * @param {Object} metadata
 */
export async function recordActivity(userId, activityType, metadata = {}) {
  if (!userId) return;
  const todayStr = getTodayUtcString();
  const actType = String(activityType).toUpperCase();
  const entry = `${Date.now()}_${metadata.gameId || metadata.giftId || 'activity'}`;

  // In-memory fallback recording
  const memKey = `quests:act:${userId}:${todayStr}:${actType === 'MINI_GAME' ? 'game' : 'gift'}`;
  if (!memoryActivities.has(memKey)) {
    memoryActivities.set(memKey, new Set());
  }
  memoryActivities.get(memKey).add(entry);

  try {
    if (redisClient.isOpen) {
      if (actType === 'MINI_GAME') {
        const key = `quests:act:${userId}:${todayStr}:game`;
        await redisClient.sAdd(key, entry).catch(() => {});
        await redisClient.expire(key, 60 * 60 * 48).catch(() => {});
      } else if (actType === 'STREAM_GIFT') {
        const key = `quests:act:${userId}:${todayStr}:gift`;
        await redisClient.sAdd(key, entry).catch(() => {});
        await redisClient.expire(key, 60 * 60 * 48).catch(() => {});
      }
    }
  } catch (err) {
    console.warn(`[QuestService] Warning recording ${activityType} activity:`, err.message);
  }
}

/**
 * Checks how many qualifying mini-games the user played today.
 * Strictly queries mini-game activity. Gift sending NEVER counts here.
 */
export async function getMiniGameCountToday(userId, dateStr = null, db = prisma) {
  if (!userId) return 0;
  const { start, end, dateStr: todayStr } = getDayUtcRange(dateStr);

  let redisCount = 0;
  try {
    if (redisClient.isOpen) {
      const key = `quests:act:${userId}:${todayStr}:game`;
      redisCount = await redisClient.sCard(key).catch(() => 0);
    }
  } catch (_) {}

  const memKey = `quests:act:${userId}:${todayStr}:game`;
  const memCount = memoryActivities.get(memKey)?.size || 0;

  let dbCount = 0;
  try {
    if (db.gameTransaction) {
      dbCount = await db.gameTransaction.count({
        where: {
          userId,
          createdAt: { gte: start, lte: end },
        },
      });
    }
  } catch (_) {}

  return Math.max(Number(redisCount || 0), Number(memCount || 0), Number(dbCount || 0));
}

/**
 * Checks how many stream gifts the user sent today.
 * Strictly queries GiftTransaction records. Playing mini games NEVER counts here.
 */
export async function getStreamGiftCountToday(userId, dateStr = null, db = prisma) {
  if (!userId) return 0;
  const { start, end, dateStr: todayStr } = getDayUtcRange(dateStr);

  let redisCount = 0;
  try {
    if (redisClient.isOpen) {
      const key = `quests:act:${userId}:${todayStr}:gift`;
      redisCount = await redisClient.sCard(key).catch(() => 0);
    }
  } catch (_) {}

  const memKey = `quests:act:${userId}:${todayStr}:gift`;
  const memCount = memoryActivities.get(memKey)?.size || 0;

  let dbCount = 0;
  try {
    if (db.giftTransaction) {
      dbCount = await db.giftTransaction.count({
        where: {
          senderUserId: userId,
          roomId: { not: null },
          createdAt: { gte: start, lte: end },
        },
      });
    }
  } catch (_) {}

  return Math.max(Number(redisCount || 0), Number(memCount || 0), Number(dbCount || 0));
}

/**
 * Determines whether a quest has already been claimed for the given day.
 * Reconciles Redis cache with immutable PostgreSQL WalletLedger records.
 */
export async function isQuestClaimedToday(userId, questKey, dateStr = null, db = prisma) {
  if (!userId || !questKey) return false;
  const todayStr = dateStr || getTodayUtcString();
  const refId = `QUEST-${userId}-${questKey}-${todayStr}`;

  // 1. Authoritative check in PostgreSQL WalletLedger
  try {
    const existingLedger = await db.walletLedger.findFirst({
      where: { referenceId: refId },
      select: { id: true },
    });
    if (existingLedger) return true;
  } catch (_) {}

  // 2. Check Redis cache
  try {
    if (redisClient.isOpen) {
      const redisClaimed = await redisClient.get(`quests:claimed:${userId}:${questKey}:${todayStr}`);
      if (redisClaimed) return true;
    }
  } catch (_) {}

  // 3. Check Memory fallback
  if (memoryClaimed.has(`${userId}:${questKey}:${todayStr}`)) {
    return true;
  }

  return false;
}

/**
 * Retrieves the authoritative daily quests status for a user.
 * Validates eligibility dynamically on the server.
 */
export async function getDailyQuestsStatus(userId, db = prisma) {
  const todayStr = getTodayUtcString();
  if (!userId) {
    return Object.values(QUEST_CONFIGS).map((cfg) => ({
      ...cfg,
      currentCount: 0,
      isCompleted: false,
      isClaimed: false,
      canClaim: false,
      status: 'INCOMPLETE',
    }));
  }

  const [gameCount, giftCount, isGameClaimed, isGiftClaimed] = await Promise.all([
    getMiniGameCountToday(userId, todayStr, db),
    getStreamGiftCountToday(userId, todayStr, db),
    isQuestClaimedToday(userId, 'PLAY_MINI_GAME', todayStr, db),
    isQuestClaimedToday(userId, 'SEND_STREAM_GIFT', todayStr, db),
  ]);

  const gameCompleted = gameCount >= QUEST_CONFIGS.PLAY_MINI_GAME.targetCount;
  const giftCompleted = giftCount >= QUEST_CONFIGS.SEND_STREAM_GIFT.targetCount;

  return [
    {
      ...QUEST_CONFIGS.PLAY_MINI_GAME,
      currentCount: gameCount,
      isCompleted: gameCompleted,
      isClaimed: isGameClaimed,
      canClaim: gameCompleted && !isGameClaimed,
      status: isGameClaimed ? 'CLAIMED' : (gameCompleted ? 'AVAILABLE' : 'INCOMPLETE'),
    },
    {
      ...QUEST_CONFIGS.SEND_STREAM_GIFT,
      currentCount: giftCount,
      isCompleted: giftCompleted,
      isClaimed: isGiftClaimed,
      canClaim: giftCompleted && !isGiftClaimed,
      status: isGiftClaimed ? 'CLAIMED' : (giftCompleted ? 'AVAILABLE' : 'INCOMPLETE'),
    },
  ];
}

/**
 * Claims a daily quest reward with strict server-side eligibility verification,
 * atomic distributed locking, and ledger-backed financial posting.
 */
export async function claimDailyQuest(userId, rawQuestId, db = prisma) {
  if (!userId) {
    const err = new Error('Authentication required');
    err.status = 401;
    err.code = 'UNAUTHORIZED';
    throw err;
  }

  const questKey = normalizeQuestId(rawQuestId);
  if (!questKey || !QUEST_CONFIGS[questKey]) {
    const err = new Error('Invalid quest identifier. Supported quests: play_mini_game, send_stream_gift.');
    err.status = 400;
    err.code = 'INVALID_QUEST_ID';
    throw err;
  }

  const config = QUEST_CONFIGS[questKey];
  const todayStr = getTodayUtcString();
  const refId = `QUEST-${userId}-${questKey}-${todayStr}`;

  // 1. Idempotency & Duplicate Claim Check (PostgreSQL + Redis)
  const alreadyClaimed = await isQuestClaimedToday(userId, questKey, todayStr, db);
  if (alreadyClaimed) {
    const err = new Error(`You have already claimed the "${config.title}" reward for today. Come back tomorrow!`);
    err.status = 400;
    err.code = 'QUEST_ALREADY_CLAIMED';
    throw err;
  }

  // 2. Strict Server-Side Activity Verification (Never trust client Claim button)
  if (questKey === 'PLAY_MINI_GAME') {
    const gameCount = await getMiniGameCountToday(userId, todayStr, db);
    if (gameCount < config.targetCount) {
      const err = new Error('Quest incomplete: You have not played a mini-game today. Play 1 mini-game in the lobby to unlock this reward.');
      err.status = 400;
      err.code = 'QUEST_INCOMPLETE';
      err.requiredCount = config.targetCount;
      err.currentCount = gameCount;
      throw err;
    }
  } else if (questKey === 'SEND_STREAM_GIFT') {
    const giftCount = await getStreamGiftCountToday(userId, todayStr, db);
    if (giftCount < config.targetCount) {
      const err = new Error('Quest incomplete: You have not sent any gifts in a live stream today. Send gifts in a live stream to unlock this reward.');
      err.status = 400;
      err.code = 'QUEST_INCOMPLETE';
      err.requiredCount = config.targetCount;
      err.currentCount = giftCount;
      throw err;
    }
  }

  // 3. Concurrency Protection: Atomic Redis Distributed Lock
  const lockKey = `quests:lock:${userId}:${questKey}:${todayStr}`;
  let lockAcquired = true;
  if (redisClient.isOpen) {
    try {
      lockAcquired = await redisClient.set(lockKey, '1', { NX: true, EX: 30 });
    } catch (_) {
      lockAcquired = true;
    }
  }
  if (!lockAcquired) {
    const err = new Error('Claim in progress or already processed today.');
    err.status = 409;
    err.code = 'CLAIM_IN_PROGRESS';
    throw err;
  }

  try {
    // 4. Atomic PostgreSQL Transaction: Wallet Update + Ledger Record
    const result = await db.$transaction(async (tx) => {
      // Re-verify inside transaction against double-credit
      const existingLedger = await tx.walletLedger.findFirst({
        where: { referenceId: refId },
      });
      if (existingLedger) {
        const err = new Error(`Quest "${config.title}" was already claimed.`);
        err.status = 400;
        err.code = 'QUEST_ALREADY_CLAIMED';
        throw err;
      }

      // Upsert wallet
      let wallet = await tx.wallet.findUnique({ where: { userId } });
      if (!wallet) {
        wallet = await tx.wallet.create({
          data: {
            userId,
            coinBalance: 0n,
            diamondBalance: 0n,
          },
        });
      }

      const balanceBeforeCoins = BigInt(wallet.coinBalance || 0n);
      const rewardCoinsBig = BigInt(config.rewardCoins);
      const newCoinBalance = balanceBeforeCoins + rewardCoinsBig;

      // Update wallet balance atomically
      const updatedWallet = await tx.wallet.update({
        where: { id: wallet.id },
        data: {
          coinBalance: newCoinBalance,
        },
      });

      // Record immutable WalletLedger entry
      const ledgerEntry = await ledgerRepository.createEntry(
        {
          walletId: wallet.id,
          transactionType: 'RECHARGE',
          coinDelta: rewardCoinsBig,
          diamondDelta: 0n,
          usdDelta: 0.0,
          balanceBefore: {
            coins: balanceBeforeCoins.toString(),
            diamonds: wallet.diamondBalance?.toString() || '0',
          },
          balanceAfter: {
            coins: newCoinBalance.toString(),
            diamonds: wallet.diamondBalance?.toString() || '0',
            questKey,
            rewardCoins: config.rewardCoins,
            claimedDate: todayStr,
          },
          referenceId: refId,
        },
        tx
      );

      return {
        updatedWallet,
        ledgerEntry,
      };
    });

    // 5. Update Redis & Memory state with 30-day TTL
    memoryClaimed.set(`${userId}:${questKey}:${todayStr}`, true);
    if (redisClient.isOpen) {
      await redisClient.set(`quests:claimed:${userId}:${questKey}:${todayStr}`, '1', {
        EX: 60 * 60 * 24 * 30,
      }).catch(() => {});
    }

    return {
      success: true,
      message: `🎉 +${config.rewardCoins} ZeCoins claimed for "${config.title}"!`,
      data: {
        questId: config.id,
        questKey: config.key,
        rewardCoins: config.rewardCoins,
        walletCoins: Number(result.updatedWallet.coinBalance),
        ledgerEntryId: result.ledgerEntry.id,
        referenceId: refId,
      },
    };
  } finally {
    // Release concurrency lock
    if (redisClient.isOpen) {
      await redisClient.del(lockKey).catch(() => {});
    }
  }
}

export default {
  QUEST_CONFIGS,
  normalizeQuestId,
  getTodayUtcString,
  getDayUtcRange,
  recordActivity,
  getMiniGameCountToday,
  getStreamGiftCountToday,
  isQuestClaimedToday,
  getDailyQuestsStatus,
  claimDailyQuest,
};
