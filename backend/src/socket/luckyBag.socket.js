import luckyBagService from '../services/luckyBag.service.js';
import { SOCKET_ERRORS } from './socket.constants.js';

export function registerLuckyBagHandlers(io, socket) {
  // 1. Create Lucky Bag
  socket.on('luckybag:create', async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const creatorUserId = socket.user?.id || socket.userId || data?.creatorId || data?.userId;

      if (!creatorUserId) {
        const err = { success: false, error: { code: 'UNAUTHORIZED', message: 'User must be authenticated' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit('luckybag:error', err);
      }

      if (!roomId) {
        const err = { success: false, error: { code: 'INVALID_ROOM_ID', message: 'roomId is required' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit('luckybag:error', err);
      }

      const bag = await luckyBagService.createLuckyBag({
        roomId,
        mode: data?.mode || 'normal',
        totalCoins: data?.totalCoins,
        quantity: data?.quantity || data?.claimCount || data?.claimersLimit,
        taskType: data?.taskType || 'none',
        countdownSeconds: data?.countdownSeconds || 0,
        creatorUserId,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: bag });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('luckybag:error', errRes);
    }
  });

  // 2. Claim Lucky Bag
  socket.on('luckybag:claim', async (data, callback) => {
    try {
      const bagId = data?.bagId;
      const roomId = data?.roomId;
      const claimantUserId = socket.user?.id || socket.userId || data?.userId;

      if (!claimantUserId) {
        const err = { success: false, error: { code: 'UNAUTHORIZED', message: 'User must be authenticated to claim' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit('luckybag:error', err);
      }

      const result = await luckyBagService.claimLuckyBag({
        bagId,
        roomId,
        claimantUserId,
        claimantUser: socket.user || data?.user,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: result });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: {
          code: err.code || SOCKET_ERRORS.INTERNAL_ERROR,
          message: err.message,
          remainingSeconds: err.remainingSeconds,
          coinsWon: err.coinsWon,
          requiredTask: err.requiredTask,
        },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('luckybag:error', errRes);
    }
  });

  // 3. Get Active Lucky Bags
  socket.on('luckybag:get_active', (data, callback) => {
    const roomId = data?.roomId;
    const bags = luckyBagService.getActiveLuckyBags(roomId);
    if (typeof callback === 'function') {
      return callback({ success: true, data: bags });
    }
    socket.emit('luckybag:active_state', bags);
  });
}

export default {
  registerLuckyBagHandlers,
};
