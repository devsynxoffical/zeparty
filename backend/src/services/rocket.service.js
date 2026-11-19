import prisma from '../config/prisma.js';
import socketEmitter from '../socket/socket.emitter.js';
import * as walletRepository from '../repositories/wallet.repository.js';
import * as ledgerService from './ledger.service.js';

/**
 * Rocket Game Milestone Configuration:
 * Rocket 1: 100,000 points -> 5,000 coins max reward
 * Rocket 2: 300,000 points -> 6,000 coins max reward
 * Rocket 3: 400,000 points -> 7,000 coins max reward
 * Rocket 4: 500,000 points -> 10,000 coins max reward
 * Rocket 5: 1,000,000 points -> 15,000 coins max reward
 * Total across 5 rockets: 43,000 coins
 */
export const ROCKET_MILESTONES = [
  { level: 1, target: 100000, maxReward: 5000, displayFormat: '100K' },
  { level: 2, target: 300000, maxReward: 6000, displayFormat: '300K' },
  { level: 3, target: 400000, maxReward: 7000, displayFormat: '400K' },
  { level: 4, target: 500000, maxReward: 10000, displayFormat: '500K' },
  { level: 5, target: 1000000, maxReward: 15000, displayFormat: '1M' },
];

// In-memory active rocket state per room:
// key: roomId -> {
//   cycleId: string,
//   cumulativePoints: number,
//   unlockedLevels: Set<number>,
//   contributors: Map<userId, { name, avatar, amount }>,
//   settledKeys: Set<string>
// }
const activeRoomRockets = new Map();

/**
 * Retrieves or initializes active rocket state for a room.
 */
export function getOrCreateRoomRocket(roomId) {
  if (!roomId) return null;
  const canonicalId = String(roomId).trim();
  if (!activeRoomRockets.has(canonicalId)) {
    activeRoomRockets.set(canonicalId, {
      cycleId: `cycle_${Date.now()}`,
      cumulativePoints: 0,
      unlockedLevels: new Set(),
      contributors: new Map(),
      settledKeys: new Set(),
    });
  }
  return activeRoomRockets.get(canonicalId);
}

/**
 * Returns formatted rocket progress for a room.
 */
export function getRoomRocketProgress(roomId) {
  const rocket = getOrCreateRoomRocket(roomId);
  if (!rocket) {
    return {
      roomId,
      cumulativePoints: 0,
      activeRocketLevel: 1,
      activeTarget: ROCKET_MILESTONES[0].target,
      unlockedLevels: [],
      targets: ROCKET_MILESTONES,
      contributors: [],
      topSender: null,
    };
  }

  // Find active level (first milestone not yet unlocked, up to 5)
  let activeLevel = 1;
  for (let i = 0; i < ROCKET_MILESTONES.length; i++) {
    if (!rocket.unlockedLevels.has(ROCKET_MILESTONES[i].level)) {
      activeLevel = ROCKET_MILESTONES[i].level;
      break;
    }
    if (i === ROCKET_MILESTONES.length - 1) {
      activeLevel = 5;
    }
  }

  const activeMilestone = ROCKET_MILESTONES[activeLevel - 1] || ROCKET_MILESTONES[0];
  const sortedContributors = Array.from(rocket.contributors.entries())
    .map(([userId, data]) => ({
      userId,
      name: data.name || 'User',
      avatar: data.avatar || null,
      amount: data.amount || 0,
    }))
    .sort((a, b) => b.amount - a.amount);

  const topSender = sortedContributors.length > 0 ? sortedContributors[0] : null;

  return {
    roomId,
    cycleId: rocket.cycleId,
    cumulativePoints: rocket.cumulativePoints,
    activeRocketLevel: activeLevel,
    activeTarget: activeMilestone.target,
    displayFormat: activeMilestone.displayFormat,
    maxReward: activeMilestone.maxReward,
    unlockedLevels: Array.from(rocket.unlockedLevels).sort((a, b) => a - b),
    targets: ROCKET_MILESTONES.map((m) => ({
      ...m,
      isUnlocked: rocket.unlockedLevels.has(m.level),
      isActive: m.level === activeLevel,
    })),
    contributors: sortedContributors,
    topSender,
  };
}

/**
 * Records an eligible committed gift contribution to the room's Rocket Game.
 * Every successfully committed coin adds 1 rocket point.
 * Checks and unlocks milestone thresholds crossed by the gift.
 */
