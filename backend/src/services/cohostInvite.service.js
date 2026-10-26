import prisma from '../config/database.js';
import redisProxy from '../config/redis.js';
import roomRepository from '../repositories/room.repository.js';
import presenceService from '../socket/presence.service.js';
import socketEmitter from '../socket/socket.emitter.js';
import stageService from './stage.service.js';

// In-memory fallback stores for distributed or non-Redis local testing
const localCoHostInviteStore = new Map();
const localCoHostTargetMap = new Map(); // key: `${roomId}:${targetUserId}` -> inviteId

const COHOST_INVITE_TTL_SECONDS = 60;

function cleanLocalExpired() {
  const now = Date.now();
  for (const [id, invite] of localCoHostInviteStore.entries()) {
    if (new Date(invite.expiresAt).getTime() <= now) {
      localCoHostInviteStore.delete(id);
      localCoHostTargetMap.delete(`${invite.roomId}:${invite.targetUserId}`);
    }
  }
}

/**
 * Resolves room by ID or prefix.
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
 * Persists a co-host invitation to Redis and local fallback.
 */
async function saveCoHostInvitation(invitation) {
  const inviteJson = JSON.stringify(invitation);
  const redisKeyTarget = `cohost_invite:room:${invitation.roomId}:target:${invitation.targetUserId}`;
  const redisKeyId = `cohost_invite:${invitation.id}`;
  const redisKeyUserList = `cohost_invites:user:${invitation.targetUserId}`;

  if (redisProxy.isOpen) {
    try {
      await redisProxy.set(redisKeyTarget, inviteJson, { EX: COHOST_INVITE_TTL_SECONDS });
      await redisProxy.set(redisKeyId, inviteJson, { EX: COHOST_INVITE_TTL_SECONDS });
      await redisProxy.sAdd(redisKeyUserList, invitation.id);
      await redisProxy.expire(redisKeyUserList, COHOST_INVITE_TTL_SECONDS);
    } catch (_) {}
  }

  localCoHostInviteStore.set(invitation.id, invitation);
  localCoHostTargetMap.set(`${invitation.roomId}:${invitation.targetUserId}`, invitation.id);
}

/**
 * Removes a co-host invitation.
 */
async function deleteCoHostInvitation(roomId, targetUserId, invitationId) {
  const redisKeyTarget = `cohost_invite:room:${roomId}:target:${targetUserId}`;
  const redisKeyId = `cohost_invite:${invitationId}`;
  const redisKeyUserList = `cohost_invites:user:${targetUserId}`;

  if (redisProxy.isOpen) {
    try {
      await redisProxy.del(redisKeyTarget);
      if (invitationId) {
        await redisProxy.del(redisKeyId);
        await redisProxy.sRem(redisKeyUserList, invitationId);
      }
    } catch (_) {}
  }

  if (invitationId) localCoHostInviteStore.delete(invitationId);
  localCoHostTargetMap.delete(`${roomId}:${targetUserId}`);
}

/**
 * Find active pending co-host invitation for target user in room.
 */
export async function getActiveCoHostInviteForUser(roomId, targetUserId) {
  cleanLocalExpired();
  const redisKey = `cohost_invite:room:${roomId}:target:${targetUserId}`;

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

  const localId = localCoHostTargetMap.get(`${roomId}:${targetUserId}`);
  if (localId && localCoHostInviteStore.has(localId)) {
    const invite = localCoHostInviteStore.get(localId);
    if (new Date(invite.expiresAt).getTime() > Date.now()) {
      return invite;
    }
    localCoHostInviteStore.delete(localId);
    localCoHostTargetMap.delete(`${roomId}:${targetUserId}`);
  }

  return null;
}

/**
 * Retrieve co-host invitation by its stable invitation ID.
 */
export async function getCoHostInviteById(invitationId) {
  cleanLocalExpired();
  const redisKey = `cohost_invite:${invitationId}`;

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

  if (localCoHostInviteStore.has(invitationId)) {
    const invite = localCoHostInviteStore.get(invitationId);
    if (new Date(invite.expiresAt).getTime() > Date.now()) {
      return invite;
    }
    localCoHostInviteStore.delete(invitationId);
    localCoHostTargetMap.delete(`${invite.roomId}:${invite.targetUserId}`);
  }

  return null;
}

/**
 * Retrieve all active pending co-host invitations for a user (across rooms or for a specific room).
 * Essential for reconnect / app resume recovery.
 */
