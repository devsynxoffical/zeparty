import prisma from '../config/database.js';
import redisProxy from '../config/redis.js';
import roomRepository from '../repositories/room.repository.js';
import presenceService from '../socket/presence.service.js';
import socketEmitter from '../socket/socket.emitter.js';
import { SOCKET_EVENTS, SOCKET_ERRORS } from '../socket/socket.constants.js';

// In-memory fallback cache for distributed or local environments
const localInviteStore = new Map();
const localTargetMap = new Map(); // key: `${roomId}:${targetUserId}` -> inviteId

const INVITE_TTL_SECONDS = 60;

function cleanLocalExpired() {
  const now = Date.now();
  for (const [id, invite] of localInviteStore.entries()) {
    if (new Date(invite.expiresAt).getTime() <= now) {
      localInviteStore.delete(id);
      localTargetMap.delete(`${invite.roomId}:${invite.targetUserId}`);
    }
  }
}

/**
 * Resolves room by full ID or prefix match.
 */
async function resolveRoom(roomId, db = prisma) {
  let room = await db.room.findUnique({
    where: { id: roomId },
    include: {
      creator: {
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true } },
        },
      },
      seats: {
        orderBy: { seatIndex: 'asc' },
      },
    },
  });

  if (!room && roomId && roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        },
        seats: {
          orderBy: { seatIndex: 'asc' },
        },
      },
    });
  }

  return room;
}

/**
 * Find active pending invitation for target user in room.
 */
export async function getActiveInviteForUser(roomId, targetUserId) {
  cleanLocalExpired();
  const redisKey = `mic_invite:room:${roomId}:target:${targetUserId}`;

  if (redisProxy.isOpen) {
    try {
      const raw = await redisProxy.get(redisKey);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (new Date(parsed.expiresAt).getTime() > Date.now()) {
          return parsed;
        }
      }
    } catch (_) {}
  }

  const localId = localTargetMap.get(`${roomId}:${targetUserId}`);
  if (localId && localInviteStore.has(localId)) {
    const invite = localInviteStore.get(localId);
    if (new Date(invite.expiresAt).getTime() > Date.now()) {
      return invite;
    }
    localInviteStore.delete(localId);
    localTargetMap.delete(`${roomId}:${targetUserId}`);
  }

  return null;
}

/**
 * Retrieve invitation by its stable invitation ID.
 */
export async function getInviteById(invitationId) {
  cleanLocalExpired();
  const redisKey = `mic_invite:${invitationId}`;

  if (redisProxy.isOpen) {
    try {
      const raw = await redisProxy.get(redisKey);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (new Date(parsed.expiresAt).getTime() > Date.now()) {
          return parsed;
        }
      }
    } catch (_) {}
  }

  if (localInviteStore.has(invitationId)) {
    const invite = localInviteStore.get(invitationId);
    if (new Date(invite.expiresAt).getTime() > Date.now()) {
      return invite;
    }
    localInviteStore.delete(invitationId);
    localTargetMap.delete(`${invite.roomId}:${invite.targetUserId}`);
  }

  return null;
}

/**
 * Persists an invitation to Redis and local fallback.
 */
async function saveInvitation(invitation) {
  const inviteJson = JSON.stringify(invitation);
  const redisKeyTarget = `mic_invite:room:${invitation.roomId}:target:${invitation.targetUserId}`;
  const redisKeyId = `mic_invite:${invitation.id}`;

  if (redisProxy.isOpen) {
    try {
      await redisProxy.set(redisKeyTarget, inviteJson, { EX: INVITE_TTL_SECONDS });
      await redisProxy.set(redisKeyId, inviteJson, { EX: INVITE_TTL_SECONDS });
    } catch (_) {}
  }

  localInviteStore.set(invitation.id, invitation);
  localTargetMap.set(`${invitation.roomId}:${invitation.targetUserId}`, invitation.id);
}

/**
 * Removes an invitation from Redis and local fallback.
 */
