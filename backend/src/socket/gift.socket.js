import giftService from '../services/gift.service.js';
import prisma from '../config/database.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from './socket.constants.js';
import { withRateLimit } from './rateLimiter.socket.js';

export async function onSendGift(io, socket, data, callback) {
  try {
    const roomId = data?.roomId;
    const recipientUserId = data?.recipientUserId || data?.receiverUserId || (data?.receiver && (data.receiver.id || data.receiver.userId));
    const giftId = data?.giftId;
    const quantity = Number(data?.quantity) || 1;
    const clientTransactionId = data?.transactionId || data?.id;

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
          giftId: existingTx.giftId,
          giftName: existingTx.gift?.name || 'Gift',
          giftIcon: existingTx.gift?.iconUrl || '🎁',
          quantity: existingTx.giftCount,
          senderUserId: existingTx.senderUserId,
          senderName,
          receiverUserId: existingTx.recipientUserId,
          receiverName,
          timestamp: existingTx.createdAt.toISOString(),
        };
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

    const broadcastPayload = {
      id: transactionId,
      transactionId,
      roomId,
      senderUserId,
      sender: {
        id: socket.user?.id || senderUserId,
        username: socket.user?.username || 'user',
        displayName: socket.user?.displayName || socket.user?.name || socket.user?.username || 'User',
        avatarUrl: socket.user?.avatarUrl || null,
      },
      recipientUserId,
      receiverUserId: recipientUserId,
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
      timestamp: new Date().toISOString(),
    };

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