export async function recordGiftContribution({
  roomId,
  roomName,
  senderUserId,
  senderName,
  senderAvatar,
  coins,
  transactionId,
}, db = prisma) {
  if (!roomId || !coins || coins <= 0) return null;
  const canonicalRoomId = String(roomId).trim();
  const rocket = getOrCreateRoomRocket(canonicalRoomId);
  const coinsInt = Math.floor(Number(coins));
  if (isNaN(coinsInt) || coinsInt <= 0) return null;

  // Add 1 rocket point per committed coin
  const prevPoints = rocket.cumulativePoints;
  rocket.cumulativePoints += coinsInt;
  const newPoints = rocket.cumulativePoints;

  // Update sender's contribution in current cycle
  const currentContrib = rocket.contributors.get(senderUserId) || {
    name: senderName || 'User',
    avatar: senderAvatar || null,
    amount: 0,
  };
  currentContrib.amount += coinsInt;
  currentContrib.name = senderName || currentContrib.name;
  currentContrib.avatar = senderAvatar || currentContrib.avatar;
  rocket.contributors.set(senderUserId, currentContrib);

  // Check thresholds crossed
  const newlyUnlocked = [];
  for (const milestone of ROCKET_MILESTONES) {
    if (newPoints >= milestone.target && !rocket.unlockedLevels.has(milestone.level)) {
      rocket.unlockedLevels.add(milestone.level);
      newlyUnlocked.push(milestone);
    }
  }

  // Broadcast in-room progress update
  const progressData = getRoomRocketProgress(canonicalRoomId);
  socketEmitter.emitToRoom(canonicalRoomId, 'room:rocket_progress', progressData);
  socketEmitter.emitToRoom(canonicalRoomId, 'rocket:progress_updated', progressData);

  // Settle each crossed milestone once
  for (const milestone of newlyUnlocked) {
    const settleKey = `room_${canonicalRoomId}_cycle_${rocket.cycleId}_rocket_${milestone.level}`;
    if (rocket.settledKeys.has(settleKey)) continue;
    rocket.settledKeys.add(settleKey);

    try {
      await settleMilestoneReward({
        rocket,
        milestone,
        canonicalRoomId,
        roomName: roomName || "Party Room",
        settleKey,
        triggerTransactionId: transactionId,
      }, db);
    } catch (settleErr) {
      console.error(`[RocketGame] Error settling milestone ${milestone.level}:`, settleErr);
    }
  }

  return progressData;
}

/**
 * Settles top sender reward for an unlocked milestone.
 */
async function settleMilestoneReward({
  rocket,
  milestone,
  canonicalRoomId,
  roomName,
  settleKey,
  triggerTransactionId,
}, db = prisma) {
  // Determine top contributor in active cycle
  const sortedContributors = Array.from(rocket.contributors.entries())
    .map(([userId, data]) => ({ userId, ...data }))
    .sort((a, b) => b.amount - a.amount);

  const winner = sortedContributors.length > 0 ? sortedContributors[0] : null;
  const rewardAmount = milestone.maxReward;
  const txRef = `ROCKET_RWD_${Date.now()}_${milestone.level}`;

  if (winner && rewardAmount > 0) {
    try {
      // 1. Credit winner's personal coin wallet (not diamonds, not stock)
      let winnerWallet = await walletRepository.findByUserId(winner.userId, db);
      if (!winnerWallet) {
        winnerWallet = await walletRepository.createWallet(winner.userId, db);
      }

      await db.wallet.update({
        where: { id: winnerWallet.id },
        data: {
          coinBalance: { increment: BigInt(rewardAmount) },
        },
      });

      // 2. Double-entry ledger audit
      try {
        await ledgerService.postTransaction({
          operations: [
            {
              walletId: winnerWallet.id,
              coinDelta: BigInt(rewardAmount),
              diamondDelta: 0n,
            },
          ],
          referenceId: txRef,
          transactionType: 'ROCKET_REWARD',
          db,
        });
      } catch (ledgerErr) {
        console.warn('[RocketGame] Ledger entry warning:', ledgerErr?.message);
      }

      // 3. Official inbox receipt to winner
      try {
        await db.message.create({
          data: {
            senderId: winner.userId, // System-assigned notification
            recipientId: winner.userId,
            content: `🚀 Rocket ${milestone.level} Unlocked! Congratulations, you were the top contributor in "${roomName}" with ${winner.amount.toLocaleString()} points. Your reward of ${rewardAmount.toLocaleString()} coins has been credited to your personal wallet. Transaction ID: ${txRef}`,
            type: 'system',
            isRead: false,
          },
        });
      } catch (inboxErr) {
        console.warn('[RocketGame] Inbox receipt warning:', inboxErr?.message);
      }

      // 4. Notify winner directly via socket
      socketEmitter.emitToUser(winner.userId, 'rocket:reward_credited', {
        rocketLevel: milestone.level,
        rewardCoins: rewardAmount,
        roomId: canonicalRoomId,
        roomName,
        transactionId: txRef,
        contribution: winner.amount,
      });
    } catch (walletErr) {
      console.error('[RocketGame] Failed to credit wallet reward:', walletErr);
    }
  }

  // 5. Broadcast unlock event to the room
  const unlockPayload = {
    roomId: canonicalRoomId,
    roomName,
    rocketLevel: milestone.level,
    target: milestone.target,
    reward: rewardAmount,
    topSender: winner
      ? {
          userId: winner.userId,
          name: winner.name,
          avatar: winner.avatar,
          contribution: winner.amount,
          rewardCoins: rewardAmount,
        }
      : null,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(canonicalRoomId, 'room:rocket_unlocked', unlockPayload);
  socketEmitter.emitToRoom(canonicalRoomId, 'rocket:unlocked', unlockPayload);

  // 6. Broadcast global world banner to ALL online users
  const worldRocketBanner = {
    type: 'rocket_unlocked',
    title: `WORLD | ROCKET ${milestone.level} UNLOCKED`,
    rocketLevel: milestone.level,
    roomId: canonicalRoomId,
    roomName,
    reward: rewardAmount,
    topSenderName: winner?.name || 'Top Contributor',
    message: `${roomName} • Tap to join this room >`,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToAll('world:rocket_unlocked', worldRocketBanner);
  socketEmitter.emitToAll('world:global_event', worldRocketBanner);
  socketEmitter.broadcastGlobal('world:rocket_unlocked', worldRocketBanner);
}

export default {
  ROCKET_MILESTONES,
  getOrCreateRoomRocket,
  getRoomRocketProgress,
  recordGiftContribution,
};
