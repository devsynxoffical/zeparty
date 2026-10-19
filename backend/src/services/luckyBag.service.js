import prisma from '../config/database.js';
import socketEmitter from '../socket/socket.emitter.js';

/**
 * Server-Authoritative Normal & World Lucky Bag Service
 *
 * Implements:
 * 1. createLuckyBag (normal in-room vs world global broadcast)
 * 2. Atomic creator coin deduction in PostgreSQL
 * 3. Countdown timer verification (opensAt)
 * 4. Task verification (authoritative PostgreSQL follow checks)
 * 5. Concurrency-safe random claim distribution
 * 6. Atomic claimant coin credit in PostgreSQL
 * 7. Active bag recovery for reconnecting/entering users
 */

// Active bags storage
const activeBagsById = new Map();
const activeBagsByRoom = new Map();
let latestWorldBag = null;

export async function createLuckyBag(
  {
    roomId,
    mode = 'normal',
    totalCoins = 1000,
    quantity = 10,
    claimCount,
    claimersLimit,
    taskType = 'none',
    countdownSeconds = 0,
    creatorUserId,
  },
  db = prisma
) {
  // Resolve room
  let canonicalRoomId = roomId;
  let room = await db.room.findUnique({ where: { id: roomId } }).catch(() => null);
  if (room) {
    canonicalRoomId = room.id;
  } else if (roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
    }).catch(() => null);
    if (room) canonicalRoomId = room.id;
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Validate parameters
  const coins = parseInt(totalCoins, 10);
  if (isNaN(coins) || coins < 100) {
    const error = new Error('Total coins must be at least 100');
    error.statusCode = 400;
    error.code = 'INVALID_TOTAL_COINS';
    throw error;
  }

  const effectiveQty = parseInt(quantity || claimCount || claimersLimit, 10) || 10;
  if (isNaN(effectiveQty) || effectiveQty < 1 || effectiveQty > 100) {
    const error = new Error('Quantity of claims must be between 1 and 100');
    error.statusCode = 400;
    error.code = 'INVALID_QUANTITY';
    throw error;
  }

  if (coins < effectiveQty) {
    const error = new Error('Total coins must be at least equal to the number of claims (min 1 coin per claim)');
    error.statusCode = 400;
    error.code = 'COINS_LESS_THAN_CLAIMS';
    throw error;
  }

  const normalizedMode = String(mode).toLowerCase() === 'world' ? 'world' : 'normal';

  const validTasks = ['none', 'follow_sender', 'follow_room', 'followme', 'followroom'];
  let normalizedTask = String(taskType).toLowerCase();
  if (normalizedTask === 'followme') normalizedTask = 'follow_sender';
  if (normalizedTask === 'followroom') normalizedTask = 'follow_room';
  if (!validTasks.includes(normalizedTask)) normalizedTask = 'none';

  const countdown = Math.max(0, parseInt(countdownSeconds, 10) || 0);

  // Atomic Creator Wallet Coin Deduction
  const updated = await (db || prisma).wallet.updateMany({
    where: {
      userId: creatorUserId,
      coinBalance: { gte: BigInt(coins) },
    },
    data: {
      coinBalance: { decrement: BigInt(coins) },
    },
  });

  if (updated.count === 0) {
    const error = new Error(
      `Insufficient coin balance to create Lucky Bag. Required: ${coins}`
    );
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_BALANCE';
    throw error;
  }

  // Resolve creator metadata
  const creatorUser = await db.user.findUnique({
    where: { id: creatorUserId },
    select: { username: true, avatarUrl: true, profile: { select: { displayName: true } } },
  }).catch(() => null);

  const creatorName = creatorUser?.profile?.displayName || creatorUser?.username || 'Host';
  const creatorAvatar = creatorUser?.avatarUrl || null;
  const roomTitle = room.title || room.name || "Javis's Party";

  const now = Date.now();
  const opensAt = new Date(now + countdown * 1000).toISOString();
  const expiresAt = new Date(now + 3600 * 1000).toISOString(); // 1 hour TTL
  const bagId = `bag_${now}_${Math.random().toString(36).substring(2, 7)}`;

  const bag = {
    id: bagId,
    bagId,
    mode: normalizedMode,
    creatorUserId,
    creatorName,
    creatorAvatar,
    sourceRoomId: canonicalRoomId,
    sourceRoomTitle: roomTitle,
    totalCoins: coins,
    totalClaims: effectiveQty,
    claimsRemaining: effectiveQty,
    coinsRemaining: coins,
    taskType: normalizedTask,
    countdownSeconds: countdown,
    createdAt: new Date(now).toISOString(),
    opensAt,
    expiresAt,
    status: 'ACTIVE',
    claims: [],
  };

  activeBagsById.set(bagId, bag);
  activeBagsByRoom.set(canonicalRoomId, bag);

  if (normalizedMode === 'world') {
    latestWorldBag = bag;
    // Broadcast to global channel and all rooms
    const globalPayload = {
      type: 'world_lucky_bag',
      bagId: bag.id,
      mode: 'world',
      sourceRoomId: canonicalRoomId,
      sourceRoomTitle: roomTitle,
      creator: {
        id: creatorUserId,
        name: creatorName,
        avatar: creatorAvatar,
      },
      totalCoins: coins,
      remainingClaims: effectiveQty,
      opensAt,
      timestamp: new Date(now).toISOString(),
    };

    socketEmitter.emitToAll('world:global_event', globalPayload);
    socketEmitter.emitToAll('luckybag:world_created', globalPayload);
  }

  // Broadcast to room
  socketEmitter.emitToRoom(canonicalRoomId, 'luckybag:created', bag);
  socketEmitter.emitToRoom(canonicalRoomId, 'luckybag:normal_created', bag);
  if (canonicalRoomId !== roomId) {
    socketEmitter.emitToRoom(roomId, 'luckybag:created', bag);
  }

  return bag;
}