export async function getPendingCoHostInvitesForUser(userId, roomId = null) {
  cleanLocalExpired();
  const results = [];

  // 1. Check local in-memory store
  for (const invite of localCoHostInviteStore.values()) {
    if (invite.targetUserId === userId && new Date(invite.expiresAt).getTime() > Date.now()) {
      if (!roomId || invite.roomId === roomId) {
        results.push(invite);
      }
    }
  }

  // 2. Check Redis if available
  if (redisProxy.isOpen) {
    try {
      const redisKeyUserList = `cohost_invites:user:${userId}`;
      const inviteIds = await redisProxy.sMembers(redisKeyUserList);
      for (const invId of inviteIds) {
        if (!results.some((r) => r.id === invId)) {
          const raw = await redisProxy.get(`cohost_invite:${invId}`);
          if (raw) {
            const parsed = JSON.parse(raw);
            if (new Date(parsed.expiresAt).getTime() > Date.now()) {
              if (!roomId || parsed.roomId === roomId) {
                results.push(parsed);
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  return results;
}

/**
 * Create a valid, persistent Co-Host invitation and deliver it over Socket.IO.
 */
export async function createCoHostInvite(
  { roomId, actorUserId, targetUserId, seatIndex = 1 },
  db = prisma
) {
  if (!roomId || !actorUserId || !targetUserId) {
    const error = new Error('roomId, actorUserId, and targetUserId are required');
    error.statusCode = 400;
    error.code = 'VALIDATION_ERROR';
    throw error;
  }

  const room = await resolveRoom(roomId, db);
  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomLive = ['LIVE', 'ACTIVE', 'OPEN'].includes((room.status || '').toUpperCase());
  if (!isRoomLive) {
    const error = new Error('Live room is not active or has ended');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  // 1. Authorization: Only room creator, active host, or authorized room admin/moderator can invite co-host
  const isOwner = room.creatorUserId === actorUserId;
  let isAuthorized = isOwner;

  if (!isAuthorized) {
    const actorMember = await db.roomMember.findUnique({
      where: { roomId_userId: { roomId: room.id, userId: actorUserId } },
    });
    if (actorMember && ['HOST', 'CO_HOST', 'ADMIN', 'MODERATOR'].includes((actorMember.role || '').toUpperCase())) {
      isAuthorized = true;
    }
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or authorized administrators can invite co-hosts');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // 2. Validate Target User Eligibility
  if (targetUserId === actorUserId) {
    const error = new Error('Cannot invite yourself to co-host');
    error.statusCode = 400;
    error.code = 'CANNOT_INVITE_SELF';
    throw error;
  }

  if (targetUserId === room.creatorUserId) {
    const error = new Error('Room owner already has primary host privileges');
    error.statusCode = 400;
    error.code = 'CANNOT_INVITE_OWNER';
    throw error;
  }

  // Check for duplicate pending invitation
  const existingPending = await getActiveCoHostInviteForUser(room.id, targetUserId);
  if (existingPending) {
    const error = new Error('A co-host invitation is already pending for this user');
    error.statusCode = 409;
    error.code = 'PENDING_INVITE_EXISTS';
    throw error;
  }

  // Check target user exists in DB
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

  if (!targetUser) {
    const error = new Error('Target user account not found');
    error.statusCode = 404;
    error.code = 'USER_NOT_FOUND';
    throw error;
  }

  const inviterName = inviterUser?.profile?.displayName || inviterUser?.username || 'Host';
  const targetName = targetUser?.profile?.displayName || targetUser?.username || `User_${String(targetUserId).substring(0, 6)}`;

  const now = new Date();
  const expiresAt = new Date(now.getTime() + COHOST_INVITE_TTL_SECONDS * 1000);
  const invitationId = `cohost_inv_${room.id}_${targetUserId}_${Date.now()}`;

  // Assemble stable invitation payload matching Flutter mobile client contracts
  const invitation = {
    id: invitationId,
    invitationId,
    roomId: room.id,
    canonicalRoomId: room.id,
    roomTitle: room.title,
    inviterUserId: actorUserId,
    targetUserId,
    recipientId: targetUserId,
    seatIndex: seatIndex || 1,
    status: 'pending',
    inviter: {
      id: actorUserId,
      userId: actorUserId,
      name: inviterName,
      displayName: inviterName,
      avatarUrl: inviterUser?.avatarUrl || '',
      isOwner,
    },
    targetUser: {
      id: targetUserId,
      userId: targetUserId,
      name: targetName,
      displayName: targetName,
      avatarUrl: targetUser?.avatarUrl || '',
    },
    room: {
      id: room.id,
      title: room.title,
      roomType: room.roomType,
    },
    createdAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    expiresInSeconds: COHOST_INVITE_TTL_SECONDS,
  };

  // Persist invitation
  await saveCoHostInvitation(invitation);

  // 3. Deliver via existing Socket.IO real-time channels
  // Direct emission to target user's private channel user:${targetUserId}
  socketEmitter.emitToUser(targetUserId, 'room:cohost_invite', invitation);
  socketEmitter.emitToUser(targetUserId, 'cohost_invite', invitation);
  socketEmitter.emitToUser(targetUserId, 'room:cohost_invitation', invitation);

  // Broadcast to room channel so UI can reflect pending state
  const pendingNotification = {
    roomId: room.id,
    invitationId,
    targetUserId,
    inviterUserId: actorUserId,
    status: 'pending',
    isPending: true,
    expiresAt: expiresAt.toISOString(),
  };
  socketEmitter.emitToRoom(room.id, 'room:cohost_invite_sent', pendingNotification);
  socketEmitter.emitToUser(actorUserId, 'room:cohost_invite_sent', pendingNotification);

  return invitation;
}

/**
 * Accept a Co-Host invitation.
 * Concurrency-safely allocates Seat 1 (Co-Host seat) or next available slot,
 * joins the live session as CO_HOST, and broadcasts updates.
 * CRITICAL: Acceptance is session-scoped and never creates a permanent Live Host approval!
 */
export async function acceptCoHostInvite(
  { roomId, invitationId, userId },
  db = prisma
) {
  const invitation = (invitationId ? await getCoHostInviteById(invitationId) : null)
    || await getActiveCoHostInviteForUser(roomId, userId);

  if (!invitation || invitation.status !== 'pending') {
    const error = new Error('Co-host invitation has expired or is no longer valid');
    error.statusCode = 400;
    error.code = 'INVITATION_EXPIRED';
    throw error;
  }

  if (invitation.targetUserId !== userId) {
    const error = new Error('Only the intended recipient can accept this co-host invitation');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  const room = await resolveRoom(invitation.roomId, db);
  if (!room) {
    await deleteCoHostInvitation(invitation.roomId, userId, invitation.id);
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  const isRoomLive = ['LIVE', 'ACTIVE', 'OPEN'].includes((room.status || '').toUpperCase());
  if (!isRoomLive) {
    await deleteCoHostInvitation(invitation.roomId, userId, invitation.id);
    const error = new Error('Live room has ended; cannot accept invitation');
    error.statusCode = 400;
    error.code = 'ROOM_NOT_LIVE';
    throw error;
  }

  // Execute acceptance and slot allocation in a database transaction
  const result = await db.$transaction(async (tx) => {
    // Determine target seat: prefer seat 1 (Co-Host mic seat), fallback to first available unassigned seat
    let targetSeatIndex = invitation.seatIndex || 1;
    const existingSeats = await tx.roomSeat.findMany({
      where: { roomId: room.id },
      orderBy: { seatIndex: 'asc' },
    });

    const seat1 = existingSeats.find((s) => s.seatIndex === 1);
    if (seat1 && seat1.occupiedUserId && seat1.occupiedUserId !== userId) {
      // Seat 1 is already taken by someone else; find next available seat
      const availableSeat = existingSeats.find((s) => s.seatIndex > 0 && !s.occupiedUserId && !s.isLocked);
      if (!availableSeat) {
        const error = new Error('All co-host and guest seats are currently occupied');
        error.statusCode = 409;
        error.code = 'ROOM_SEATS_FULL';
        throw error;
      }
      targetSeatIndex = availableSeat.seatIndex;
    }

    // Allocate seat
    const updatedSeat = await tx.roomSeat.upsert({
      where: {
        roomId_seatIndex: {
          roomId: room.id,
          seatIndex: targetSeatIndex,
        },
      },
      update: {
        occupiedUserId: userId,
        isLocked: false,
        isMuted: false,
      },
      create: {
        roomId: room.id,
        seatIndex: targetSeatIndex,
        occupiedUserId: userId,
        isLocked: false,
        isMuted: false,
      },
      include: {
        occupiedUser: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: { select: { displayName: true } },
          },
        },
      },
    });

    // Update or add roomMember record with role: 'CO_HOST'
    const member = await tx.roomMember.upsert({
      where: {
        roomId_userId: {
          roomId: room.id,
          userId,
        },
      },
      update: {
        role: 'CO_HOST',
      },
      create: {
        roomId: room.id,
        userId,
        role: 'CO_HOST',
      },
    });

    return { seat: updatedSeat, member, targetSeatIndex };
  }, { maxWait: 10000, timeout: 20000 });

  // Delete pending invitation now that it has been successfully accepted
  await deleteCoHostInvitation(invitation.roomId, userId, invitation.id);

  // Fetch user profile for broadcast
  const user = await db.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      username: true,
      avatarUrl: true,
      profile: { select: { displayName: true } },
    },
  });

  const userName = user?.profile?.displayName || user?.username || 'Co-Host';

  const responsePayload = {
    invitationId: invitation.id,
    id: invitation.id,
    roomId: room.id,
    targetUserId: userId,
    recipientId: userId,
    accepted: true,
    status: 'accepted',
    seatIndex: result.targetSeatIndex,
    user: {
      id: userId,
      name: userName,
      displayName: userName,
      avatarUrl: user?.avatarUrl || '',
    },
    timestamp: new Date().toISOString(),
  };

  // Broadcast real-time responses
  socketEmitter.emitToRoom(room.id, 'room:cohost_invite_response', responsePayload);
  socketEmitter.emitToRoom(room.id, 'cohost_invite_response', responsePayload);
  socketEmitter.emitToUser(invitation.inviterUserId, 'room:cohost_invite_response', responsePayload);

  // Authoritative stage broadcast (emits room:stage_updated, room:seat_occupied, room:seat_updated, room:cohost_joined)
  let stageSnapshot = null;
  try {
    stageSnapshot = await stageService.notifyStageOccupied({
      roomId: room.id,
      seatIndex: result.targetSeatIndex,
      userId,
      user: responsePayload.user,
      role: 'CO_HOST',
    });
    if (stageSnapshot) {
      responsePayload.stage = stageSnapshot;
      responsePayload.version = stageSnapshot.version;
    }
  } catch (_) {
    // Fallback direct socket emission if stage service encounters an issue
    socketEmitter.emitToRoom(room.id, 'room:seat_updated', {
      roomId: room.id,
      seatIndex: result.targetSeatIndex,
      seat: result.seat,
    });
    socketEmitter.emitToRoom(room.id, 'room:cohost_joined', {
      roomId: room.id,
      userId,
      user: responsePayload.user,
      seatIndex: result.targetSeatIndex,
    });
  }

  return {
    success: true,
    message: 'Co-Host invitation accepted successfully',
    data: responsePayload,
  };
}

/**
 * Decline a Co-Host invitation.
 */
export async function declineCoHostInvite(
  { roomId, invitationId, userId, reason = 'DECLINED_BY_USER' },
  db = prisma
) {
  const invitation = (invitationId ? await getCoHostInviteById(invitationId) : null)
    || await getActiveCoHostInviteForUser(roomId, userId);

  if (!invitation) {
    return { success: true, message: 'Invitation already resolved or expired' };
  }

  if (invitation.targetUserId !== userId) {
    const error = new Error('Only the intended recipient can decline this invitation');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  await deleteCoHostInvitation(invitation.roomId, userId, invitation.id);

  const responsePayload = {
    invitationId: invitation.id,
    id: invitation.id,
    roomId: invitation.roomId,
    targetUserId: userId,
    recipientId: userId,
    accepted: false,
    status: 'declined',
    reason,
    timestamp: new Date().toISOString(),
  };

  // Notify room and inviter
  socketEmitter.emitToRoom(invitation.roomId, 'room:cohost_invite_response', responsePayload);
  socketEmitter.emitToRoom(invitation.roomId, 'cohost_invite_response', responsePayload);
  socketEmitter.emitToUser(invitation.inviterUserId, 'room:cohost_invite_response', responsePayload);

  return {
    success: true,
    message: 'Co-Host invitation declined',
    data: responsePayload,
  };
}

/**
 * Cancel a pending Co-Host invitation by the host.
 */
export async function cancelCoHostInvite(
  { roomId, invitationId, actorUserId },
  db = prisma
) {
  const invitation = await getCoHostInviteById(invitationId);
  if (!invitation) {
    return { success: true, message: 'Invitation already resolved or expired' };
  }

  // Authorization: Only inviter, room creator, or admin can cancel
  const room = await resolveRoom(roomId || invitation.roomId, db);
  const isOwner = room && room.creatorUserId === actorUserId;
  const isInviter = invitation.inviterUserId === actorUserId;

  if (!isOwner && !isInviter) {
    const error = new Error('Only the room host or inviter can cancel this co-host invitation');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  await deleteCoHostInvitation(invitation.roomId, invitation.targetUserId, invitation.id);

  const cancelledPayload = {
    invitationId: invitation.id,
    id: invitation.id,
    roomId: invitation.roomId,
    targetUserId: invitation.targetUserId,
    status: 'cancelled',
    timestamp: new Date().toISOString(),
  };

  socketEmitter.emitToUser(invitation.targetUserId, 'room:cohost_invite_cancelled', cancelledPayload);
  socketEmitter.emitToRoom(invitation.roomId, 'room:cohost_invite_cancelled', cancelledPayload);

  return {
    success: true,
    message: 'Co-Host invitation cancelled',
    data: cancelledPayload,
  };
}

export default {
  createCoHostInvite,
  getActiveCoHostInviteForUser,
  getCoHostInviteById,
  getPendingCoHostInvitesForUser,
  acceptCoHostInvite,
  declineCoHostInvite,
  cancelCoHostInvite,
};
