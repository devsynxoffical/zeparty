import giftService from '../services/gift.service.js';
import roomRepository from '../repositories/room.repository.js';
import prisma from '../config/database.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';
import { deriveAgoraUid, formatAuthoritativeUserIdentity } from '../utils/agoraToken.util.js';

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
    const rawRoomId =
      data?.roomId ||
      data?.sessionId ||
      data?.liveSessionId ||
      data?.partyRoomId ||
      data?.channelName ||
      data?.pkId ||
      data?.matchId ||
      socket.currentRoomId;
    const recipientUserId =
      data?.recipientUserId ||
      data?.receiverUserId ||
      data?.recipientId ||
      (data?.receiver && (data.receiver.id || data.receiver.userId)) ||
      (data?.recipient && (data.recipient.id || data.recipient.userId));
    const giftId = data?.giftId || data?.gift?.id;
    const quantity = Number(data?.quantity ?? data?.count ?? 1);
    const clientTransactionId = data?.transactionId || data?.id || data?.idempotencyKey;

    if (!rawRoomId || !recipientUserId || !giftId || !Number.isInteger(quantity) || quantity < 1) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.VALIDATION_ERROR,
          message: 'Valid roomId, recipientUserId, giftId, and positive integer quantity are required',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const senderUserId = socket.userId || socket.user?.id;
    if (!senderUserId || socket.isGuest) {
      const err = {
        success: false,
        error: {
          code: SOCKET_ERRORS.UNAUTHORIZED,
          message: 'Authenticated account is required to send gifts',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const resolvedRoom = await roomRepository
      .resolveCanonicalRoom(rawRoomId, { senderUserId, recipientUserId, allowActiveFallback: false }, prisma)
      .catch(() => null);

    if (!resolvedRoom) {
      const err = {
        success: false,
        error: {
          code: 'ROOM_NOT_FOUND',
          message: 'Room not found',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    if (!['LIVE', 'ACTIVE', 'OPEN'].includes(resolvedRoom.status)) {
      const err = {
        success: false,
        error: {
          code: 'ROOM_NOT_LIVE',
          message: 'Room is not available or has ended',
        },
      };
      if (typeof callback === 'function') return callback(err);
      return socket.emit(SOCKET_EVENTS.ERROR, err);
    }

    const canonicalRoomId = resolvedRoom.id;
    socket.join(`room:${canonicalRoomId}`);
    if (resolvedRoom.creatorUserId) {
      io.in(`user:${resolvedRoom.creatorUserId}`).socketsJoin(`room:${canonicalRoomId}`);
    }

    // Idempotency: check if this transaction was already processed by the REST endpoint
    if (clientTransactionId && typeof clientTransactionId === 'string' && clientTransactionId.length > 5) {
      const existingTx = await prisma.giftTransaction
        .findUnique({
          where: { id: clientTransactionId },
          include: {
            gift: {
              select: {
                id: true,
                name: true,
                coinValue: true,
                iconUrl: true,
                svgaAssetUrl: true,
                soundUrl: true,
                isFullScreen: true,
              },
            },
            sender: { select: { id: true, username: true, avatarUrl: true, countryCode: true, profile: true } },
            recipient: { select: { id: true, username: true, avatarUrl: true, countryCode: true, profile: true } },
          },
        })
        .catch(() => null);

      if (existingTx) {
        const senderIdentity = formatAuthoritativeUserIdentity(existingTx.sender || { id: existingTx.senderUserId });
        const receiverIdentity = formatAuthoritativeUserIdentity(
          existingTx.recipient || { id: existingTx.recipientUserId }
        );
        const senderName = senderIdentity?.displayName || 'User';
        const receiverName = receiverIdentity?.displayName || 'Host';
        const ackPayload = {
          id: existingTx.id,
          transactionId: existingTx.id,
          roomId: existingTx.roomId || canonicalRoomId,
          sessionId: existingTx.roomId || canonicalRoomId,
          clientRoomId: rawRoomId,
          giftId: existingTx.giftId,
          giftName: existingTx.gift?.name || 'Gift',
          giftIcon: existingTx.gift?.iconUrl || '🎁',
          iconUrl: existingTx.gift?.iconUrl || null,
          animationUrl: existingTx.gift?.svgaAssetUrl || null,
          svgaAssetUrl: existingTx.gift?.svgaAssetUrl || null,
          soundUrl: existingTx.gift?.soundUrl || null,
          quantity: existingTx.giftCount,
          totalCoins: existingTx.totalCoins?.toString?.() || '0',
          senderUserId: existingTx.senderUserId,
          senderAgoraUid: senderIdentity?.agoraUid || deriveAgoraUid(existingTx.senderUserId),
          senderName,
          senderUsername: senderIdentity?.username || senderName,
          senderAvatar: senderIdentity?.avatarUrl || null,
          sender: senderIdentity,
          recipientUserId: existingTx.recipientUserId,
          receiverUserId: existingTx.recipientUserId,
          recipientAgoraUid: receiverIdentity?.agoraUid || deriveAgoraUid(existingTx.recipientUserId),
          receiverName,
          recipientName: receiverName,
          receiverUsername: receiverIdentity?.username || receiverName,
          receiverAvatar: receiverIdentity?.avatarUrl || null,
          receiver: receiverIdentity,
          recipient: receiverIdentity,
          gift: {
            id: existingTx.giftId,
            name: existingTx.gift?.name || 'Gift',
            coinValue: existingTx.gift?.coinValue?.toString?.() || '0',
            iconUrl: existingTx.gift?.iconUrl || '🎁',
            animationUrl: existingTx.gift?.svgaAssetUrl || null,
            svgaAssetUrl: existingTx.gift?.svgaAssetUrl || null,
            soundUrl: existingTx.gift?.soundUrl || null,
            isFullScreen: Boolean(existingTx.gift?.isFullScreen),
          },
          timestamp: existingTx.createdAt.toISOString(),
        };

        // Only broadcast if the original REST call did not have a roomId attached
        if (io && !existingTx.roomId && canonicalRoomId) {
          await prisma.giftTransaction
            .update({ where: { id: existingTx.id }, data: { roomId: canonicalRoomId } })
            .catch(() => null);
          const targetRooms = Array.from(new Set([String(rawRoomId), String(canonicalRoomId)]));
          const channelNames = targetRooms.map((r) => `room:${r}`);
          io.to(channelNames).emit(SOCKET_EVENTS.ROOM_GIFT_SENT, ackPayload);
          await syncAndBroadcastRoomSendingTotal(io, rawRoomId, canonicalRoomId, prisma);
        }

        if (typeof callback === 'function') {
          return callback({
            ok: true,
            success: true,
            deduplicated: true,
            message: 'Gift already recorded successfully.',
            data: { ...ackPayload, deduplicated: true },
          });
        }
        return;
      }
    }

    // Execute Authoritative Financial Gifting Transaction + Unified Room/PK Broadcast
    const result = await giftService.sendGift(
      {
        senderUserId,
        recipientUserId,
        giftId,
        quantity,
        roomId: canonicalRoomId,
        transactionId: clientTransactionId,
        idempotencyKey: clientTransactionId,
      },
      {
        ipAddress: socket.handshake?.address || '127.0.0.1',
      }
    );

    const broadcastPayload = result?.broadcastPayload || result?.data?.broadcastPayload || result?.data || result;

    if (typeof callback === 'function') {
      return callback({
        ok: true,
        success: true,
        deduplicated: Boolean(result?.deduplicated),
        message: 'Gift sent successfully.',
        data: { ...broadcastPayload, deduplicated: Boolean(result?.deduplicated) },
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