async function deleteInvitation(roomId, targetUserId, invitationId) {
  const redisKeyTarget = `mic_invite:room:${roomId}:target:${targetUserId}`;
  const redisKeyId = `mic_invite:${invitationId}`;

  if (redisProxy.isOpen) {
    try {
      await redisProxy.del(redisKeyTarget);
      if (invitationId) await redisProxy.del(redisKeyId);
    } catch (_) {}
  }

  if (invitationId) localInviteStore.delete(invitationId);
  localTargetMap.delete(`${roomId}:${targetUserId}`);
}

/**
 * Change 13: Create and send invitation to mic from Live Viewers list.
 */
export async function createMicInvite(
  { roomId, actorUserId, targetUserId, seatIndex = null },
  db = prisma
) {
  if (!roomId || !actorUserId || !targetUserId) {
    const error = new Error('roomId, actorUserId, and targetUserId are required');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.VALIDATION_ERROR;
    throw error;
  }

  const room = await resolveRoom(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = SOCKET_ERRORS.ROOM_NOT_FOUND;
    throw error;
  }

  const isRoomLive = ['LIVE', 'ACTIVE', 'OPEN'].includes((room.status || '').toUpperCase());
  if (!isRoomLive) {
    const error = new Error('Room is not active or has ended');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.ROOM_NOT_LIVE;
    throw error;
  }

  // 1. Permission Check: Room owner, authorized admin, or super admin
  const isOwner = room.creatorUserId === actorUserId;
  let isAdmin = false;
  if (!isOwner) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
    });
    if (actorMember && ['ADMIN', 'HOST'].includes((actorMember.role || '').toUpperCase())) {
      isAdmin = true;
    }
  }

  if (!isOwner && !isAdmin) {
    const error = new Error('Only the room owner or authorized room admins can invite viewers to mic');
    error.statusCode = 403;
    error.code = SOCKET_ERRORS.FORBIDDEN;
    throw error;
  }

  // 2. Validate Target User Eligibility
  if (targetUserId === actorUserId) {
    const error = new Error('Cannot invite yourself to mic');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.CANNOT_INVITE_SELF;
    throw error;
  }

  if (targetUserId === room.creatorUserId) {
    const error = new Error('Room owner already has full host mic privileges');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.CANNOT_INVITE_OWNER;
    throw error;
  }

  // Verify target is currently in the room
  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId: room.id, userId: targetUserId } },
  });
  let isTargetInPresence = false;
  try {
    const activeUsers = await presenceService.getRoomActiveUsers(room.id);
    isTargetInPresence = activeUsers.some((u) => u.userId === targetUserId || u.id === targetUserId);
  } catch (_) {}

  if (!targetMember && !isTargetInPresence) {
    const error = new Error('Selected viewer is not currently in this room');
    error.statusCode = 404;
    error.code = SOCKET_ERRORS.TARGET_NOT_IN_ROOM;
    throw error;
  }

  // Verify target is not already on mic
  const occupiedSeat = (room.seats || []).find((s) => s.occupiedUserId === targetUserId);
  if (occupiedSeat) {
    const error = new Error('Selected user is already occupying a microphone seat');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.ALREADY_ON_MIC;
    throw error;
  }

  // Check for existing pending invitation (deduplication)
  const existingPending = await getActiveInviteForUser(room.id, targetUserId);
  if (existingPending) {
    const error = new Error('An invitation to mic is already pending for this viewer');
    error.statusCode = 409;
    error.code = SOCKET_ERRORS.PENDING_INVITE_EXISTS;
    throw error;
  }

  // Check if room has available permitted mic seats (seats 1..N that are not locked or occupied)
  const availableSeats = (room.seats || []).filter(
    (s) => s.seatIndex > 0 && !s.isLocked && !s.occupiedUserId
  );
  if (availableSeats.length === 0) {
    const error = new Error('All microphone seats in this room are currently occupied or locked');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.ROOM_FULL;
    throw error;
  }

  let targetSeatIndex = null;
  if (typeof seatIndex === 'number' && seatIndex > 0) {
    const requestedSeat = (room.seats || []).find((s) => s.seatIndex === seatIndex);
    if (requestedSeat && !requestedSeat.isLocked && !requestedSeat.occupiedUserId) {
      targetSeatIndex = seatIndex;
    }
  }

  // Resolve inviter and target profile details
  const [inviterUser, targetUser] = await Promise.all([
    db.user.findUnique({
      where: { id: actorUserId },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        profile: { select: { displayName: true } },
      },
    }),
    db.user.findUnique({
      where: { id: targetUserId },
      select: {
        id: true,
        username: true,
        avatarUrl: true,
        profile: { select: { displayName: true } },
      },
    }),
  ]);

  const inviterName = inviterUser?.profile?.displayName || inviterUser?.username || 'Host';
  const targetName = targetUser?.profile?.displayName || targetUser?.username || `User_${String(targetUserId).substring(0, 6)}`;

  const now = new Date();
  const expiresAt = new Date(now.getTime() + INVITE_TTL_SECONDS * 1000);
  const invitationId = `mic_inv_${room.id}_${targetUserId}_${Date.now()}`;

  // Assemble stable invitation payload (following Item 12: numeric IDs visible, username removal respected)
  const invitation = {
    id: invitationId,
    invitationId,
    roomId: room.id,
    roomTitle: room.title,
    inviterUserId: actorUserId,
    targetUserId,
    seatIndex: targetSeatIndex,
    status: 'PENDING',
    inviter: {
      id: actorUserId,
      userId: actorUserId,
      name: inviterName,
      displayName: inviterName,
      avatarUrl: inviterUser?.avatarUrl || null,
      isOwner,
      isAdmin,
    },
    targetUser: {
      id: targetUserId,
      userId: targetUserId,
      name: targetName,
      displayName: targetName,
      avatarUrl: targetUser?.avatarUrl || null,
    },
    room: {
      id: room.id,
      title: room.title,
      roomType: room.roomType,
    },
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    expiresInSeconds: INVITE_TTL_SECONDS,
  };

  await saveInvitation(invitation);

  // 3. Emit Realtime Events
  // Direct notification to target user
  socketEmitter.emitToUser(targetUserId, SOCKET_EVENTS.MIC_INVITATION_RECEIVED, invitation);
  socketEmitter.emitToUser(targetUserId, 'room:mic_invitation', invitation);
  socketEmitter.emitToUser(targetUserId, 'room:mic_invite_received', invitation);
  socketEmitter.emitToUser(targetUserId, 'room:mic_invitation_received', invitation);
  socketEmitter.emitToUser(targetUserId, 'mic_invitation_received', invitation);
  socketEmitter.emitToUser(targetUserId, 'room_mic_invitation', invitation);

  // Update room participants that this viewer has a pending invite (disables duplicate buttons in Live Viewers)
  const pendingPayload = {
    roomId: room.id,
    invitationId,
    targetUserId,
    inviterUserId: actorUserId,
    status: 'PENDING',
    isPending: true,
    expiresAt: expiresAt.toISOString(),
  };
  socketEmitter.emitToRoom(room.id, 'room:mic_invite_sent', pendingPayload);
  socketEmitter.emitToRoom(room.id, 'room:mic_invite_pending', pendingPayload);
  socketEmitter.emitToUser(actorUserId, 'room:mic_invite_sent', pendingPayload);

  return invitation;
}

