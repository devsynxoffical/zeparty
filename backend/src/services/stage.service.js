import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import redisProxy from '../config/redis.js';
import socketEmitter from '../socket/socket.emitter.js';
import presenceService from '../socket/presence.service.js';
import { SOCKET_EVENTS } from '../socket/socket.constants.js';

const memoryStageVersions = new Map();
const memoryCameraStates = new Map();

/**
 * Gets or increments the monotonic server sequence/revision for the room stage.
 */
export async function getNextStageVersion(roomId) {
  let v = 1;
  try {
    if (redisProxy.isOpen) {
      v = await redisProxy.incr(`room:stage:version:${roomId}`);
    } else {
      const cur = memoryStageVersions.get(roomId) || 0;
      v = cur + 1;
      memoryStageVersions.set(roomId, v);
    }
  } catch (_) {
    const cur = memoryStageVersions.get(roomId) || 0;
    v = cur + 1;
    memoryStageVersions.set(roomId, v);
  }
  return v;
}

/**
 * Gets the current stage revision without incrementing.
 */
export async function getCurrentStageVersion(roomId) {
  try {
    if (redisProxy.isOpen) {
      const raw = await redisProxy.get(`room:stage:version:${roomId}`);
      if (raw) return parseInt(raw, 10);
    }
  } catch (_) {}
  return memoryStageVersions.get(roomId) || 1;
}

/**
 * Retrieves camera state for a user in a room.
 * In live video rooms, stage occupants have camera enabled by default (true).
 */
export async function getParticipantCameraState(roomId, userId) {
  try {
    if (redisProxy.isOpen) {
      const val = await redisProxy.get(`room:stage:camera:${roomId}:${userId}`);
      if (val !== null) return val === 'true';
    }
  } catch (_) {}
  if (memoryCameraStates.has(`${roomId}:${userId}`)) {
    return memoryCameraStates.get(`${roomId}:${userId}`);
  }
  return true; // default camera ON for live video stage
}

/**
 * Updates camera state for an active stage occupant.
 */
export async function setParticipantCameraState(roomId, userId, isCameraOn) {
  const boolVal = Boolean(isCameraOn);
  try {
    if (redisProxy.isOpen) {
      await redisProxy.set(`room:stage:camera:${roomId}:${userId}`, boolVal ? 'true' : 'false', {
        EX: 86400, // 24h expiry
      });
    }
  } catch (_) {}
  memoryCameraStates.set(`${roomId}:${userId}`, boolVal);
  return boolVal;
}

/**
 * Generates the authoritative stage snapshot for a room session.
 * Guaranteed to return consistent state across owner, co-host, and audience viewers.
 */
