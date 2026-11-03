import roomRepository from '../repositories/room.repository.js';
import presenceService from './presence.service.js';
import socketEmitter from './socket.emitter.js';
import { SOCKET_EVENTS } from './socket.constants.js';
import * as attendanceService from '../services/attendance.service.js';

// Map of roomId -> { timer: NodeJS.Timeout, type: 'PARTY' | 'VIDEO', hostUserId: string, startedAt: number, durationMs: number }
const hostAbsentTimers = new Map();

// Map of roomId -> { timer: NodeJS.Timeout, roomType: string, startedAt: number, delayMs: number }
const emptyRoomSleepTimers = new Map();

const DEFAULT_PARTY_SLEEP_DELAY_MS = 12000; // 12 seconds (within 10-15s requirement)

export function isPartyRoomType(roomType) {
  const normalized = String(roomType || 'AUDIO_PARTY').toUpperCase();
  return normalized.includes('PARTY') || normalized.includes('AUDIO') || normalized === 'MULTI_GUEST';
}

/**
 * Counts how many active users (socket presence or occupied mic seats) are currently inside a room.
 */
export async function getActiveRoomParticipantCount(roomId, excludeUserId = null) {
  if (!roomId) return 0;
  let activePresenceCount = 0;
  try {
    const activeIds = await presenceService.getRoomActiveUserIds(roomId);
    const filteredIds = excludeUserId
      ? activeIds.filter((id) => String(id) !== String(excludeUserId))
      : activeIds;
    activePresenceCount = filteredIds.length;
  } catch {
    try {
      activePresenceCount = await presenceService.getRoomActiveUserCount(roomId);
    } catch {}
  }

  let occupiedSeatCount = 0;
  try {
    const room = await roomRepository.findRoomById(roomId);
    if (room && Array.isArray(room.seats)) {
      occupiedSeatCount = room.seats.filter(
        (s) => s.occupiedUserId && (!excludeUserId || String(s.occupiedUserId) !== String(excludeUserId))
      ).length;
    }
  } catch {}

  return Math.max(activePresenceCount, occupiedSeatCount);
}

/**
 * Starts a 12-second (10-15s) sleep timer when a Party Room has 0 users remaining.
 * Once the timer expires and the room is still empty, the room transitions to sleep (status = 'ENDED')
 * without kicking anyone or emitting disruptive "Room does not exist" popups.
 * The room remains searchable and joinable by its permanent Room ID, which wakes it back to 'LIVE'.
 */
export function startEmptyRoomSleepTimer(roomId, roomType = 'AUDIO_PARTY', io = null, delayMs = DEFAULT_PARTY_SLEEP_DELAY_MS) {
  if (!roomId) return;

  clearEmptyRoomSleepTimer(roomId);

  const sleepSeconds = Math.round(delayMs / 1000);
  console.log(`[RoomTimerManager] Starting ${sleepSeconds}s empty-room sleep timer for party room ${roomId}`);

  const timer = setTimeout(async () => {
    try {
      emptyRoomSleepTimers.delete(roomId);

      const currentRoom = await roomRepository.findRoomById(roomId).catch(() => null);
      if (!currentRoom || currentRoom.status !== 'LIVE') {
        return;
      }

      // Double-check that no user joined during the 12-second grace window
      const activeCount = await getActiveRoomParticipantCount(roomId);
      if (activeCount > 0) {
        console.log(`[RoomTimerManager] Sleep aborted for room ${roomId}: ${activeCount} active participant(s) present.`);
        return;
      }

      console.log(`[RoomTimerManager] Party room ${roomId} has been empty for ${sleepSeconds}s. Transitioning to SLEEP state.`);

      // Ensure host broadcast session timer is closed so sleeping time is never counted
      await attendanceService.endBroadcastSession({ roomId }).catch(() => {});
      await presenceService.clearRoomPresence(roomId).catch(() => {});

      await roomRepository.closeRoomTx({
        roomId: currentRoom.id,
        status: 'ENDED',
        endedAt: new Date(),
      }).catch((e) => console.warn(`[RoomTimerManager] Could not put room ${roomId} to sleep:`, e?.message));

      const sleepPayload = {
        roomId: currentRoom.id,
        status: 'SLEEPING',
        dbStatus: 'ENDED',
        isSleeping: true,
        currentViewersCount: 0,
        viewerCount: 0,
        reason: 'EMPTY_ROOM_SLEEP',
        message: 'Room is now sleeping because no users are inside. Join by Room ID to wake it up.',
      };

      if (io) {
        io.emit('room:sleeping', sleepPayload);
        io.emit('room:updated', sleepPayload);
      } else {
        socketEmitter.broadcastGlobal('room:sleeping', sleepPayload);
        socketEmitter.broadcastGlobal('room:updated', sleepPayload);
      }
    } catch (err) {
      console.error(`[RoomTimerManager] Error in emptyRoomSleepTimer for room ${roomId}:`, err);
    }
  }, delayMs);

  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  emptyRoomSleepTimers.set(roomId, {
    timer,
    roomType,
    startedAt: Date.now(),
    delayMs,
    sleepSeconds,
  });
}

/**
 * Cancels the empty-room sleep timer when any user joins or wakes the room.
 */
export function clearEmptyRoomSleepTimer(roomId) {
  if (!roomId) return;
  const entry = emptyRoomSleepTimers.get(roomId);
  if (entry) {
    clearTimeout(entry.timer);
    emptyRoomSleepTimers.delete(roomId);
    console.log(`[RoomTimerManager] Cancelled empty-room sleep timer for room ${roomId} (User active in room)`);
  }
}

/**
 * Checks if a Party Room has 0 participants left; if empty, schedules the 12-second sleep timer.
 * If participants are still inside, ensures any pending sleep timer is cleared.
 */
