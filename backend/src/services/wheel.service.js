import prisma from '../config/database.js';
import socketEmitter from '../socket/socket.emitter.js';

/**
 * Server-Authoritative Multi-Participant Elimination Lucky Wheel Service
 *
 * Implements full round lifecycle:
 * 1. createSession (LOBBY)
 * 2. joinSession (atomic coin deduction if entryCoinFee > 0, deduplicated)
 * 3. spinRound (random server-side elimination of active participants, round progression)
 * 4. winner finalization (sole survivor receives pot/rewardCoins atomically)
 * 5. cancelSession (safe refund of entry fees to joined players)
 * 6. getActiveSession (reconnection and snapshot recovery)
 */

// Active sessions memory map: roomId -> WheelSession
const activeSessionsByRoom = new Map();
// By sessionId -> WheelSession
const sessionsById = new Map();

export async function createWheelSession(
  roomId,
  { entryCoinFee = 0, maxParticipants = 10, rewardCoins = 0, onlySeatedMics = false, actorUserId },
  db = prisma
) {
  // Resolve room
  let canonicalRoomId = roomId;
  let room = await db.room.findUnique({ where: { id: roomId } }).catch(() => null);
  if (room) {
    canonicalRoomId = room.id;
  } else if (roomId.length <= 16) {
    room = await db.room.findFirst({
      where: { id: { startsWith: roomId, mode: 'insensitive' } },
    }).catch(() => null);
    if (room) canonicalRoomId = room.id;
  }

  if (!room) {
    const error = new Error('Room not found');
    error.statusCode = 404;
    error.code = 'ROOM_NOT_FOUND';
    throw error;
  }

  // Authorization check: Host, Co-Host, or Moderator
  const isCreator = room.creatorUserId === actorUserId;
  let isAuthorized = isCreator;
  if (!isAuthorized && actorUserId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: canonicalRoomId,
        userId: actorUserId,
        role: { in: ['OWNER', 'CO_HOST', 'MODERATOR', 'ADMIN'] },
      },
    }).catch(() => null);
    if (member) isAuthorized = true;
  }

  if (!isAuthorized) {
    const error = new Error('Only the room host or moderator can create a Lucky Wheel session');
    error.statusCode = 403;
    error.code = 'FORBIDDEN';
    throw error;
  }

  // Check if an existing session is in progress
  const existing = activeSessionsByRoom.get(canonicalRoomId);
  if (existing && existing.status === 'IN_PROGRESS') {
    const error = new Error('A Lucky Wheel round is currently in progress');
    error.statusCode = 409;
    error.code = 'GAME_IN_PROGRESS';
    throw error;
  }

  const fee = Math.max(0, parseInt(entryCoinFee, 10) || 0);
  const maxP = Math.min(50, Math.max(2, parseInt(maxParticipants, 10) || 10));
  const reward = Math.max(0, parseInt(rewardCoins, 10) || 0);

  const sessionId = `wheel_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const session = {
    id: sessionId,
    sessionId,
    roomId: canonicalRoomId,
    clientRoomId: roomId,
    creatorUserId: actorUserId,
    entryCoinFee: fee,
    maxParticipants: maxP,
    rewardCoins: reward,
    onlySeatedMics: Boolean(onlySeatedMics),
    status: 'LOBBY', // 'LOBBY' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED'
    participants: [],
    eliminatedParticipants: [],
    currentRound: 0,
    winner: null,
    createdAt: new Date().toISOString(),
    startedAt: null,
    completedAt: null,
  };

  activeSessionsByRoom.set(canonicalRoomId, session);
  sessionsById.set(sessionId, session);

  // Broadcast to room
  socketEmitter.emitToRoom(canonicalRoomId, 'wheel:session_created', session);
  if (canonicalRoomId !== roomId) {
    socketEmitter.emitToRoom(roomId, 'wheel:session_created', session);
  }

  return session;
}

export async function joinWheelSession({ sessionId, roomId, userId, user }, db = prisma) {
  let session = null;
  if (sessionId) {
    session = sessionsById.get(sessionId);
  }
  if (!session && roomId) {
    session = activeSessionsByRoom.get(roomId);
  }

  if (!session) {
    const error = new Error('No active Lucky Wheel session found');
    error.statusCode = 404;
    error.code = 'SESSION_NOT_FOUND';
    throw error;
  }

  if (session.status !== 'LOBBY') {
    const error = new Error('Cannot join: Lucky Wheel round has already started or ended');
    error.statusCode = 400;
    error.code = 'GAME_ALREADY_STARTED';
    throw error;
  }

  // Check duplicate
  if (session.participants.some((p) => p.userId === userId)) {
    const error = new Error('User has already joined this Lucky Wheel round');
    error.statusCode = 400;
    error.code = 'ALREADY_JOINED';
    throw error;
  }

  // Check capacity
  if (session.participants.length >= session.maxParticipants) {
    const error = new Error('Lucky Wheel round has reached maximum capacity');
    error.statusCode = 400;
    error.code = 'SESSION_FULL';
    throw error;
  }

  // If seated mics only rule is enabled, verify participant is on mic
  if (session.onlySeatedMics) {
    const seat = await db.roomSeat.findFirst({
      where: { roomId: session.roomId, occupiedUserId: userId },
    }).catch(() => null);
    if (!seat) {
      const error = new Error('Only participants on microphone seats can join this wheel session');
      error.statusCode = 403;
      error.code = 'MUST_BE_ON_MIC';
      throw error;
    }
  }

  // Atomic Entry Fee Deduction
  if (session.entryCoinFee > 0) {
    const updated = await (db || prisma).wallet.updateMany({
      where: {
        userId,
        coinBalance: { gte: BigInt(session.entryCoinFee) },
      },
      data: {
        coinBalance: { decrement: BigInt(session.entryCoinFee) },
      },
    });

    if (updated.count === 0) {
      const error = new Error(
        `Insufficient coin balance. Required: ${session.entryCoinFee}`
      );
      error.statusCode = 400;
      error.code = 'INSUFFICIENT_BALANCE';
      throw error;
    }
  }

  // Resolve user display info
  let effectiveName = user?.displayName || user?.name || user?.username;
  let effectiveAvatar = user?.avatarUrl;
  if (!effectiveName) {
    const dbUser = await db.user.findUnique({
      where: { id: userId },
      select: { username: true, avatarUrl: true, profile: { select: { displayName: true } } },
    }).catch(() => null);
    if (dbUser) {
      effectiveName = dbUser.profile?.displayName || dbUser.username;
      effectiveAvatar = dbUser.avatarUrl;
    }
  }

  const participant = {
    userId,
    name: effectiveName || 'Player',
    displayName: effectiveName || 'Player',
    avatarUrl: effectiveAvatar || null,
    joinedAt: new Date().toISOString(),
  };

  session.participants.push(participant);

  const payload = {
    sessionId: session.id,
    roomId: session.roomId,
    participant,
    participants: session.participants,
    totalJoined: session.participants.length,
    maxParticipants: session.maxParticipants,
  };

  socketEmitter.emitToRoom(session.roomId, 'wheel:participant_joined', payload);

  return {
    success: true,
    participant,
    session,
  };
}

export async function spinWheelRound({ sessionId, roomId, actorUserId }, db = prisma) {
  let session = null;
  if (sessionId) {
    session = sessionsById.get(sessionId);
  }
  if (!session && roomId) {
    session = activeSessionsByRoom.get(roomId);
  }

  if (!session) {
    const error = new Error('No active Lucky Wheel session found');
    error.statusCode = 404;
    error.code = 'SESSION_NOT_FOUND';
    throw error;
  }

  if (session.status === 'COMPLETED' || session.status === 'CANCELLED') {
    const error = new Error(`Lucky Wheel session is already ${session.status.toLowerCase()}`);
    error.statusCode = 400;
    error.code = 'SESSION_CLOSED';
    throw error;
  }

  // Authorization check: creator or moderator
  if (actorUserId && session.creatorUserId !== actorUserId) {
    const member = await db.roomMember.findFirst({
      where: {
        roomId: session.roomId,
        userId: actorUserId,
        role: { in: ['OWNER', 'CO_HOST', 'MODERATOR', 'ADMIN'] },
      },
    }).catch(() => null);
    if (!member) {
      const error = new Error('Only the session controller or host can spin the wheel');
      error.statusCode = 403;
      error.code = 'FORBIDDEN';
      throw error;
    }
  }

  // Active participants are those not yet eliminated
  const eliminatedUserIds = new Set(session.eliminatedParticipants.map((e) => e.userId));
  const activeParticipants = session.participants.filter((p) => !eliminatedUserIds.has(p.userId));

  if (activeParticipants.length < 2) {
    const error = new Error('Cannot spin: At least 2 active participants are required');
    error.statusCode = 400;
    error.code = 'NOT_ENOUGH_PARTICIPANTS';
    throw error;
  }

  session.status = 'IN_PROGRESS';
  if (!session.startedAt) session.startedAt = new Date().toISOString();
  session.currentRound += 1;

  // Authoritatively select ONE participant to eliminate at random
  const eliminateIndex = Math.floor(Math.random() * activeParticipants.length);
  const eliminatedUser = activeParticipants[eliminateIndex];

  // Calculate visual rotation angle for clients (0-360)
  const segmentSize = 360 / activeParticipants.length;
  const targetAngleDegrees = Math.round(eliminateIndex * segmentSize + segmentSize / 2);

  const eliminationRecord = {
    userId: eliminatedUser.userId,
    displayName: eliminatedUser.displayName,
    avatarUrl: eliminatedUser.avatarUrl,
    roundNumber: session.currentRound,
    eliminatedAt: new Date().toISOString(),
  };
  session.eliminatedParticipants.push(eliminationRecord);

  const remainingActive = activeParticipants.filter((p) => p.userId !== eliminatedUser.userId);
  const isFinalRound = remainingActive.length === 1;

  let winner = null;
  let rewardCoinsAwarded = 0;

  if (isFinalRound) {
    winner = remainingActive[0];
    session.winner = winner;
    session.status = 'COMPLETED';
    session.completedAt = new Date().toISOString();

    // Calculate reward: configured prize or accumulated pot
    rewardCoinsAwarded = session.rewardCoins > 0
      ? session.rewardCoins
      : (session.entryCoinFee * session.participants.length);

    // Atomically credit winner
    if (rewardCoinsAwarded > 0) {
      try {
        await (db || prisma).wallet.updateMany({
          where: { userId: winner.userId },
          data: { coinBalance: { increment: BigInt(rewardCoinsAwarded) } },
        });
      } catch (err) {
        console.error('[LuckyWheel] Winner credit error:', err);
      }
    }
  }

  const roundPayload = {
    sessionId: session.id,
    roomId: session.roomId,
    roundNumber: session.currentRound,
    eliminatedUserId: eliminatedUser.userId,
    eliminatedUser,
    remainingUserIds: remainingActive.map((p) => p.userId),
    remainingCount: remainingActive.length,
    targetAngleDegrees,
    isFinalRound,
  };

  // Broadcast round elimination
  socketEmitter.emitToRoom(session.roomId, 'wheel:round_eliminated', roundPayload);

  // If winner finalized, emit completion event
  if (isFinalRound) {
    const completedPayload = {
      sessionId: session.id,
      roomId: session.roomId,
      winnerUserId: winner.userId,
      winner,
      rewardCoins: rewardCoinsAwarded,
      totalRounds: session.currentRound,
      participantsCount: session.participants.length,
      eliminatedParticipants: session.eliminatedParticipants,
    };
    socketEmitter.emitToRoom(session.roomId, 'wheel:session_completed', completedPayload);
  }

  return {
    success: true,
    round: roundPayload,
    isFinalRound,
    winner,
    rewardCoins: rewardCoinsAwarded,
  };
}

export async function cancelWheelSession({ sessionId, roomId, actorUserId }, db = prisma) {
  let session = null;
  if (sessionId) session = sessionsById.get(sessionId);
  if (!session && roomId) session = activeSessionsByRoom.get(roomId);

  if (!session) {
    const error = new Error('No active Lucky Wheel session found');
    error.statusCode = 404;
    error.code = 'SESSION_NOT_FOUND';
    throw error;
  }

  if (session.status === 'COMPLETED') {
    const error = new Error('Cannot cancel a completed session');
    error.statusCode = 400;
    error.code = 'SESSION_ALREADY_COMPLETED';
    throw error;
  }

  // Safe Refund of Entry Fees
  if (session.entryCoinFee > 0 && session.participants.length > 0) {
    for (const participant of session.participants) {
      try {
        await db.wallet.updateMany({
          where: { userId: participant.userId },
          data: { coinBalance: { increment: BigInt(session.entryCoinFee) } },
        });
      } catch (err) {
        console.error(`[LuckyWheel] Refund failed for ${participant.userId}:`, err);
      }
    }
  }

  session.status = 'CANCELLED';
  session.completedAt = new Date().toISOString();

  const payload = {
    sessionId: session.id,
    roomId: session.roomId,
    cancelledBy: actorUserId,
    refundedCoinFee: session.entryCoinFee,
    participantsCount: session.participants.length,
  };

  socketEmitter.emitToRoom(session.roomId, 'wheel:session_cancelled', payload);

  return {
    success: true,
    message: 'Lucky Wheel session cancelled and participant entry fees refunded',
    data: payload,
  };
}

export function getActiveWheelSession(roomId) {
  return activeSessionsByRoom.get(roomId) || null;
}

export default {
  createWheelSession,
  joinWheelSession,
  spinWheelRound,
  cancelWheelSession,
  getActiveWheelSession,
};