export async function getStageSnapshot(roomId, db = prisma) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const version = await getCurrentStageVersion(room.id);
  const hostUserId = room.creatorUserId;

  // Resolve host user details
  const hostUser = room.creator || (await db.user.findUnique({
    where: { id: hostUserId },
    include: { profile: true },
  }));

  const hostDisplayName = hostUser?.profile?.displayName || hostUser?.username || 'Host';
  const hostAvatar = hostUser?.avatarUrl || hostUser?.profile?.avatarUrl || null;

  // Determine host seat (seatIndex 0)
  const hostSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.seatIndex === 0) : null;
  const isHostMuted = Boolean(hostSeat?.isMuted);
  const isHostCameraOn = await getParticipantCameraState(room.id, hostUserId);

  const hostPayload = {
    id: hostUserId,
    userId: hostUserId,
    username: hostUser?.username || 'host',
    displayName: hostDisplayName,
    name: hostDisplayName,
    avatarUrl: hostAvatar,
    role: 'HOST',
    isHost: true,
    isOwner: true,
    seatIndex: 0,
    seatNumber: 0,
    isMuted: isHostMuted,
    isCameraOn: isHostCameraOn,
    status: 'ACTIVE',
  };

  // Resolve Co-Host details (Designated Seat 1 or roomMember with role CO_HOST)
  const coHostSeat = Array.isArray(room.seats) ? room.seats.find((s) => s.seatIndex === 1) : null;
  const coHostMember = Array.isArray(room.members) ? room.members.find((m) => m.role === 'CO_HOST') : null;

  let coHostPayload = null;
  const activeCoHostUserId = coHostSeat?.occupiedUserId || coHostMember?.userId;

  if (activeCoHostUserId && activeCoHostUserId !== hostUserId) {
    const coHostUser = coHostSeat?.occupiedUser || (await db.user.findUnique({
      where: { id: activeCoHostUserId },
      include: { profile: true },
    }));

    if (coHostUser) {
      const coHostDisplayName = coHostUser.profile?.displayName || coHostUser.displayName || coHostUser.username || 'Co-Host';
      const coHostAvatar = coHostUser.avatarUrl || coHostUser.profile?.avatarUrl || null;
      const isCoHostMuted = Boolean(coHostSeat?.isMuted);
      const isCoHostCameraOn = await getParticipantCameraState(room.id, activeCoHostUserId);

      coHostPayload = {
        id: activeCoHostUserId,
        userId: activeCoHostUserId,
        username: coHostUser.username || 'cohost',
        displayName: coHostDisplayName,
        name: coHostDisplayName,
        avatarUrl: coHostAvatar,
        role: 'CO_HOST',
        isHost: false,
        isCoHost: true,
        seatIndex: coHostSeat?.seatIndex ?? 1,
        seatNumber: coHostSeat?.seatIndex ?? 1,
        isMuted: isCoHostMuted,
        isCameraOn: isCoHostCameraOn,
        status: 'ACTIVE',
      };
    }
  }

  // Format all stage slots (0 to capacity - 1)
  const slots = await Promise.all(
    (room.seats || []).map(async (s) => {
      const isSeatHost = s.seatIndex === 0;
      const isSeatCoHost = s.seatIndex === 1;
      const occupantId = isSeatHost ? (s.occupiedUserId || hostUserId) : s.occupiedUserId;
      const isOccupied = Boolean(occupantId);

      let occupantUser = null;
      let isCameraOn = true;

      if (isOccupied) {
        isCameraOn = await getParticipantCameraState(room.id, occupantId);

        if (isSeatHost) {
          occupantUser = {
            id: hostUserId,
            userId: hostUserId,
            username: hostUser?.username || 'host',
            displayName: hostDisplayName,
            name: hostDisplayName,
            avatarUrl: hostAvatar,
            level: hostUser?.profile?.level || 1,
            vipLevel: hostUser?.profile?.vipLevel || 0,
          };
        } else if (isSeatCoHost && coHostPayload && occupantId === coHostPayload.id) {
          occupantUser = {
            id: coHostPayload.id,
            userId: coHostPayload.id,
            username: coHostPayload.username,
            displayName: coHostPayload.displayName,
            name: coHostPayload.name,
            avatarUrl: coHostPayload.avatarUrl,
            level: s.occupiedUser?.profile?.level || 1,
            vipLevel: s.occupiedUser?.profile?.vipLevel || 0,
          };
        } else if (s.occupiedUser) {
          const u = s.occupiedUser;
          const dName = u.profile?.displayName || u.displayName || u.username || 'Speaker';
          occupantUser = {
            id: u.id,
            userId: u.id,
            username: u.username,
            displayName: dName,
            name: dName,
            avatarUrl: u.avatarUrl || u.profile?.avatarUrl || null,
            level: u.profile?.level || 1,
            vipLevel: u.profile?.vipLevel || 0,
          };
        }
      }

      const role = isSeatHost ? 'HOST' : (isSeatCoHost && isOccupied ? 'CO_HOST' : (isOccupied ? 'SPEAKER' : 'NONE'));

      return {
        id: s.id,
        seatIndex: s.seatIndex,
        seatNumber: s.seatIndex,
        isOccupied,
        isLocked: Boolean(s.isLocked),
        isMuted: Boolean(s.isMuted),
        isMutedByModerator: Boolean(s.isMutedByModerator),
        isCameraOn,
        role,
        occupiedUserId: isOccupied ? occupantId : null,
        user: occupantUser,
      };
    })
  );

  return {
    roomId: room.id,
    liveSessionId: room.id,
    version,
    updatedAt: new Date().toISOString(),
    host: hostPayload,
    coHost: coHostPayload,
    isCoHosting: Boolean(coHostPayload),
    slots,
    seats: slots,
    stageCapacity: slots.length,
    agoraChannelName: room.agoraChannelName || `room_${room.id.replace(/-/g, '')}`,
  };
}

/**
 * Publishes authoritative stage state updates to all room participants and subscribers.
 */
export async function broadcastStageUpdate(roomId, eventType, metadata = {}, db = prisma) {
  const version = await getNextStageVersion(roomId);
  const snapshot = await getStageSnapshot(roomId, db);

  const payload = {
    ...snapshot,
    version,
    eventType: eventType || 'STAGE_UPDATED',
    metadata,
    timestamp: new Date().toISOString(),
  };

  // Primary authoritative stage events
  socketEmitter.emitToRoom(roomId, 'room:stage_updated', payload);
  socketEmitter.emitToRoom(roomId, 'stage:updated', payload);
  socketEmitter.emitToRoom(roomId, 'room:stage_snapshot', payload);

  return payload;
}