export async function checkAndSchedulePartyRoomSleep(roomId, io = null, delayMs = DEFAULT_PARTY_SLEEP_DELAY_MS, excludeUserId = null) {
  if (!roomId) return { scheduled: false, activeCount: 0 };
  try {
    const room = await roomRepository.findRoomById(roomId).catch(() => null);
    if (!room || room.status !== 'LIVE') {
      return { scheduled: false, activeCount: 0 };
    }
    if (!isPartyRoomType(room.roomType)) {
      return { scheduled: false, activeCount: 0 };
    }

    const activeCount = await getActiveRoomParticipantCount(room.id, excludeUserId);
    if (activeCount <= 0) {
      startEmptyRoomSleepTimer(room.id, room.roomType, io, delayMs);
      return { scheduled: true, activeCount: 0, sleepAfterSeconds: Math.round(delayMs / 1000) };
    } else {
      clearEmptyRoomSleepTimer(room.id);
      return { scheduled: false, activeCount };
    }
  } catch (err) {
    console.warn(`[RoomTimerManager] checkAndSchedulePartyRoomSleep warning for ${roomId}:`, err?.message);
    return { scheduled: false, activeCount: 0 };
  }
}

/**
 * Handles host departure/disconnect from a room.
 * - For Party Rooms (AUDIO_PARTY / VIDEO_PARTY):
 *   1. Stops the host's personal BroadcastSession attendance clock immediately.
 *   2. Does NOT close the room for remaining participants.
 *   3. If no participants remain in the room, starts the 12-second Empty Room Sleep Timer.
 * - For Solo Live Video (LIVE_VIDEO):
 *   Starts the host-absent grace timer before ending the solo video stream.
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

  // Always stop the host's personal attendance session when the host leaves/disconnects
  // so hostless or sleeping room time is NEVER counted toward host streaming hours.
  await attendanceService.endBroadcastSession({ roomId, hostUserId }).catch(() => {});

  const isParty = isPartyRoomType(roomType);

  if (isParty) {
    const { scheduled, activeCount } = await checkAndSchedulePartyRoomSleep(
      roomId,
      io,
      DEFAULT_PARTY_SLEEP_DELAY_MS,
      hostUserId
    );

    const absentPayload = {
      roomId,
      hostUserId,
      hostAbsent: true,
      roomStaysOpen: true,
      activeCount,
      willSleepIfEmptyInSeconds: scheduled ? Math.round(DEFAULT_PARTY_SLEEP_DELAY_MS / 1000) : null,
      message: activeCount > 0
        ? 'Host has left the room. The party room remains open for all members.'
        : 'Room is empty and will go to sleep in 12 seconds.',
    };

    if (io) {
      io.to(`room:${roomId}`).emit('room:host_absent', absentPayload);
    } else {
      socketEmitter.emitToRoom(roomId, 'room:host_absent', absentPayload);
    }
    return;
  }

  let viewerCount = 0;
  try {
    const room = await roomRepository.findRoomById(roomId);
    viewerCount = Number(room?.currentViewersCount || 0);
  } catch {}

  // Solo LIVE_VIDEO stream grace period (3 minutes if 0 viewers, 15 minutes if viewers exist)
  const durationMs = (viewerCount <= 0) ? (3 * 60 * 1000) : (15 * 60 * 1000);
  const autoEndSeconds = Math.round(durationMs / 1000);

  console.log(`[RoomTimerManager] Starting ${autoEndSeconds}s host absent timer for LIVE_VIDEO room ${roomId} (viewers: ${viewerCount})`);

  const timer = setTimeout(async () => {
    try {
      console.log(`[RoomTimerManager] Host absent timer expired for LIVE_VIDEO room ${roomId}. Auto-closing in DB.`);
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

      let summary = null;
      try {
        const { getLiveSessionSummary } = await import('../services/room.service.js');
        summary = await getLiveSessionSummary(roomId);
      } catch (_) {}

      // Broadcast room closed to all clients in LIVE_VIDEO stream
      const closePayload = {
        roomId,
        status: 'ENDED',
        reason: 'HOST_ABSENT_TIMEOUT',
        message: 'Broadcast has ended (host absence timeout).',
        summary,
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

  if (typeof timer.unref === 'function') {
    timer.unref();
  }

  hostAbsentTimers.set(roomId, {
    timer,
    type: roomType || 'LIVE_VIDEO',
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
    message: 'Live broadcast paused by host.',
  };

  if (io) {
    io.to(`room:${roomId}`).emit('room:host_absent', absentPayload);
  } else {
    socketEmitter.emitToRoom(roomId, 'room:host_absent', absentPayload);
  }
}

/**
 * Clears and cancels the host absent timer (and any empty-room sleep timer) when host rejoins.
 *
 * @param {string} roomId
 * @param {import('socket.io').Server} [io]
 */
export function clearHostAbsentTimer(roomId, io) {
  if (!roomId) return;
  clearEmptyRoomSleepTimer(roomId);
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
  return hostAbsentTimers.get(roomId) || emptyRoomSleepTimers.get(roomId) || null;
}

export function getEmptyRoomSleepTimerInfo(roomId) {
  return emptyRoomSleepTimers.get(roomId) || null;
}

export default {
  isPartyRoomType,
  getActiveRoomParticipantCount,
  startEmptyRoomSleepTimer,
  clearEmptyRoomSleepTimer,
  checkAndSchedulePartyRoomSleep,
  startHostAbsentTimer,
  clearHostAbsentTimer,
  isHostAbsent,
  getHostAbsentTimerInfo,
  getEmptyRoomSleepTimerInfo,
};
