import roomRepository from '../repositories/room.repository.js';
import socketEmitter from './socket.emitter.js';
import { SOCKET_EVENTS } from './socket.constants.js';
import * as attendanceService from '../services/attendance.service.js';

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
export async function startHostAbsentTimer(roomId, roomType, hostUserId, io) {
  if (!roomId) return;

  // Clear any existing timer for this room
  clearHostAbsentTimer(roomId);

  let viewerCount = 0;
  try {
    const room = await roomRepository.findRoomById(roomId);
    viewerCount = Number(room?.currentViewersCount || 0);
  } catch {}

  const isAudioParty = (roomType || '').toUpperCase().includes('AUDIO') || (roomType || '').toUpperCase().includes('PARTY');

  // DO NOT close immediately on 0 viewers!
  // Give hosts a 3-minute grace period (180,000 ms) to reconnect or resume app
  // If viewers exist, keep active for 15 minutes (900,000 ms)
  const durationMs = (viewerCount <= 0) ? (3 * 60 * 1000) : (15 * 60 * 1000);
  const autoEndSeconds = Math.round(durationMs / 1000);

  console.log(`[RoomTimerManager] Starting ${autoEndSeconds}s host absent timer for room ${roomId} (viewers: ${viewerCount})`);

  const timer = setTimeout(async () => {
    try {
      console.log(`[RoomTimerManager] Host absent timer expired for room ${roomId}. Auto-closing in DB.`);
      hostAbsentTimers.delete(roomId);

      // Verify room is still LIVE before closing
      const currentRoom = await roomRepository.findRoomById(roomId).catch(() => null);
      if (!currentRoom || currentRoom.status !== 'LIVE') {
        return;
      }

      // End active broadcast attendance session
      await attendanceService.endBroadcastSession({ roomId }).catch(() => {});

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
        reason: 'HOST_ABSENT_TIMEOUT',
        message: isAudioParty ? 'Party ended because the host was absent.' : 'Broadcast has ended (host absence timeout).',
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
    type: roomType || 'AUDIO_PARTY',
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
      ? 'Host has stepped out. Room will automatically end if host does not return.'
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

/**
 * Returns info on the active host absent timer for testing and status checks.
 */
export function getHostAbsentTimerInfo(roomId) {
  return hostAbsentTimers.get(roomId) || null;
}

export default {
  startHostAbsentTimer,
  clearHostAbsentTimer,
  isHostAbsent,
  getHostAbsentTimerInfo,
};
