import pkService from '../services/pk.service.js';

export function registerPKHandlers(io, socket) {
  const getUserId = () => socket.auth?.userId || socket.userId;

  /**
   * 1. Send PK Invitation via Socket
   */
  socket.on('pk:send_invite', async (data, callback) => {
    try {
      const { fromRoomId, targetRoomId, targetHostUserId, durationSeconds } = data || {};
      const callerUserId = getUserId();

      const result = await pkService.sendInvitation({
        fromRoomId,
        targetRoomId,
        targetHostUserId,
        durationSeconds: Number(durationSeconds) || 300,
        callerUserId,
      });

      if (typeof callback === 'function') {
        callback({ success: true, data: result });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_INVITE_FAILED' });
      }
    }
  });

  /**
   * 2. Respond to PK Invitation (ACCEPT / REJECT)
   */
  socket.on('pk:respond_invite', async (data, callback) => {
    try {
      const { invitationId, action, roomId, targetRoomId } = data || {};
      const responderUserId = getUserId();

      const result = await pkService.respondInvitation({
        invitationId,
        responderUserId,
        action: action || 'ACCEPT',
        targetRoomId: targetRoomId || roomId,
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

  /**
   * 3. Cancel Pending Invitation
   */
  socket.on('pk:cancel_invite', async (data, callback) => {
    try {
      const { invitationId, reason } = data || {};
      const callerUserId = getUserId();

      const result = await pkService.cancelInvitation({
        invitationId,
        callerUserId,
        reason,
      });

      if (typeof callback === 'function') {
        callback({ success: true, data: result });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_CANCEL_FAILED' });
      }
    }
  });

  /**
   * 4. Confirm Readiness & Media Preparation
   */
  socket.on('pk:ready', async (data, callback) => {
    try {
      const { matchId, pkId, roomId, isReady = true, mediaPrepared = true } = data || {};
      const userId = getUserId();

      const result = await pkService.setOperatorReady({
        matchId: matchId || pkId,
        userId,
        roomId,
        isReady: Boolean(isReady),
        mediaPrepared: Boolean(mediaPrepared),
      });

      if (typeof callback === 'function') {
        callback({ success: true, data: result });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_READY_FAILED' });
      }
    }
  });

  /**
   * 5. Explicit Host Disconnect Notification
   */
  socket.on('pk:host_disconnect', async (data, callback) => {
    try {
      const { roomId } = data || {};
      const userId = getUserId();
      await pkService.handleHostDisconnect({ roomId, userId });

      if (typeof callback === 'function') {
        callback({ success: true });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message });
      }
    }
  });

  /**
   * 6. Explicit Host Reconnect Notification
   */
  socket.on('pk:host_reconnect', async (data, callback) => {
    try {
      const { roomId } = data || {};
      const userId = getUserId();
      await pkService.handleHostReconnect({ roomId, userId });

      if (typeof callback === 'function') {
        callback({ success: true });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message });
      }
    }
  });

  /**
   * 7. Legacy: pk:start (Authoritative Timer Start)
   */
  socket.on('pk:start', async (data, callback) => {
    try {
      const { pkId, matchId } = data || {};
      const targetId = matchId || pkId;
      const snapshot = await pkService.getMatchSnapshot(targetId);

      if (typeof callback === 'function') {
        callback({ success: true, data: snapshot });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message, code: err.code || 'PK_START_FAILED' });
      }
    }
  });

  /**
   * 8. Legacy: pk:end (Conclude match)
   */
  socket.on('pk:end', async (data, callback) => {
    try {
      const { pkId, matchId } = data || {};
      const targetId = matchId || pkId;
      const snapshot = await pkService.finishMatch(targetId, 'NORMAL_COMPLETION');

      if (typeof callback === 'function') {
        callback({ success: true, data: snapshot });
      }
    } catch (err) {
      if (typeof callback === 'function') {
        callback({ success: false, error: err.message });
      }
    }
  });

  /**
   * Socket disconnect hook for host disconnect grace
   */
  socket.on('disconnect', () => {
    const userId = getUserId();
    const roomId = socket.currentRoomId;
    if (userId && roomId) {
      pkService.handleHostDisconnect({ roomId, userId }).catch(() => {});
    }
  });
}

export default registerPKHandlers;