/**
 * Change 13: Accept mic invitation. Validates room presence, seats, assigns seat once,
 * broadcasts single mic join message.
 */
export async function acceptMicInvite({ roomId, invitationId, userId }, db = prisma) {
  const invitation = await getInviteById(invitationId) || await getActiveInviteForUser(roomId, userId);

  if (!invitation || invitation.status !== 'PENDING') {
    const error = new Error('Invitation has expired or is no longer valid');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.INVITATION_EXPIRED;
    throw error;
  }

  if (invitation.targetUserId !== userId) {
    const error = new Error('Only the invited viewer can accept this invitation');
    error.statusCode = 403;
    error.code = SOCKET_ERRORS.FORBIDDEN;
    throw error;
  }

  const room = await resolveRoom(invitation.roomId, db);
  if (!room) {
    await deleteInvitation(invitation.roomId, userId, invitation.id);
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = SOCKET_ERRORS.ROOM_NOT_FOUND;
    throw error;
  }

  const isRoomLive = ['LIVE', 'ACTIVE', 'OPEN'].includes((room.status || '').toUpperCase());
  if (!isRoomLive) {
    await deleteInvitation(invitation.roomId, userId, invitation.id);
    const error = new Error('Room is no longer active');
    error.statusCode = 400;
    error.code = SOCKET_ERRORS.ROOM_NOT_LIVE;
    throw error;
  }

  // Validate viewer remains in the room
  const targetMember = await db.roomMember.findUnique({
    where: { roomId_userId: { roomId: room.id, userId } },
  });
  let isTargetInPresence = false;
  try {
    const activeUsers = await presenceService.getRoomActiveUsers(room.id);
    isTargetInPresence = activeUsers.some((u) => u.userId === userId || u.id === userId);
  } catch (_) {}

  if (!targetMember && !isTargetInPresence) {
    await deleteInvitation(room.id, userId, invitation.id);
    const error = new Error('You are no longer in this room');
    error.statusCode = 404;
    error.code = SOCKET_ERRORS.TARGET_NOT_IN_ROOM;
    throw error;
  }

  // Find available permitted mic seat
  let chosenSeatIndex = null;
  const currentSeats = room.seats || [];

  if (typeof invitation.seatIndex === 'number' && invitation.seatIndex > 0) {
    const preferredSeat = currentSeats.find((s) => s.seatIndex === invitation.seatIndex);
    if (preferredSeat && !preferredSeat.isLocked && !preferredSeat.occupiedUserId) {
      chosenSeatIndex = invitation.seatIndex;
    }
  }

  if (chosenSeatIndex === null) {
    const availableSeat = currentSeats.find(
      (s) => s.seatIndex > 0 && !s.isLocked && !s.occupiedUserId
    );
    if (availableSeat) {
      chosenSeatIndex = availableSeat.seatIndex;
    }
  }

  if (chosenSeatIndex === null) {
    // Room filled up before acceptance: clear invite and keep viewer in audience
    await deleteInvitation(room.id, userId, invitation.id);
    socketEmitter.emitToRoom(room.id, 'room:mic_invite_cleared', {
      roomId: room.id,
      invitationId: invitation.id,
      targetUserId: userId,
      reason: 'ROOM_FULL',
    });
    const error = new Error('Room microphone seats are currently full. You remain in the audience.');
    error.statusCode = 409;
    error.code = SOCKET_ERRORS.ROOM_FULL;
    throw error;
  }

  // Atomically occupy the seat
  const seatResult = await roomRepository.occupySeatTx({
    roomId: room.id,
    seatIndex: chosenSeatIndex,
    userId,
  }, db);

  // Clear pending state
  await deleteInvitation(room.id, userId, invitation.id);

  // Resolve user info for broadcast
  const userRec = await db.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      profile: {
        select: {
          displayName: true,
          nobleRank: true,
          vipLevel: true,
        },
      },
    },
  });

  const effectiveName = userRec?.profile?.displayName || userRec?.username || `User_${String(userId).substring(0, 6)}`;
  const effectiveAvatar = userRec?.avatarUrl || null;
  const effectiveVip = Boolean(userRec?.profile?.vipLevel && userRec.profile.vipLevel > 0);
  const effectiveNoble = userRec?.profile?.nobleRank || null;

  const seatPayload = {
    roomId: room.id,
    seatIndex: chosenSeatIndex,
    vacatedSeatIndex: seatResult.vacatedSeatIndex || null,
    user: {
      id: userId,
      userId,
      name: effectiveName,
      displayName: effectiveName,
      avatarUrl: effectiveAvatar,
      isVip: effectiveVip,
      nobleTitle: effectiveNoble,
    },
  };

  // Broadcast authoritative seat occupied
  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_SEAT_OCCUPIED, seatPayload);
  socketEmitter.emitToRoom(room.id, 'seat_occupied', seatPayload);
  socketEmitter.emitToRoom(room.id, 'seat:occupied', seatPayload);
  socketEmitter.emitToRoom(room.id, 'room_seat_occupied', seatPayload);

  // Broadcast single mic join announcement in lower room chat (Bug 09 deduplication)
  const chatPayload = {
    id: `mic_join_${Date.now()}_${userId}`,
    roomId: room.id,
    userId,
    senderId: userId,
    sender: {
      id: userId,
      userId,
      name: effectiveName,
      displayName: effectiveName,
      avatarUrl: effectiveAvatar,
      isVip: effectiveVip,
    },
    user: {
      id: userId,
      userId,
      name: effectiveName,
      displayName: effectiveName,
      avatarUrl: effectiveAvatar,
      isVip: effectiveVip,
    },
    text: `🎙️ ${effectiveName} took Mic ${chosenSeatIndex + 1}.`,
    message: `🎙️ ${effectiveName} took Mic ${chosenSeatIndex + 1}.`,
    content: `🎙️ ${effectiveName} took Mic ${chosenSeatIndex + 1}.`,
    type: 'SYSTEM',
    isSystemMessage: true,
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToRoom(room.id, SOCKET_EVENTS.ROOM_CHAT_MESSAGE, chatPayload);
  socketEmitter.emitToRoom(room.id, 'room:chat', chatPayload);
  socketEmitter.emitToRoom(room.id, 'chat_message', chatPayload);

  // Broadcast invite accepted to room
  socketEmitter.emitToRoom(room.id, 'room:mic_invite_accepted', {
    roomId: room.id,
    invitationId: invitation.id,
    targetUserId: userId,
    seatIndex: chosenSeatIndex,
  });
  socketEmitter.emitToRoom(room.id, 'room:mic_invite_cleared', {
    roomId: room.id,
    invitationId: invitation.id,
    targetUserId: userId,
    status: 'ACCEPTED',
  });

  return {
    success: true,
    message: 'Joined microphone seat successfully',
    data: {
      invitationId: invitation.id,
      roomId: room.id,
      seatIndex: chosenSeatIndex,
      user: seatPayload.user,
    },
  };
}

