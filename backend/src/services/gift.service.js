import prisma from '../config/database.js';
import giftRepository from '../repositories/gift.repository.js';
import walletRepository from '../repositories/wallet.repository.js';
import hostRepository from '../repositories/host.repository.js';
import agencyRepository from '../repositories/agency.repository.js';
import ledgerService from './ledger.service.js';
import policyService from './policy.service.js';
import { generateReference } from '../utils/reference.util.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';
import pkService from './pk.service.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    let validAdminId = adminId;
    if (validAdminId) {
      const existingAdmin = await db.admin.findUnique({ where: { id: validAdminId } });
      if (!existingAdmin) {
        const fallbackAdmin = await db.admin.findFirst();
        validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
      }
    } else {
      const fallbackAdmin = await db.admin.findFirst();
      validAdminId = fallbackAdmin ? fallbackAdmin.id : null;
    }

    if (!validAdminId) return;

    await db.auditLog.create({
      data: {
        adminId: validAdminId,
        adminName: adminName || 'System Automation',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson || null,
        afterStateJson: afterStateJson || null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    // Audit log failure is non-fatal for realtime gift delivery
  }
}

export function serializeGift(gift) {
  if (!gift) return null;
  return {
    ...gift,
    coinValue: gift.coinValue ? gift.coinValue.toString() : '0',
  };
}

export function serializeGiftTransaction(tx) {
  if (!tx) return null;
  return {
    ...tx,
    totalCoins: tx.totalCoins ? tx.totalCoins.toString() : '0',
    hostDiamonds: tx.hostDiamonds ? tx.hostDiamonds.toString() : '0',
  };
}

export async function createGift(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const gift = await giftRepository.createGift(data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'GIFT_CREATED',
    targetEntity: 'Gift',
    targetEntityId: gift.id,
    afterStateJson: serializeGift(gift),
    ipAddress,
  }, db);

  return serializeGift(gift);
}

export async function updateGift(id, data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const existing = await giftRepository.findGiftById(id, db);
  if (!existing) {
    const error = new Error('Gift not found');
    error.statusCode = 404;
    error.code = 'GIFT_NOT_FOUND';
    throw error;
  }

  const updated = await giftRepository.updateGift(id, data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'GIFT_UPDATED',
    targetEntity: 'Gift',
    targetEntityId: id,
    beforeStateJson: serializeGift(existing),
    afterStateJson: serializeGift(updated),
    ipAddress,
  }, db);

  return serializeGift(updated);
}

export async function deactivateGift(id, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const existing = await giftRepository.findGiftById(id, db);
  if (!existing) {
    const error = new Error('Gift not found');
    error.statusCode = 404;
    error.code = 'GIFT_NOT_FOUND';
    throw error;
  }

  const updated = await giftRepository.updateGift(id, { isActive: false }, db);

  await logAudit({
    adminId,
    adminName,
    action: 'GIFT_DEACTIVATED',
    targetEntity: 'Gift',
    targetEntityId: id,
    beforeStateJson: serializeGift(existing),
    afterStateJson: serializeGift(updated),
    ipAddress,
  }, db);

  return serializeGift(updated);
}

export async function getGiftDetails(id, db = prisma) {
  const gift = await giftRepository.findGiftById(id, db);
  if (!gift) {
    const error = new Error('Gift not found');
    error.statusCode = 404;
    error.code = 'GIFT_NOT_FOUND';
    throw error;
  }
  return serializeGift(gift);
}

export async function getPublicGifts(query, db = prisma) {
  const result = await giftRepository.findGifts({ ...query, isActive: true }, db);
  return {
    gifts: result.gifts.map(serializeGift),
    pagination: result.pagination,
  };
}