/**
 * Notifies all clients when a stage slot is occupied (including co-host).
 */
export async function notifyStageOccupied(
  { roomId, seatIndex, userId, user = null, role = 'SPEAKER' },
  db = prisma
) {
  const stageSnapshot = await broadcastStageUpdate(roomId, 'SEAT_OCCUPIED', {
    seatIndex,
    userId,
    role,
  }, db);

  const targetSeat = stageSnapshot.slots.find((s) => s.seatIndex === seatIndex);
  const effectiveUser = targetSeat?.user || user || { id: userId, userId };

  const seatOccupiedPayload = {
    id: `seat_occ_${roomId}_${seatIndex}_${userId}_${Date.now()}`,
    roomId,
    seatIndex,
    seatNumber: seatIndex,
    role,
    isMuted: Boolean(targetSeat?.isMuted),
    isLocked: Boolean(targetSeat?.isLocked),
    isCameraOn: Boolean(targetSeat?.isCameraOn ?? true),
    user: effectiveUser,
    coHost: stageSnapshot.coHost,
    isCoHosting: stageSnapshot.isCoHosting,
    slots: stageSnapshot.slots,
    seats: stageSnapshot.slots,
    version: stageSnapshot.version,
    timestamp: new Date().toISOString(),
  };

  // Emit standard room:seat_occupied listened to by mobile Flutter apps
  socketEmitter.emitToRoom(roomId, 'room:seat_occupied', seatOccupiedPayload);
  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_SEAT_OCCUPIED, seatOccupiedPayload);
  socketEmitter.emitToRoom(roomId, 'room:seat_updated', seatOccupiedPayload);

  // If Co-Host seat (Index 1) is occupied, emit co-host specific events
  if (seatIndex === 1 || role === 'CO_HOST') {
    socketEmitter.emitToRoom(roomId, 'room:cohost_joined', {
      roomId,
      userId,
      user: effectiveUser,
      seatIndex: 1,
      coHost: stageSnapshot.coHost,
      version: stageSnapshot.version,
    });
    socketEmitter.emitToRoom(roomId, 'cohost:joined', {
      roomId,
      userId,
      user: effectiveUser,
      seatIndex: 1,
      version: stageSnapshot.version,
    });
  }

  return stageSnapshot;
}

/**
 * Notifies all clients when a stage slot is released / vacated.
 */
export async function notifyStageReleased(
  { roomId, seatIndex, userId, releasedByUserId = null, reason = 'LEFT_STAGE' },
  db = prisma
) {
  // Clear any cached camera state
  if (userId) {
    try {
      if (redisProxy.isOpen) await redisProxy.del(`room:stage:camera:${roomId}:${userId}`);
    } catch (_) {}
    memoryCameraStates.delete(`${roomId}:${userId}`);
  }

  const stageSnapshot = await broadcastStageUpdate(roomId, 'SEAT_RELEASED', {
    seatIndex,
    userId,
    releasedByUserId: releasedByUserId || userId,
    reason,
  }, db);

  const seatReleasedPayload = {
    id: `seat_rel_${roomId}_${seatIndex}_${userId || 'none'}_${Date.now()}`,
    roomId,
    seatIndex,
    seatNumber: seatIndex,
    userId,
    releasedByUserId: releasedByUserId || userId,
    previousUserId: userId,
    reason,
    coHost: stageSnapshot.coHost,
    isCoHosting: stageSnapshot.isCoHosting,
    slots: stageSnapshot.slots,
    seats: stageSnapshot.slots,
    version: stageSnapshot.version,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, 'room:seat_released', seatReleasedPayload);
  socketEmitter.emitToRoom(roomId, SOCKET_EVENTS.ROOM_SEAT_RELEASED, seatReleasedPayload);
  socketEmitter.emitToRoom(roomId, 'room:seat_updated', seatReleasedPayload);

  if (seatIndex === 1) {
    socketEmitter.emitToRoom(roomId, 'room:cohost_left', {
      roomId,
      userId,
      seatIndex: 1,
      version: stageSnapshot.version,
    });
    socketEmitter.emitToRoom(roomId, 'cohost:left', {
      roomId,
      userId,
      seatIndex: 1,
      version: stageSnapshot.version,
    });
  }

  return stageSnapshot;
}