/**
 * Change 13: Decline mic invitation or report microphone permission denied.
 * Leaves viewer in audience and clears pending state.
 */
export async function declineMicInvite(
  { roomId, invitationId, userId, reason = 'DECLINED_BY_USER' },
  db = prisma
) {
  const invitation = await getInviteById(invitationId) || await getActiveInviteForUser(roomId, userId);

  if (!invitation) {
    return { success: true, message: 'Invitation already resolved or expired' };
  }

  const effectiveRoomId = invitation.roomId || roomId;
  await deleteInvitation(effectiveRoomId, invitation.targetUserId, invitation.id);

  const declinePayload = {
    roomId: effectiveRoomId,
    invitationId: invitation.id,
    targetUserId: invitation.targetUserId,
    inviterUserId: invitation.inviterUserId,
    reason,
    isPermissionDenied: reason === 'PERMISSION_DENIED' || reason === 'MICROPHONE_PERMISSION_DENIED',
  };

  // Notify inviter and room
  socketEmitter.emitToUser(invitation.inviterUserId, 'room:mic_invite_declined', declinePayload);
  socketEmitter.emitToRoom(effectiveRoomId, 'room:mic_invite_declined', declinePayload);
  socketEmitter.emitToRoom(effectiveRoomId, 'room:mic_invite_cleared', {
    roomId: effectiveRoomId,
    invitationId: invitation.id,
    targetUserId: invitation.targetUserId,
    status: 'DECLINED',
    reason,
  });

  return {
    success: true,
    message: reason === 'PERMISSION_DENIED' ? 'Microphone permission denied' : 'Invitation declined',
    data: declinePayload,
  };
}

