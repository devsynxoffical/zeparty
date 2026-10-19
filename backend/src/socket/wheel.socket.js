import wheelService from '../services/wheel.service.js';
import { SOCKET_ERRORS } from './socket.constants.js';

export function registerWheelHandlers(io, socket) {
  // 1. Create Wheel Session
  socket.on('wheel:create_session', async (data, callback) => {
    try {
      const roomId = data?.roomId;
      const actorUserId = socket.user?.id || socket.userId || data?.hostId || data?.userId;

      if (!roomId) {
        const err = { success: false, error: { code: 'INVALID_ROOM_ID', message: 'roomId is required' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit('wheel:error', err);
      }

      const session = await wheelService.createWheelSession(roomId, {
        entryCoinFee: data?.entryCoinFee,
        maxParticipants: data?.maxParticipants,
        rewardCoins: data?.rewardCoins,
        onlySeatedMics: data?.onlySeatedMics,
        actorUserId,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: session });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('wheel:error', errRes);
    }
  });

  // 2. Join Wheel Session
  socket.on('wheel:join_session', async (data, callback) => {
    try {
      const sessionId = data?.sessionId;
      const roomId = data?.roomId;
      const userId = socket.user?.id || socket.userId || data?.userId;

      if (!userId) {
        const err = { success: false, error: { code: 'UNAUTHORIZED', message: 'User must be authenticated to join' } };
        if (typeof callback === 'function') return callback(err);
        return socket.emit('wheel:error', err);
      }

      const result = await wheelService.joinWheelSession({
        sessionId,
        roomId,
        userId,
        user: socket.user || data?.user,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: result });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('wheel:error', errRes);
    }
  });

  // 3. Spin Wheel Round
  socket.on('wheel:spin_round', async (data, callback) => {
    try {
      const sessionId = data?.sessionId;
      const roomId = data?.roomId;
      const actorUserId = socket.user?.id || socket.userId || data?.userId;

      const result = await wheelService.spinWheelRound({
        sessionId,
        roomId,
        actorUserId,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: result });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('wheel:error', errRes);
    }
  });

  // 4. Cancel Session
  socket.on('wheel:cancel_session', async (data, callback) => {
    try {
      const sessionId = data?.sessionId;
      const roomId = data?.roomId;
      const actorUserId = socket.user?.id || socket.userId || data?.userId;

      const result = await wheelService.cancelWheelSession({
        sessionId,
        roomId,
        actorUserId,
      });

      if (typeof callback === 'function') {
        return callback({ success: true, data: result });
      }
    } catch (err) {
      const errRes = {
        success: false,
        error: { code: err.code || SOCKET_ERRORS.INTERNAL_ERROR, message: err.message },
      };
      if (typeof callback === 'function') return callback(errRes);
      return socket.emit('wheel:error', errRes);
    }
  });

  // 5. Get Active Session
  socket.on('wheel:get_session', (data, callback) => {
    const roomId = data?.roomId;
    const session = wheelService.getActiveWheelSession(roomId);
    if (typeof callback === 'function') {
      return callback({ success: true, data: session });
    }
    socket.emit('wheel:session_state', { roomId, session });
  });
}

export default {
  registerWheelHandlers,
};
