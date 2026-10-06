import pkService from '../services/pk.service.js';

export function registerPKHandlers(io, socket) {
  // Start PK Battle via WebSocket (Authoritative Timer Start)
  socket.on('pk:start', async (data, callback) => {
    try {
      const { pkId } = data || {};
      const hostUserId = socket.auth?.userId || socket.userId;
      const session = await pkService.startPKBattle({
        pkId,
        hostUserId,
      });

      if (typeof callback === 'function') {
        callback({ success: true, data: session });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_START_FAILED' });
      }
    }
  });

  // Respond to PK invitation via WebSocket
  socket.on('pk:respond_invite', async (data, callback) => {
    try {
      const { invitationId, action, roomId, userInfo } = data || {};
      const responderUserId = socket.auth?.userId || socket.userId;
      const result = await pkService.respondPKInvite({
        invitationId,
        responderUserId,
        responderRoomId: roomId,
        responderInfo: userInfo || {},
        action: action || 'ACCEPT',
      });

      if (typeof callback === 'function') {
        callback({ success: true, data: result });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_RESPOND_FAILED' });
      }
    }
  });

  // End PK Battle
  socket.on('pk:end', async (data, callback) => {
    try {
      const { pkId } = data || {};
      const session = await pkService.endPKBattle(pkId);
      if (typeof callback === 'function') {
        callback({ success: true, data: session });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message });
      }
    }
  });
}

export default registerPKHandlers;