/**
 * Change 13: Cancel a pending mic invitation by room owner or admin.
 */
export async function cancelMicInvite({ roomId, invitationId, actorUserId }, db = prisma) {
  const invitation = await getInviteById(invitationId);
  if (!invitation) {
    return { success: true, message: 'Invitation already resolved or expired' };
  }

  const room = await resolveRoom(invitation.roomId, db);
  if (room) {
    const isOwner = room.creatorUserId === actorUserId;
    let isAdmin = false;
    if (!isOwner) {
      const actorMember = await db.roomMember.findUnique({
        where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
      });
      if (actorMember && ['ADMIN', 'HOST'].includes((actorMember.role || '').toUpperCase())) {
        isAdmin = true;
      }
    }
    if (!isOwner && !isAdmin) {
      const error = new Error('Only the room owner or authorized room admins can cancel invitations');
      error.statusCode = 403;
      error.code = SOCKET_ERRORS.FORBIDDEN;
      throw error;
    }
  }

  await deleteInvitation(invitation.roomId, invitation.targetUserId, invitation.id);

  const cancelPayload = {
    roomId: invitation.roomId,
    invitationId: invitation.id,
    targetUserId: invitation.targetUserId,
    cancelledByUserId: actorUserId,
    status: 'CANCELLED',
  };

  socketEmitter.emitToUser(invitation.targetUserId, 'room:mic_invite_cancelled', cancelPayload);
  socketEmitter.emitToRoom(invitation.roomId, 'room:mic_invite_cancelled', cancelPayload);
  socketEmitter.emitToRoom(invitation.roomId, 'room:mic_invite_cleared', cancelPayload);

  return {
    success: true,
    message: 'Invitation cancelled',
    data: cancelPayload,
  };
}

