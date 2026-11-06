import giftService from '../services/gift.service.js';
import prisma from '../config/database.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';
import privacyEligibilityService from '../services/privacyEligibility.service.js';

/**
 * Recalculates authoritative room gifting total from DB and broadcasts across all room aliases.
 */
export async function syncAndBroadcastRoomSendingTotal(io, roomId, canonicalRoomId, db = prisma) {
  try {
    const effectiveRoomId = canonicalRoomId || roomId;
    if (!effectiveRoomId) return 0;

    const todayUtc = new Date();
    todayUtc.setUTCHours(0, 0, 0, 0);
    let effectiveDailyStart = todayUtc;

    const roomRec = await db.room.findUnique({
      where: { id: effectiveRoomId },
      select: { id: true, createdAt: true },
    }).catch(() => null);

    if (roomRec?.createdAt) {
      const sessionStart = new Date(roomRec.createdAt);
      if (sessionStart > todayUtc) {
        effectiveDailyStart = sessionStart;
      }
    }

    const dailyAggr = await db.giftTransaction.aggregate({
      where: { roomId: effectiveRoomId, createdAt: { gte: effectiveDailyStart } },
      _sum: { totalCoins: true },
    });
    const updatedTotal = Number(dailyAggr._sum?.totalCoins || 0);

    // Atomically persist to DB so fresh room details queries have the latest ground truth
    await db.room.update({
      where: { id: effectiveRoomId },
      data: {
        roomSendingTotal: updatedTotal,
        dailySendingTotal: updatedTotal,
        periodTotalCoins: updatedTotal,
        trophyCoins: updatedTotal,
      },
    }).catch(() => {});

    const sendingTotalPayload = {
      roomId: effectiveRoomId,
      clientRoomId: roomId,
      period: 'daily',
      totalCoins: updatedTotal,
      roomSendingTotal: updatedTotal,
      dailySendingTotal: updatedTotal,
      trophyCoins: updatedTotal,
      timestamp: new Date().toISOString(),
    };

    const targetRoomIds = Array.from(new Set([String(roomId), String(effectiveRoomId)]));
    if (io) {
      const channelNames = targetRoomIds.map((rid) => `room:${rid}`);
      io.to(channelNames).emit('room:sending_total_updated', sendingTotalPayload);
      io.to(channelNames).emit('room:sending_total', sendingTotalPayload);
      io.to(channelNames).emit(SOCKET_EVENTS.ROOM_SENDING_TOTAL_UPDATED, sendingTotalPayload);
    }
    return updatedTotal;
  } catch (err) {
    console.error('[GiftSocket] syncAndBroadcastRoomSendingTotal error:', err.message);
    return 0;
  }
}