export async function claimLuckyBag({ bagId, roomId, claimantUserId, claimantUser }, db = prisma) {
  let bag = null;
  if (bagId) {
    bag = activeBagsById.get(bagId);
  }
  if (!bag && roomId) {
    bag = activeBagsByRoom.get(roomId);
  }
  if (!bag && latestWorldBag && latestWorldBag.status === 'ACTIVE') {
    bag = latestWorldBag;
  }

  if (!bag) {
    const error = new Error('Lucky Bag not found or has expired');
    error.statusCode = 404;
    error.code = 'BAG_NOT_FOUND';
    throw error;
  }

  const now = Date.now();

  // 1. Verify Countdown
  if (now < new Date(bag.opensAt).getTime()) {
    const remainingSec = Math.ceil((new Date(bag.opensAt).getTime() - now) / 1000);
    const error = new Error(`Lucky Bag is still locked. Opens in ${remainingSec} seconds`);
    error.statusCode = 400;
    error.code = 'COUNTDOWN_ACTIVE';
    error.remainingSeconds = remainingSec;
    throw error;
  }

  // 2. Verify Expiry
  if (now > new Date(bag.expiresAt).getTime()) {
    bag.status = 'EXPIRED';
    const error = new Error('Lucky Bag has expired');
    error.statusCode = 400;
    error.code = 'BAG_EXPIRED';
    throw error;
  }

  // 3. Verify Empty/Exhausted
  if (bag.claimsRemaining <= 0 || bag.coinsRemaining <= 0 || bag.status !== 'ACTIVE') {
    bag.status = 'EXHAUSTED';
    const error = new Error('Lucky Bag is fully claimed');
    error.statusCode = 400;
    error.code = 'BAG_FULLY_CLAIMED';
    throw error;
  }

  // 4. Verify Duplicate Claim
  const existingClaim = bag.claims.find((c) => c.userId === claimantUserId);
  if (existingClaim) {
    const error = new Error(`You have already claimed ${existingClaim.coins} coins from this Lucky Bag`);
    error.statusCode = 400;
    error.code = 'ALREADY_CLAIMED';
    error.coinsWon = existingClaim.coins;
    throw error;
  }

  // 5. Authoritative Task Verification via PostgreSQL
  if (bag.taskType === 'follow_sender') {
    const follow = await db.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: claimantUserId,
          followingId: bag.creatorUserId,
        },
      },
    }).catch(() => null);

    if (!follow || follow.status !== 'ACCEPTED') {
      const error = new Error('Task requirement not met: You must follow the bag creator to claim');
      error.statusCode = 403;
      error.code = 'TASK_REQUIRED';
      error.requiredTask = 'follow_sender';
      throw error;
    }
  } else if (bag.taskType === 'follow_room') {
    // Check if claimant follows room host
    const room = await db.room.findUnique({
      where: { id: bag.sourceRoomId },
      select: { creatorUserId: true },
    }).catch(() => null);

    if (room && room.creatorUserId) {
      const follow = await db.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: claimantUserId,
            followingId: room.creatorUserId,
          },
        },
      }).catch(() => null);

      if (!follow || follow.status !== 'ACCEPTED') {
        const error = new Error('Task requirement not met: You must follow the room host to claim');
        error.statusCode = 403;
        error.code = 'TASK_REQUIRED';
        error.requiredTask = 'follow_room';
        throw error;
      }
    }
  }

  // 6. Concurrency-Safe Randomized Share Calculation
  let rewardCoins;
  if (bag.claimsRemaining === 1) {
    rewardCoins = bag.coinsRemaining;
  } else {
    const maxShare = Math.round((bag.coinsRemaining / bag.claimsRemaining) * 2.0);
    const minShare = Math.max(1, Math.floor(bag.coinsRemaining / (bag.claimsRemaining * 5)));
    rewardCoins = minShare + Math.floor(Math.random() * Math.max(1, maxShare - minShare + 1));
    rewardCoins = Math.min(rewardCoins, bag.coinsRemaining - (bag.claimsRemaining - 1));
    rewardCoins = Math.max(1, rewardCoins);
  }

  // Deduct from bag budget
  bag.coinsRemaining -= rewardCoins;
  bag.claimsRemaining -= 1;

  if (bag.claimsRemaining <= 0 || bag.coinsRemaining <= 0) {
    bag.status = 'EXHAUSTED';
  }

  // 7. Atomic Claimant Coin Credit in PostgreSQL
  await (db || prisma).wallet.updateMany({
    where: { userId: claimantUserId },
    data: { coinBalance: { increment: BigInt(rewardCoins) } },
  });

  // Resolve claimant metadata
  let effectiveName = claimantUser?.displayName || claimantUser?.name || claimantUser?.username;
  let effectiveAvatar = claimantUser?.avatarUrl;
  if (!effectiveName) {
    const dbUser = await db.user.findUnique({
      where: { id: claimantUserId },
      select: { username: true, avatarUrl: true, profile: { select: { displayName: true } } },
    }).catch(() => null);
    if (dbUser) {
      effectiveName = dbUser.profile?.displayName || dbUser.username;
      effectiveAvatar = dbUser.avatarUrl;
    }
  }

  const claimRecord = {
    userId: claimantUserId,
    userName: effectiveName || 'User',
    displayName: effectiveName || 'User',
    userAvatar: effectiveAvatar || null,
    coins: rewardCoins,
    claimedAt: new Date().toISOString(),
  };

  bag.claims.unshift(claimRecord);

  const claimPayload = {
    bagId: bag.id,
    mode: bag.mode,
    sourceRoomId: bag.sourceRoomId,
    claimant: claimRecord,
    coinsWon: rewardCoins,
    claimsRemaining: bag.claimsRemaining,
    coinsRemaining: bag.coinsRemaining,
    isFullyClaimed: bag.claimsRemaining <= 0,
    timestamp: new Date().toISOString(),
  };

  // Broadcast to room channel
  socketEmitter.emitToRoom(bag.sourceRoomId, 'luckybag:claimed', claimPayload);

  // If World Lucky Bag, also broadcast to global channel
  if (bag.mode === 'world') {
    socketEmitter.emitToAll('world:global_event', {
      type: 'world_lucky_bag_claimed',
      ...claimPayload,
    });
  }

  return {
    success: true,
    coinsWon: rewardCoins,
    claimsRemaining: bag.claimsRemaining,
    coinsRemaining: bag.coinsRemaining,
    claimRecord,
  };
}

export function getActiveLuckyBags(roomId) {
  const roomBag = roomId ? activeBagsByRoom.get(roomId) : null;
  return {
    roomBag: roomBag && roomBag.status === 'ACTIVE' ? roomBag : null,
    worldBag: latestWorldBag && latestWorldBag.status === 'ACTIVE' ? latestWorldBag : null,
  };
}

export default {
  createLuckyBag,
  claimLuckyBag,
  getActiveLuckyBags,
};