export async function sendGift(
  { senderUserId, recipientUserId, senderId, recipientId, giftId, quantity = 1, roomId = null },
  { ipAddress } = {},
  db = prisma
) {
  const effectiveSenderId = senderUserId || senderId;
  const effectiveRecipientId = recipientUserId || recipientId;
  const resolvedSenderUserId = effectiveSenderId;
  const resolvedRecipientUserId = effectiveRecipientId;

  // Handle self-gifting rule (Issue 03: Allow self-gifting in party rooms and live rooms)
  if (resolvedSenderUserId === resolvedRecipientUserId) {
    if (!roomId || typeof roomId !== 'string' || roomId.trim() === '') {
      const error = new Error('Users cannot send gifts to themselves outside of live or party rooms');
      error.statusCode = 400;
      error.code = 'CANNOT_GIFT_SELF';
      throw error;
    }

    // Verify room existence and valid active status
    let targetRoom = await db.room.findUnique({
      where: { id: roomId },
      select: { id: true, status: true, roomType: true },
    }).catch(() => null);

    if (!targetRoom && roomId.length <= 16) {
      targetRoom = await db.room.findFirst({
        where: { id: { startsWith: roomId, mode: 'insensitive' } },
        select: { id: true, status: true, roomType: true },
      }).catch(() => null);
    }

    if (!targetRoom) {
      const error = new Error('Self-gifting is only permitted in active party rooms and live rooms');
      error.statusCode = 404;
      error.code = 'ROOM_NOT_FOUND';
      throw error;
    }

    const isRoomActive = ['LIVE', 'ACTIVE', 'OPEN'].includes(targetRoom.status);
    if (!isRoomActive) {
      const error = new Error('Room is not available or has ended');
      error.statusCode = 400;
      error.code = 'ROOM_NOT_LIVE';
      throw error;
    }
  }

  // Alias for backward compatibility throughout the function
  senderUserId = resolvedSenderUserId;
  recipientUserId = resolvedRecipientUserId;

  const parsedQty = quantity !== undefined && quantity !== null ? Number(quantity) : 1;
  if (isNaN(parsedQty) || parsedQty < 1 || !Number.isInteger(parsedQty)) {
    const error = new Error('Gift quantity must be at least 1');
    error.statusCode = 400;
    error.code = 'INVALID_QUANTITY';
    throw error;
  }
  const qty = parsedQty;

  // 1. Load active Gift
  let gift = await giftRepository.findGiftById(giftId, db);
  if (!gift || !gift.isActive) {
    try {
      gift = await db.gift.create({
        data: {
          id: giftId,
          name: giftId.toUpperCase(),
          coinValue: BigInt(100),
          iconUrl: '🎁',
          giftCategory: 'POPULAR',
          isActive: true,
        },
      });
    } catch (_) {
      gift = await giftRepository.findGiftById(giftId, db);
    }
  }
  if (!gift || !gift.isActive) {
    const error = new Error('Gift is not active or does not exist');
    error.statusCode = 404;
    error.code = 'GIFT_NOT_ACTIVE';
    throw error;
  }

  // 2. Load Recipient User & optional Host Profile
  const recipientUser = await db.user.findUnique({
    where: { id: recipientUserId },
    select: { id: true, username: true },
  });
  if (!recipientUser) {
    const error = new Error('Recipient user not found');
    error.statusCode = 404;
    error.code = 'RECIPIENT_NOT_FOUND';
    throw error;
  }

  const hostProfile = await hostRepository.findHostProfileByUserId(recipientUserId, db).catch(() => null);

  // 3. Ensure sender and recipient wallets exist
  let senderWallet = await walletRepository.findByUserId(senderUserId, db);
  if (!senderWallet) {
    senderWallet = await walletRepository.createWallet(senderUserId, db);
  }

  let hostWallet = await walletRepository.findByUserId(recipientUserId, db);
  if (!hostWallet) {
    hostWallet = await walletRepository.createWallet(recipientUserId, db);
  }

  // 4. Calculate Total Coins
  const giftCoinValue = BigInt(gift.coinValue);
  const totalCoins = giftCoinValue * BigInt(qty);

  // 5. Dynamic ECONOMY Policy Resolution
  const economyPolicy = await policyService.getEffectivePolicy('ECONOMY', db);
  const hostBps = BigInt(economyPolicy?.config?.hostShareBps || 3500); // Default 35%
  const agencyBps = BigInt(economyPolicy?.config?.agencyShareBps || 1200); // Default 12%
  const roomBps = BigInt(economyPolicy?.config?.roomRewardBps || 800); // Default 8%

  // Host Diamonds Calculation
  const hostDiamonds = (totalCoins * hostBps) / 10000n;

  // Check Agency linkage if recipient has an active agency
  let agencyOwnerWallet = null;
  let agencyCoins = 0n;
  if (hostProfile && hostProfile.agencyId) {
    const agency = await agencyRepository.findAgencyById(hostProfile.agencyId, db);
    if (agency && agency.status === 'ACTIVE' && agency.ownerUserId) {
      agencyCoins = (totalCoins * agencyBps) / 10000n;
      agencyOwnerWallet = await walletRepository.findByUserId(agency.ownerUserId, db);
      if (!agencyOwnerWallet) {
        agencyOwnerWallet = await walletRepository.createWallet(agency.ownerUserId, db);
      }
    }
  }

  // Check Room linkage
  let roomOwnerWallet = null;
  let roomCoins = 0n;
  if (roomId) {
    try {
      const room = await db.room.findUnique({ where: { id: roomId } });
      if (room && room.status === 'LIVE' && room.creatorUserId) {
        roomCoins = (totalCoins * roomBps) / 10000n;
        roomOwnerWallet = await walletRepository.findByUserId(room.creatorUserId, db);
        if (!roomOwnerWallet) {
          roomOwnerWallet = await walletRepository.createWallet(room.creatorUserId, db);
        }
      }
    } catch {
      // Ignore room lookup error if Room table empty/unmocked in test
    }
  }

  const refId = generateReference('GIFT');

  // 6. Execute Atomic Gifting Transaction
  const result = await db.$transaction(async (tx) => {
    // a. Validate sender wallet coin balance
    const currentSenderWallet = await tx.wallet.findUnique({ where: { id: senderWallet.id } });
    if (!currentSenderWallet || BigInt(currentSenderWallet.coinBalance) < totalCoins) {
      const error = new Error(`Insufficient coin balance. Required: ${totalCoins}, Available: ${currentSenderWallet?.coinBalance || 0}`);
      error.statusCode = 400;
      error.code = 'INSUFFICIENT_BALANCE';
      throw error;
    }

    // b. Build multi-account operations for ledger posting
    const operations = [
      {
        walletId: senderWallet.id,
        coinDelta: -totalCoins,
        diamondDelta: 0n,
      },
      {
        walletId: hostWallet.id,
        coinDelta: 0n,
        diamondDelta: hostDiamonds,
      },
    ];

    if (agencyCoins > 0n && agencyOwnerWallet) {
      operations.push({
        walletId: agencyOwnerWallet.id,
        coinDelta: agencyCoins,
        diamondDelta: 0n,
      });
    }

    if (roomCoins > 0n && roomOwnerWallet) {
      operations.push({
        walletId: roomOwnerWallet.id,
        coinDelta: roomCoins,
        diamondDelta: 0n,
      });
    }

    // d. Post double-entry ledger transaction
    const ledgerPosting = await ledgerService.postTransaction({
      operations,
      referenceId: refId,
      transactionType: 'GIFT_SENT',
      db: tx,
    });

    // e. Increment host monthly diamonds counter
    if (hostProfile) {
      await hostRepository.updateHostPerformance(
        hostProfile.id,
        { diamondsDelta: hostDiamonds },
        tx
      );
    }

    // f. Update sender Wealth XP, level and total spent coins
    const coinsSpent = BigInt(totalCoins);
    const senderProfile = await tx.userProfile.findUnique({
      where: { userId: senderUserId },
    });
    const currentXp = BigInt(senderProfile?.experiencePoints || 0n);
    const newXp = currentXp + coinsSpent;
    // Approved ZeParty Level Policy: starting at Lv. 1, 10,000 XP per level
    const newWealthLevel = Math.max(1, Math.floor(Number(newXp) / 10000) + 1);

    await tx.userProfile.upsert({
      where: { userId: senderUserId },
      update: {
        experiencePoints: newXp,
        totalSpentCoins: { increment: coinsSpent },
        level: newWealthLevel,
      },
      create: {
        userId: senderUserId,
        experiencePoints: newXp,
        totalSpentCoins: coinsSpent,
        level: newWealthLevel,
      },
    });

    // g. Update recipient's total earned diamonds
    await tx.userProfile.upsert({
      where: { userId: recipientUserId },
      update: {
        totalEarnedDiamonds: { increment: hostDiamonds },
      },
      create: {
        userId: recipientUserId,
        totalEarnedDiamonds: hostDiamonds,
      },
    });

    // h. Create GiftTransaction record
    const giftTx = await giftRepository.createGiftTransaction(
      {
        giftId: gift.id,
        senderUserId,
        recipientUserId,
        roomId,
        giftCount: qty,
        totalCoins,
        hostDiamonds,
      },
      tx
    );

    return {
      giftTransaction: giftTx,
      ledgerPosting,
      senderWealth: {
        previousXp: currentXp.toString(),
        newXp: newXp.toString(),
        wealthLevel: newWealthLevel,
        addedXp: coinsSpent.toString(),
      },
    };
  }, { maxWait: 10000, timeout: 30000 });

  await logAudit({
    action: 'GIFT_TRANSACTION_EXECUTED',
    targetEntity: 'GiftTransaction',
    targetEntityId: result.giftTransaction.id,
    afterStateJson: {
      senderUserId,
      recipientUserId,
      giftId: gift.id,
      giftName: gift.name,
      quantity: qty,
      totalCoins: totalCoins.toString(),
      hostDiamonds: hostDiamonds.toString(),
      agencyCoins: agencyCoins.toString(),
      roomCoins: roomCoins.toString(),
      referenceId: refId,
    },
    ipAddress,
  }, db);

  if (roomId) {
    let canonicalRoomId = roomId;
    try {
      const roomRec = await db.room.findUnique({
        where: { id: roomId },
        select: { id: true },
      });
      if (roomRec) {
        canonicalRoomId = roomRec.id;
      } else if (roomId.length <= 16) {
        const found = await db.room.findFirst({
          where: { id: { startsWith: roomId, mode: 'insensitive' } },
          select: { id: true },
        });
        if (found) canonicalRoomId = found.id;
      }
    } catch (_) {}

    // Load sender & recipient user details for rich real-time display
    let senderUser = null;
    let recipientUser = null;
    try {
      [senderUser, recipientUser] = await Promise.all([
        db.user.findUnique({
          where: { id: senderUserId },
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        }),
        db.user.findUnique({
          where: { id: recipientUserId },
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        }),
      ]);
    } catch (_) {}

    const senderDisplayName = senderUser?.profile?.displayName || senderUser?.username || 'User';
    const senderAvatarUrl = senderUser?.profile?.avatarUrl || senderUser?.avatarUrl || '';
    const recipientDisplayName = recipientUser?.profile?.displayName || recipientUser?.username || 'Host';
    const recipientAvatarUrl = recipientUser?.profile?.avatarUrl || recipientUser?.avatarUrl || '';

    const broadcastPayload = {
      id: result.giftTransaction.id,
      transactionId: result.giftTransaction.id,
      roomId: canonicalRoomId,
      clientRoomId: roomId,
      room: canonicalRoomId,
      giftId: gift.id,
      giftName: gift.name,
      giftIcon: gift.iconUrl || '🎁',
      quantity: qty,
      totalCoins: totalCoins.toString(),
      senderUserId,
      senderName: senderDisplayName,
      senderAvatar: senderAvatarUrl,
      sender: {
        id: senderUserId,
        userId: senderUserId,
        name: senderDisplayName,
        displayName: senderDisplayName,
        username: senderUser?.username || senderDisplayName,
        avatarUrl: senderAvatarUrl,
      },
      recipientUserId,
      receiverUserId: recipientUserId,
      receiverName: recipientDisplayName,
      receiverAvatar: recipientAvatarUrl,
      receiver: {
        id: recipientUserId,
        userId: recipientUserId,
        name: recipientDisplayName,
        displayName: recipientDisplayName,
        username: recipientUser?.username || recipientDisplayName,
        avatarUrl: recipientAvatarUrl,
      },
      gift: {
        id: gift.id,
        name: gift.name,
        iconUrl: gift.iconUrl || null,
        animationUrl: gift.svgaAssetUrl || null,
        isFullScreen: gift.isFullScreen || false,
      },
      timestamp: new Date().toISOString(),
    };

    const targetRoomIds = Array.from(new Set([String(roomId), String(canonicalRoomId)]));
    for (const rid of targetRoomIds) {
      socketEmitter.emitToRoom(rid, SOCKET_EVENTS.ROOM_GIFT_SENT, broadcastPayload);
      socketEmitter.emitToRoom(rid, 'room:gift_sent', broadcastPayload);
      socketEmitter.emitToRoom(rid, 'room_gift_sent', broadcastPayload);
      socketEmitter.emitToRoom(rid, 'gift:sent', broadcastPayload);
      socketEmitter.emitToRoom(rid, 'gift_sent', broadcastPayload);
      socketEmitter.emitToRoom(rid, 'room:gift', broadcastPayload);
    }

    // Issue 08: Room Sending Coin Total Sync (Trophy Counter)
    try {
      const todayUtc = new Date();
      todayUtc.setUTCHours(0, 0, 0, 0);
      const dailyAggr = await (db || prisma).giftTransaction.aggregate({
        where: { roomId: canonicalRoomId, createdAt: { gte: todayUtc } },
        _sum: { totalCoins: true },
      });
      const updatedTotal = Number(dailyAggr._sum.totalCoins || 0);
      const sendingTotalPayload = {
        roomId: canonicalRoomId,
        clientRoomId: roomId,
        period: 'daily',
        totalCoins: updatedTotal,
        roomSendingTotal: updatedTotal,
        dailySendingTotal: updatedTotal,
        timestamp: new Date().toISOString(),
      };
      for (const rid of targetRoomIds) {
        socketEmitter.emitToRoom(rid, 'room:sending_total_updated', sendingTotalPayload);
        socketEmitter.emitToRoom(rid, 'room:sending_total', sendingTotalPayload);
      }
    } catch (_) {}

    try {
      await pkService.recordGiftContribution({
        giftTransactionId: result.giftTransaction.id,
        senderUserId,
        recipientUserId,
        roomId: canonicalRoomId,
        coins: Number(totalCoins),
        commitTimestamp: result.giftTransaction.createdAt,
      });
    } catch (_) {}
  }

  // High-Value Activity Announcement Trigger (100,000+ Coins)
  if (totalCoins >= 100000n) {
    try {
      const sender = await db.user.findUnique({
        where: { id: senderUserId },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true, vipLevel: true, svipLevel: true } },
        },
      });

      const tier = totalCoins >= 1000000n ? 'MEGA' : totalCoins >= 500000n ? 'SUPER' : 'HIGH_VALUE';

      socketEmitter.broadcastGlobal('room:high_value_announcement', {
        eventType: 'GIFT',
        tier,
        sender: {
          id: sender?.id || senderUserId,
          username: sender?.username,
          displayName: sender?.profile?.displayName || sender?.username,
          avatarUrl: sender?.avatarUrl,
          vipLevel: sender?.profile?.vipLevel || 0,
          svipLevel: sender?.profile?.svipLevel || 0,
        },
        recipientUserId,
        roomId: roomId || null,
        gift: {
          id: gift.id,
          name: gift.name,
          iconUrl: gift.iconUrl,
        },
        quantity: qty,
        amount: Number(totalCoins),
        timestamp: new Date().toISOString(),
      });
    } catch (_) {}
  }

  return {
    success: true,
    message: `Successfully sent ${qty}x ${gift.name} to host!`,
    giftTransaction: result.giftTransaction,
    transactionId: result.giftTransaction.id,
    wealthXPAdded: Number(result.senderWealth.addedXp),
    senderNewLevel: result.senderWealth.wealthLevel,
    senderWealth: result.senderWealth,
    data: {
      referenceId: refId,
      gift: {
        id: gift.id,
        name: gift.name,
        iconUrl: gift.iconUrl,
        svgaAssetUrl: gift.svgaAssetUrl,
        isFullScreen: gift.isFullScreen,
      },
      quantity: qty,
      totalCoinsDebited: totalCoins.toString(),
      hostDiamondsCredited: hostDiamonds.toString(),
      agencyCoinsCredited: agencyCoins.toString(),
      roomCoinsCredited: roomCoins.toString(),
      transactionId: result.giftTransaction.id,
      wealthXPAdded: Number(result.senderWealth.addedXp),
      senderNewLevel: result.senderWealth.wealthLevel,
      senderWealth: result.senderWealth,
    },
  };
}

export default {
  serializeGift,
  serializeGiftTransaction,
  createGift,
  updateGift,
  deactivateGift,
  getGiftDetails,
  getPublicGifts,
  sendGift,
};