export async function onSendGift(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    const recipientUserId = data?.recipientUserId || data?.receiverUserId || (data?.receiver && (data.receiver.id || data.receiver.userId));
    const giftId = data?.giftId;
    const quantity = Number(data?.quantity) || 1;
    const clientTransactionId = data?.transactionId || data?.id || data?.idempotencyKey;

    if (!roomId || !recipientUserId || !giftId || quantity < 1) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'Valid roomId, recipientUserId, giftId, and positive quantity are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const senderUserId = socket.userId || socket.user?.id;

    // Idempotency: check if this transaction was already processed by the REST endpoint
    if (clientTransactionId && typeof clientTransactionId === 'string' && clientTransactionId.length > 5) {
      const existingTx = await prisma.giftTransaction.findUnique({
        where: { id: clientTransactionId },
        include: {
          gift: { select: { id: true, name: true, iconUrl: true, svgaAssetUrl: true } },
          sender: { select: { id: true, username: true, avatarUrl: true, profile: true } },
          recipient: { select: { id: true, username: true, avatarUrl: true, profile: true } },
        },
      }).catch(() => null);

      if (existingTx) {
        const senderName = existingTx.sender?.profile?.displayName || existingTx.sender?.username || 'User';
        const receiverName = existingTx.recipient?.profile?.displayName || existingTx.recipient?.username || 'Host';
        const ackPayload = {
          id: existingTx.id,
          transactionId: existingTx.id,
          roomId: existingTx.roomId || roomId,
          clientRoomId: roomId,
          giftId: existingTx.giftId,
          giftName: existingTx.gift?.name || 'Gift',
          giftIcon: existingTx.gift?.iconUrl || '🎁',
          quantity: existingTx.giftCount,
          senderUserId: existingTx.senderUserId,
          senderName,
          sender: {
            id: existingTx.senderUserId,
            userId: existingTx.senderUserId,
            name: senderName,
            displayName: senderName,
            username: existingTx.sender?.username || senderName,
            avatarUrl: existingTx.sender?.avatarUrl || existingTx.sender?.profile?.avatarUrl || null,
          },
          receiverUserId: existingTx.recipientUserId,
          receiverName,
          receiver: {
            id: existingTx.recipientUserId,
            userId: existingTx.recipientUserId,
            name: receiverName,
            displayName: receiverName,
            username: existingTx.recipient?.username || receiverName,
            avatarUrl: existingTx.recipient?.avatarUrl || existingTx.recipient?.profile?.avatarUrl || null,
          },
          gift: {
            id: existingTx.giftId,
            name: existingTx.gift?.name || 'Gift',
            iconUrl: existingTx.gift?.iconUrl || '🎁',
            animationUrl: existingTx.gift?.svgaAssetUrl || null,
          },
          timestamp: existingTx.createdAt.toISOString(),
        };

        if (io && roomId) {
          const targetRooms = Array.from(new Set([String(roomId), String(existingTx.roomId || roomId)]));
          const channelNames = targetRooms.map((r) => `room:${r}`);
          io.to(channelNames).emit(SOCKET_EVENTS.ROOM_GIFT_SENT, ackPayload);
          io.to(channelNames).emit('room:gift_sent', ackPayload);
          await syncAndBroadcastRoomSendingTotal(io, roomId, existingTx.roomId || roomId, prisma);
        }

        if (typeof callback === 'function') {
          return callback({
            success: true,
            message: 'Gift already recorded successfully.',
            data: ackPayload,
          });
        }
        return;
      }
    }

    // Execute Phase 3 Authoritative Financial Gifting Transaction (wallet lock, split, ledger posting)
    const result = await giftService.sendGift(
      {
        senderUserId,
        recipientUserId,
        giftId,
        quantity,
        roomId,
      },
      {
        ipAddress: socket.handshake?.address || '127.0.0.1',
      }
    );

    const giftData = result?.data || result;
    const transactionId = giftData?.transactionId || giftData?.transaction?.id || result?.giftTransaction?.id || 'tx_unknown';
    const giftInfo = giftData?.gift || result?.gift || {};

    let isAnonymous = false;
    try {
      const prefs = await privacyEligibilityService.getUserPreferences(senderUserId);
      if (prefs.HIDE_GIFT_RECORD || prefs.ANONYMOUS_GIFTING) {
        const el = await privacyEligibilityService.checkUserEligibility(senderUserId, 'HIDE_GIFT_RECORD');
        if (el.isEligible) {
          isAnonymous = true;
        }
      }
    } catch (_) {}

    const senderInfo = isAnonymous
      ? {
          id: 'anonymous',
          username: 'Mysterious Sender',
          displayName: 'Mysterious Sender',
          name: 'Mysterious Sender',
          avatarUrl: null,
          isAnonymous: true,
        }
      : {
          id: socket.user?.id || senderUserId,
          username: socket.user?.username || 'user',
          displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
          name: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
          avatarUrl: socket.user?.avatarUrl || null,
          isAnonymous: false,
        };

    const broadcastPayload = {
      id: transactionId,
      transactionId,
      roomId,
      clientRoomId: roomId,
      senderUserId: isAnonymous ? 'anonymous' : senderUserId,
      sender: senderInfo,
      recipientUserId,
      receiverUserId: recipientUserId,
      receiverName: giftData?.recipient?.displayName || giftData?.recipient?.name || 'Host',
      receiver: {
        id: recipientUserId,
        userId: recipientUserId,
        username: giftData?.recipient?.username || 'Host',
        displayName: giftData?.recipient?.displayName || giftData?.recipient?.name || 'Host',
        name: giftData?.recipient?.displayName || giftData?.recipient?.name || 'Host',
        avatarUrl: giftData?.recipient?.avatarUrl || null,
      },
      gift: {
        id: giftInfo.id || giftId,
        name: giftInfo.name || 'Gift',
        iconUrl: giftInfo.iconUrl || null,
        animationUrl: giftInfo.animationUrl || giftInfo.svgaAssetUrl || null,
      },
      giftId: giftInfo.id || giftId,
      giftName: giftInfo.name || 'Gift',
      giftIcon: giftInfo.iconUrl || '🎁',
      quantity,
      isAnonymous,
      timestamp: new Date().toISOString(),
    };

    const canonicalRoomId = result?.giftTransaction?.roomId || giftData?.roomId || roomId;
    if (io && roomId) {
      const targetRooms = Array.from(new Set([String(roomId), String(canonicalRoomId)]));
      const channelNames = targetRooms.map((r) => `room:${r}`);
      io.to(channelNames).emit(SOCKET_EVENTS.ROOM_GIFT_SENT, broadcastPayload);
      io.to(channelNames).emit('room:gift_sent', broadcastPayload);
      await syncAndBroadcastRoomSendingTotal(io, roomId, canonicalRoomId, prisma);
    }

    if (typeof callback === 'function') {
      return callback({
        success: true,
        message: 'Gift sent successfully.',
        data: broadcastPayload,
      });
    }
  } catch (err) {
    const errorResponse = {
      success: false,
      error: {
        code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
        message: err.message || 'Failed to send gift',
      },
    };
    if (typeof callback === 'function') return callback(errorResponse);
    socket.emit(SOCKET_EVENTS.ERROR, errorResponse);
  }
}

export function registerGiftHandlers(io, socket) {
  const handleGiftSend = withRateLimit('GIFT_ACTION', 5, 1000, (s, d, cb) => onSendGift(io, s, d, cb));
  socket.on(SOCKET_EVENTS.ROOM_GIFT_SEND, handleGiftSend);
  socket.on('room:gift_send', handleGiftSend);
  socket.on('room_gift_send', handleGiftSend);
  socket.on('gift:send', handleGiftSend);
  socket.on('gift_send', handleGiftSend);
}

export default {
  onSendGift,
  registerGiftHandlers,
};