/**
 * Updates stage microphone mute status for an occupant or moderator.
 */
export async function updateStageMicState(
  { roomId, actorUserId, targetUserId, isMuted, reason = null },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const targetId = targetUserId || actorUserId;
  const isSelf = actorUserId === targetId;
  const isHost = room.creatorUserId === actorUserId;

  if (!isSelf && !isHost) {
    const error = new Error('Unauthorized to modify microphone state of other participants');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Find occupied seat for target user
  const occupiedSeat = Array.isArray(room.seats)
    ? room.seats.find((s) => s.occupiedUserId === targetId || (s.seatIndex === 0 && targetId === room.creatorUserId))
    : null;

  if (!occupiedSeat) {
    const error = new Error('Target user does not occupy a stage slot');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_STAGE';
    throw error;
  }

  // If moderator-muted, user cannot self-unmute
  if (isSelf && !isMuted && occupiedSeat.isMutedByModerator && !isHost) {
    const error = new Error('Your microphone was muted by the host and cannot be unmuted by yourself');
    error.statusCode = 403;
    error.code = 'MUTED_BY_MODERATOR';
    throw error;
  }

  const shouldMute = Boolean(isMuted);

  await db.roomSeat.update({
    where: { id: occupiedSeat.id },
    data: {
      isMuted: shouldMute,
      isMutedByModerator: !isSelf && isHost ? shouldMute : occupiedSeat.isMutedByModerator,
    },
  });

  const stageSnapshot = await broadcastStageUpdate(roomId, shouldMute ? 'MIC_MUTED' : 'MIC_UNMUTED', {
    seatIndex: occupiedSeat.seatIndex,
    userId: targetId,
    actorUserId,
    isMuted: shouldMute,
    reason,
  }, db);

  const micPayload = {
    roomId,
    seatIndex: occupiedSeat.seatIndex,
    seatNumber: occupiedSeat.seatIndex,
    userId: targetId,
    isMuted: shouldMute,
    isMutedByModerator: Boolean(occupiedSeat.isMutedByModerator),
    version: stageSnapshot.version,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, shouldMute ? 'room:user_muted' : 'room:user_unmuted', micPayload);
  socketEmitter.emitToRoom(roomId, shouldMute ? 'room:seat_muted' : 'room:seat_unmuted', micPayload);
  socketEmitter.emitToRoom(roomId, 'room:seat_updated', micPayload);

  return {
    success: true,
    message: shouldMute ? 'Microphone muted successfully' : 'Microphone unmuted successfully',
    data: micPayload,
    stage: stageSnapshot,
  };
}

/**
 * Updates stage camera on/off status for an active stage occupant.
 * When camera is off, participant remains seated on stage with avatar metadata shown.
 */
export async function updateStageCameraState(
  { roomId, actorUserId, isCameraOn },
  db = prisma
) {
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const occupiedSeat = Array.isArray(room.seats)
    ? room.seats.find((s) => s.occupiedUserId === actorUserId || (s.seatIndex === 0 && actorUserId === room.creatorUserId))
    : null;

  if (!occupiedSeat) {
    const error = new Error('You do not occupy a stage slot');
    error.statusCode = 400;
    error.code = 'USER_NOT_ON_STAGE';
    throw error;
  }

  const boolCamera = Boolean(isCameraOn);
  await setParticipantCameraState(roomId, actorUserId, boolCamera);

  const stageSnapshot = await broadcastStageUpdate(roomId, 'CAMERA_TOGGLED', {
    seatIndex: occupiedSeat.seatIndex,
    userId: actorUserId,
    isCameraOn: boolCamera,
  }, db);

  const cameraPayload = {
    roomId,
    seatIndex: occupiedSeat.seatIndex,
    userId: actorUserId,
    isCameraOn: boolCamera,
    version: stageSnapshot.version,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(roomId, 'room:camera_toggled', cameraPayload);
  socketEmitter.emitToRoom(roomId, 'stage:camera_toggled', cameraPayload);

  return {
    success: true,
    message: boolCamera ? 'Camera enabled' : 'Camera disabled (audio only)',
    data: cameraPayload,
    stage: stageSnapshot,
  };
}

export default {
  getNextStageVersion,
  getCurrentStageVersion,
  getParticipantCameraState,
  setParticipantCameraState,
  getStageSnapshot,
  broadcastStageUpdate,
  notifyStageOccupied,
  notifyStageReleased,
  updateStageMicState,
  updateStageCameraState,
};