/**
 * Clears any pending mic invitations when a user genuinely leaves the room or disconnects.
 */
export async function clearPendingInvitesForUser(roomId, userId) {
  const invite = await getActiveInviteForUser(roomId, userId);
  if (invite) {
    await deleteInvitation(roomId, userId, invite.id);
    const payload = {
      roomId,
      invitationId: invite.id,
      targetUserId: userId,
      reason: 'USER_LEFT',
    };
    socketEmitter.emitToUser(invite.inviterUserId, 'room:mic_invite_expired', payload);
    socketEmitter.emitToRoom(roomId, 'room:mic_invite_cleared', payload);
  }
}

/**
 * Clears all pending mic invitations for a room when it ends or is closed.
 */
export async function clearAllInvitesForRoom(roomId) {
  cleanLocalExpired();
  for (const [id, invite] of localInviteStore.entries()) {
    if (invite.roomId === roomId) {
      localInviteStore.delete(id);
      localTargetMap.delete(`${roomId}:${invite.targetUserId}`);
    }
  }
}

/**
 * Decorates members list with mic invitation eligibility and status for Live Viewers list.
 */
export async function decorateMembersWithMicInviteStatus(roomId, membersList, db = prisma) {
  if (!Array.isArray(membersList) || membersList.length === 0) {
    return membersList;
  }

  let occupiedUserIds = new Set();
  try {
    const seats = await db.roomSeat.findMany({
      where: { roomId, occupiedUserId: { not: null } },
      select: { occupiedUserId: true },
    });
    occupiedUserIds = new Set(seats.map((s) => s.occupiedUserId).filter(Boolean));
  } catch (_) {}

  return await Promise.all(
    membersList.map(async (m) => {
      const uId = m.userId || m.id || m.user?.id;
      const isOwner = Boolean(m.isHost || m.isOwner);
      const isOnMic = occupiedUserIds.has(uId);

      const pendingInvite = await getActiveInviteForUser(roomId, uId);
      const isPendingMicInvite = Boolean(pendingInvite);

      const canInviteToMic = !isOwner && !isOnMic && !isPendingMicInvite;

      return {
        ...m,
        isOnMic,
        canInviteToMic,
        isPendingMicInvite,
        pendingInviteId: pendingInvite?.id || null,
        user: {
          ...(m.user || {}),
          id: uId,
          numericId: String(uId),
          isOnMic,
          canInviteToMic,
          isPendingMicInvite,
        },
      };
    })
  );
}

export default {
  getActiveInviteForUser,
  getInviteById,
  createMicInvite,
  acceptMicInvite,
  declineMicInvite,
  cancelMicInvite,
  clearPendingInvitesForUser,
  clearAllInvitesForRoom,
  decorateMembersWithMicInviteStatus,
};
