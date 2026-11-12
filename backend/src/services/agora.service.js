import env from '../config/env.js';
import prisma from '../config/database.js';
import roomRepository from '../repositories/room.repository.js';
import userRepository from '../repositories/user.repository.js';
import socketEmitter from '../socket/socket.emitter.js';
import {
  deriveAgoraUid,
  generateAgoraRtcToken,
  AGORA_ROLES,
  formatAuthoritativeUserIdentity,
} from '../utils/agoraToken.util.js';

/**
 * Issues a short-lived Agora RTC token for a user in a live room after strict authorization.
 * 
 * Authorization Rules:
 * 1. Room must exist and be LIVE / ACTIVE.
 * 2. User must exist and have ACTIVE account status.
 * 3. User must not be banned / restricted in the room.
 * 4. Role derivation:
 *    - Host / Creator -> BROADCASTER (Publisher)
 *    - Current Seat Occupant -> BROADCASTER (Publisher)
 *    - Viewer / Member -> AUDIENCE (Subscriber)
 * 5. Deterministic integer UID derived from user ID.
 * 6. Tokens are short-lived and never stored in database or Redis.
 */
export async function issueRoomAgoraToken({ roomId, userId }, db = prisma) {
  if (!roomId || !userId) {
    const error = new Error('Room ID and User ID are required');
    error.statusCode = 400;
    error.status = 400;
    error.code = 'INVALID_PARAMETERS';
    throw error;
  }

  // 1. Check user status (supports both regular users and admins)
  const user = await userRepository.findUserById(userId, db);
  let admin = null;
  if (!user) {
    admin = await db.admin.findUnique({ where: { id: userId } });
  }

  if (!user && !admin) {
    const error = new Error('User not found');
    error.statusCode = 404;
    error.status = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  if (user && user.status !== 'ACTIVE') {
    const error = new Error(`Account is ${user.status.toLowerCase()}. Access denied.`);
    error.statusCode = 403;
    error.status = 403;
    error.code = 'USER_NOT_ACTIVE';
    throw error;
  }

  if (admin && admin.status !== 'ACTIVE') {
    const error = new Error(`Admin account is ${admin.status.toLowerCase()}. Access denied.`);
    error.statusCode = 403;
    error.status = 403;
    error.code = 'ADMIN_NOT_ACTIVE';
    throw error;
  }

  // 2. Check room status
  const room = await roomRepository.findRoomById(roomId, db);
  if (!room) {
    const error = new Error('Live room not found');
    error.statusCode = 404;
    error.status = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  if (room.status !== 'LIVE') {
    const isParty = String(room.roomType || '').toUpperCase().includes('PARTY') ||
      String(room.roomType || '').toUpperCase().includes('AUDIO');
    if (isParty && room.status === 'ENDED') {
      try {
        await db.room.updateMany({
          where: { id: room.id, status: 'ENDED' },
          data: { status: 'LIVE', endedAt: null },
        });
        const fresh = await db.room.findUnique({ where: { id: room.id }, select: { status: true } });
        if (fresh?.status) room.status = fresh.status;
      } catch (_) {}
    }
    if (room.status !== 'LIVE') {
      if (['CLOSED_BY_ADMIN', 'HOST_KICKED'].includes(room.status)) {
        const error = new Error(`Room has been closed by administration (status: ${room.status})`);
        error.statusCode = 403;
        error.status = 403;
        error.code = 'ROOM_CLOSED_BY_ADMIN';
        error.roomEnded = true;
        error.recoverable = false;
        throw error;
      }
      const error = new Error(`Room is not live (current status: ${room.status})`);
      error.statusCode = 410;
      error.status = 410;
      error.code = 'ROOM_NOT_LIVE';
      error.roomEnded = true;
      error.recoverable = false;
      throw error;
    }
  }

  if (!room.agoraChannelName) {
    const fallbackChannel = `room_${(room.id || '').replace(/-/g, '')}`;
    try {
      await db.room.update({
        where: { id: room.id },
        data: { agoraChannelName: fallbackChannel },
      });
      room.agoraChannelName = fallbackChannel;
    } catch (updateErr) {
      room.agoraChannelName = fallbackChannel;
    }
  }

  // Check if user was kicked from this room session
  const isKicked = await db.roomModeration.findFirst({
    where: {
      roomId: room.id,
      targetUserId: userId,
      actionType: 'KICK',
    },
  });
  if (isKicked) {
    const error = new Error('You have been kicked from this room session');
    error.statusCode = 403;
    error.status = 403;
    error.code = 'ROOM_KICKED';
    throw error;
  }

  // Check if user is muted by moderation in this room
  const isModMuted = await db.roomModeration.findFirst({
    where: {
      roomId: room.id,
      targetUserId: userId,
      actionType: 'MUTE_MIC',
    },
  });

  // 3. Derive user role in room from authoritative database state
  // For interactive party and live streaming rooms, active members are granted BROADCASTER (PUBLISHER)
  // privilege so they can take an open seat and speak immediately without token revocation errors.
  // When not seated, the client joins as clientRoleAudience to prevent sending audio or consuming upstream bandwidth.
  // If the user has been muted by a moderator (MUTE_MIC), their token is strictly locked to AUDIENCE.
  const isModBanned = Boolean(isModMuted);
  const role = isModBanned ? AGORA_ROLES.AUDIENCE : AGORA_ROLES.BROADCASTER;

  // 4. Derive integer UID
  const uid = deriveAgoraUid(userId);
  const expirySeconds = env.AGORA_TOKEN_EXPIRY_SECONDS || 3600;
  const expiresAt = new Date(Date.now() + expirySeconds * 1000).toISOString();

  // 5. Generate short-lived token
  const token = generateAgoraRtcToken({
    appId: (env.AGORA_APP_ID && !env.AGORA_APP_ID.includes('mock_agora')) ? env.AGORA_APP_ID : '970ca35de60c44645bbae8a215061401',
    appCertificate: env.AGORA_APP_CERTIFICATE,
    channelName: room.agoraChannelName,
    uid,
    role,
    expirySeconds,
  });

  // Subscribe connected sockets of regular user to the room channel
  let userIdentity = null;
  if (user) {
    userIdentity = formatAuthoritativeUserIdentity(user, {
      role: room.creatorUserId === userId ? 'HOST' : 'PARTICIPANT',
    });
    await socketEmitter.joinUserSocketsToRoom(userId, room.id, userIdentity).catch(() => {});
  }

  return {
    token,
    roomId: room.id,
    channelName: room.agoraChannelName,
    agoraUid: uid,
    uid,
    hostUserId: room.creatorUserId,
    hostAgoraUid: deriveAgoraUid(room.creatorUserId),
    userId,
    userIdentity,
    role,
    appId: (env.AGORA_APP_ID && !env.AGORA_APP_ID.includes('mock_agora')) ? env.AGORA_APP_ID : '970ca35de60c44645bbae8a215061401',
    expiresInSeconds: expirySeconds,
    expiresIn: expirySeconds,
    expiresAt,
  };
}

/**
 * Refreshes an Agora RTC token after repeating all authorization checks.
 */
export async function refreshRoomAgoraToken({ roomId, userId }, db = prisma) {
  return await issueRoomAgoraToken({ roomId, userId }, db);
}

export default {
  issueRoomAgoraToken,
  refreshRoomAgoraToken,
};
