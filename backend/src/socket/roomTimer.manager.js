import roomRepository from '../repositories/room.repository.js';
import socketEmitter from './socket.emitter.js';
import { SOCKET_EVENTS } from './socket.constants.js';

// Map of roomId -> { timer: NodeJS.Timeout, type: 'PARTY' | 'VIDEO', hostUserId: string, startedAt: number, durationMs: number }
const hostAbsentTimers = new Map();

/**
 * Starts a host absence timer when the host leaves or disconnects from a room.
 *
 * @param {string} roomId
 * @param {string} roomType - 'AUDIO_PARTY' | 'LIVE_VIDEO'
 * @param {string} hostUserId
 * @param {import('socket.io').Server} [io]
 */
export function startHostAbsentTimer(roomId, roomType, hostUserId, io) {
  if (!roomId) return;

  // Clear any existing timer for this room
  clearHostAbsentTimer(roomId);

  const isAudioParty = (roomType || '').toUpperCase().includes('AUDIO') || (roomType || '').toUpperCase().includes('PARTY');
  // Party room: 2 minutes (120,000 ms)
  // Video live: 10 minutes (600,000 ms)
  const durationMs = isAudioParty ? 2 * 60 * 1000 : 10 * 60 * 1000;
  const autoEndSeconds = Math.round(durationMs / 1000);

  console.log(`[RoomTimerManager] Starting host absent timer for room ${roomId} (${isAudioParty ? 'PARTY: 2 mins' : 'VIDEO: 10 mins'})`);

  const timer = setTimeout(async () => {
    try {
      console.log(`[RoomTimerManager] Host absent timer expired for room ${roomId}. Auto-closing room in DB.`);
      hostAbsentTimers.delete(roomId);

      // Close room in database
      await roomRepository.closeRoomTx({
        roomId,
        status: 'ENDED',
        endedAt: new Date(),
      }).catch((e) => console.warn(`[RoomTimerManager] Could not close room ${roomId} on timer expiry:`, e?.message));

      // Broadcast room closed to all clients
      const closePayload = {
        roomId,
        status: 'ENDED',
        reason: isAudioParty ? 'HOST_ABSENT_TIMEOUT' : 'HOST_LEFT_TIMEOUT',
        message: isAudioParty
          ? 'Live party has ended because the host was away for 2 minutes.'
          : 'Live stream has ended (host away timeout).',
      };

      if (io) {
        io.to(`room:${roomId}`).emit(SOCKET_EVENTS.ROOM_CLOSED, closePayload);
        io.to(`room:${roomId}`).emit('room:closed', closePayload);
        io.to(`room:${roomId}`).emit('room_closed', closePayload);
        io.to(`room:${roomId}`).emit('stream:ended', closePayload);
        io.emit('room:deleted', { roomId });
      } else {
        socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_CLOSED, closePayload);
        socketEmitter.emitToRoom(roomId, 'room:closed', closePayload);
        socketEmitter.broadcastGlobal('room:deleted', { roomId });
      }
    } catch (err) {
      console.error(`[RoomTimerManager] Error handling timer expiry for room ${roomId}:`, err);
    }
  }, durationMs);

  hostAbsentTimers.set(roomId, {
    timer,
    type: isAudioParty ? 'PARTY' : 'VIDEO',
    hostUserId,
    startedAt: Date.now(),
    durationMs,
    autoEndSeconds,
  });

  // Notify room members that host is absent
  const absentPayload = {
    roomId,
    hostUserId,
    hostAbsent: true,
    autoEndSeconds,
    message: isAudioParty
      ? 'Host has stepped out. Room will automatically end in 2 minutes if host does not return.'
      : 'Live broadcast ended by host.',
  };

  if (io) {
    io.to(`room:${roomId}`).emit('room:host_absent', absentPayload);
  } else {
    socketEmitter.emitToRoom(roomId, 'room:host_absent', absentPayload);
  }
}

/**
 * Clears and cancels the host absent timer when host rejoins or room is explicitly deleted.
 *
 * @param {string} roomId
 * @param {import('socket.io').Server} [io]
 */
export function clearHostAbsentTimer(roomId, io) {
  if (!roomId) return;
  const entry = hostAbsentTimers.get(roomId);
  if (entry) {
    clearTimeout(entry.timer);
    hostAbsentTimers.delete(roomId);
    console.log(`[RoomTimerManager] Cancelled host absent timer for room ${roomId} (Host returned / room closed)`);

    if (io) {
      io.to(`room:${roomId}`).emit('room:host_returned', { roomId, hostAbsent: false });
    } else {
      socketEmitter.emitToRoom(roomId, 'room:host_returned', { roomId, hostAbsent: false });
    }
  }
}

/**
 * Checks if a room currently has an active host absent timer.
 */
export function isHostAbsent(roomId) {
  return hostAbsentTimers.has(roomId);
}

export default {
  startHostAbsentTimer,
  clearHostAbsentTimer,
  isHostAbsent,
};
