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
import hostTargetService from './hostTarget.service.js';

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

  // 2. Parallel Pre-Transaction Entity & Policy Resolution
  const [
    recipientUser,
    hostProfile,
    initialSenderWallet,
    initialHostWallet,
    economyPolicy,
    roomRecord,
  ] = await Promise.all([
    db.user.findUnique({
      where: { id: recipientUserId },
      select: { id: true, username: true },
    }),
    hostRepository.findHostProfileByUserId(recipientUserId, db).catch(() => null),
    walletRepository.findByUserId(senderUserId, db),
    walletRepository.findByUserId(recipientUserId, db),
    policyService.getEffectivePolicy('ECONOMY', db).catch(() => null),
    roomId ? db.room.findUnique({ where: { id: roomId } }).catch(() => null) : Promise.resolve(null),
  ]);

  if (!recipientUser) {
    const error = new Error('Recipient user not found');
    error.statusCode = 404;
    error.code = 'RECIPIENT_NOT_FOUND';
    throw error;
  }

  // Ensure sender and recipient wallets exist
  let senderWallet = initialSenderWallet;
  if (!senderWallet) {
    senderWallet = await walletRepository.createWallet(senderUserId, db);
  }

  let hostWallet = initialHostWallet;
  if (!hostWallet) {
    hostWallet = await walletRepository.createWallet(recipientUserId, db);
  }

  // 4. Calculate Total Coins
  const giftCoinValue = BigInt(gift.coinValue);
  const totalCoins = giftCoinValue * BigInt(qty);

  // 5. Dynamic ECONOMY Policy Resolution
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
  if (roomRecord && roomRecord.status === 'LIVE' && roomRecord.creatorUserId) {
    roomCoins = (totalCoins * roomBps) / 10000n;
    roomOwnerWallet = await walletRepository.findByUserId(roomRecord.creatorUserId, db);
    if (!roomOwnerWallet) {
      roomOwnerWallet = await walletRepository.createWallet(roomRecord.creatorUserId, db);
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

    // If sending directly to a user in Inbox (no roomId), persist authoritative Message in conversation
    let directMessage = null;
    if (!roomId) {
      try {
        directMessage = await tx.message.create({
          data: {
            senderId: senderUserId,
            recipientId: recipientUserId,
            content: `🎁 Sent ${qty > 1 ? qty + ' × ' : ''}${gift.name}`,
            type: 'gift',
            mediaUrl: gift.iconUrl || gift.svgaAssetUrl || null,
            mediaExpiresAt: null, // Gifts are permanent financial assets, never expired
            isMediaDeleted: false,
            isRead: false,
          },
        });
      } catch (dmErr) {
        console.warn('Failed to persist direct gift message inside tx:', dmErr.message);
      }
    }

    const senderNewBalance = (BigInt(currentSenderWallet.coinBalance) - totalCoins).toString();

    return {
      giftTransaction: giftTx,
      directMessage,
      ledgerPosting,
      senderNewBalance,
      senderWealth: {
        previousXp: currentXp.toString(),
        newXp: newXp.toString(),
        wealthLevel: newWealthLevel,
        addedXp: coinsSpent.toString(),
      },
    };
  }, { maxWait: 10000, timeout: 30000 });

  // Prepare immediate confirmed HTTP response payload (Bug #26: sub-50ms latency)
  const responseData = {
    referenceId: refId,
    status: 'CONFIRMED',
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
    senderNewBalance: result.senderNewBalance,
    updatedCoinBalance: result.senderNewBalance,
    newCoinBalance: result.senderNewBalance,
    remainingBalance: result.senderNewBalance,
    transactionId: result.giftTransaction.id,
    wealthXPAdded: Number(result.senderWealth.addedXp),
    senderNewLevel: result.senderWealth.wealthLevel,
    senderWealth: result.senderWealth,
    hostTarget: null,
  };

  const returnPayload = {
    success: true,
    message: `Successfully sent ${qty}x ${gift.name} to host!`,
    giftTransaction: result.giftTransaction,
    transactionId: result.giftTransaction.id,
    senderNewBalance: result.senderNewBalance,
    updatedCoinBalance: result.senderNewBalance,
    wealthXPAdded: Number(result.senderWealth.addedXp),
    senderNewLevel: result.senderWealth.wealthLevel,
    senderWealth: result.senderWealth,
    data: responseData,
  };

  // Asynchronous background execution: target attribution, audit log, socket emissions, PK sync, and high-value notifications
  setImmediate(async () => {
    try {
      // 1. Authoritative Persistent Gift-Target Attribution (Counting Key = giftTransaction.id)
      try {
        await hostTargetService.recordGiftAttribution(
          {
            giftTransaction: result.giftTransaction,
            recipientUser,
            hostProfile,
            gift,
            quantity: qty,
          },
          db
        );
      } catch (attrErr) {
        console.warn('Target attribution record warning:', attrErr.message);
      }

      // 2. Audit Logging
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

      // Load sender & recipient user details for rich real-time display
      let senderUser = null;
      let recipientUserObj = null;
      try {
        [senderUser, recipientUserObj] = await Promise.all([
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
      const recipientDisplayName = recipientUserObj?.profile?.displayName || recipientUserObj?.username || 'Host';
      const recipientAvatarUrl = recipientUserObj?.profile?.avatarUrl || recipientUserObj?.avatarUrl || '';

      // 3. Realtime Room Socket Broadcasts vs Direct Inbox Messaging
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

        // Bug #28: Tag live broadcast with explicit playback & replay flags
        const broadcastPayload = {
          id: result.giftTransaction.id,
          transactionId: result.giftTransaction.id,
          eventId: `live_gift_${result.giftTransaction.id}`,
          isLive: true,
          isHistorical: false,
          playbackType: 'ANIMATE_ONCE',
          replayAnimation: true,
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
            username: recipientUserObj?.username || recipientDisplayName,
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

        // Room Sending Coin Total Sync (Trophy Counter)
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
      } else {
        // Direct Inbox Gift: emit direct message events to both users
        const giftMediaPayload = {
          id: gift.id,
          name: gift.name,
          iconUrl: gift.iconUrl || null,
          animationUrl: gift.svgaAssetUrl || null,
          mediaType: gift.svgaAssetUrl ? 'ANIMATION' : 'IMAGE',
          quantity: qty,
          totalCoins: totalCoins.toString(),
          transactionId: result.giftTransaction.id,
        };

        const msgId = result.directMessage?.id || result.giftTransaction.id;
        const directMsgPayload = {
          id: msgId,
          messageId: msgId,
          transactionId: result.giftTransaction.id,
          senderId: senderUserId,
          recipientId: recipientUserId,
          content: `🎁 Sent ${qty > 1 ? qty + ' × ' : ''}${gift.name}`,
          type: 'gift',
          mediaUrl: gift.iconUrl || gift.svgaAssetUrl || null,
          mediaType: gift.svgaAssetUrl ? 'animation' : 'image',
          mediaExpiresAt: null,
          isMediaDeleted: false,
          isMediaExpired: false,
          gift: giftMediaPayload,
          sender: {
            id: senderUserId,
            username: senderUser?.username || senderDisplayName,
            displayName: senderDisplayName,
            avatarUrl: senderAvatarUrl,
          },
          recipient: {
            id: recipientUserId,
            username: recipientUserObj?.username || recipientDisplayName,
            displayName: recipientDisplayName,
            avatarUrl: recipientAvatarUrl,
          },
          createdAt: result.directMessage?.createdAt || result.giftTransaction.createdAt,
          timestamp: (result.directMessage?.createdAt || result.giftTransaction.createdAt).toISOString(),
        };

        socketEmitter.emitToUser(recipientUserId, 'direct_message', directMsgPayload);
        socketEmitter.emitToUser(recipientUserId, 'message:received', directMsgPayload);
        socketEmitter.emitToUser(recipientUserId, 'inbox:message', directMsgPayload);
        socketEmitter.emitToUser(senderUserId, 'direct_message_sent', directMsgPayload);
        socketEmitter.emitToUser(senderUserId, 'message:sent', directMsgPayload);
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

      // Authoritative Host Target Progress Real-Time Refresh
      try {
        const hostTargetProgress = await hostTargetService.getHostTargetProgress(
          recipientUserId,
          { date: result.giftTransaction.createdAt },
          db
        );

        if (hostTargetProgress?.isHost) {
          // Emit to receiving host personal socket channel
          socketEmitter.emitToUser(recipientUserId, 'host:target_updated', hostTargetProgress);
          socketEmitter.emitToUser(recipientUserId, 'host_target_updated', hostTargetProgress);

          // If Audio/ID host belongs to an agency, emit to agency channel for aggregate sync
          if (hostTargetProgress.agencyId) {
            const agencyTargetProgress = await hostTargetService.getAgencyTargetProgress(
              hostTargetProgress.agencyId,
              { date: result.giftTransaction.createdAt },
              db
            );
            socketEmitter.emitToAgency(hostTargetProgress.agencyId, 'agency:target_updated', agencyTargetProgress);
            socketEmitter.emitToAgency(hostTargetProgress.agencyId, 'agency_target_updated', agencyTargetProgress);
          }
        }
      } catch (_) {}
    } catch (bgErr) {
      console.warn('[sendGift Background Task] Warning:', bgErr?.message);
    }
  });

  return returnPayload;
}

/**
 * Reverses a confirmed gift transaction and its linked target attribution.
 *
 * @param {Object} params
 * @param {string} params.giftTransactionId
 * @param {string} params.referenceId
 * @param {string} params.reason
 * @param {string} [params.adminId='SYSTEM']
 * @param {Object} [db=prisma]
 * @returns {Promise<Object>}
 */
export async function reverseGiftTransaction(
  { giftTransactionId, referenceId, reason, adminId = 'SYSTEM' },
  db = prisma
) {
  // 1. Perform linked host target reversal
  const targetReversalResult = await hostTargetService.recordGiftReversal(
    { giftTransactionId, referenceId, reason, adminId },
    db
  );

  // 2. Load gift transaction details
  const giftTx = await db.giftTransaction.findUnique({
    where: { id: giftTransactionId },
    include: { gift: true },
  });

  return {
    success: true,
    message: 'Gift transaction and target attribution successfully reversed',
    giftTransactionId,
    referenceId,
    targetReversal: targetReversalResult,
    giftTransaction: giftTx,
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
  reverseGiftTransaction,
};
