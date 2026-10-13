import prisma from '../config/database.js';
import { deriveAgoraUid } from '../utils/agoraToken.util.js';

const TX_CONFIG = { maxWait: 15000, timeout: 30000 };

export class PKRepository {
  /**
   * Check if a user or room has an active PK restriction.
   */
  async checkRestriction({ userId, roomId }, db = prisma) {
    const conditions = [];
    if (userId) {
      conditions.push({ targetType: 'USER', targetId: userId.toString(), status: 'ACTIVE' });
    }
    if (roomId) {
      conditions.push({ targetType: 'ROOM', targetId: roomId.toString(), status: 'ACTIVE' });
    }

    if (conditions.length === 0) return null;

    const active = await db.pKRestriction.findFirst({
      where: {
        OR: conditions,
        AND: [
          {
            OR: [
              { expiresAt: null },
              { expiresAt: { gt: new Date() } },
            ],
          },
        ],
      },
    });

    return active;
  }

  /**
   * Find any active, preparing, or countdown match for a room.
   */
  async findActiveOrPendingMatchForRoom(roomId, db = prisma) {
    if (!roomId) return null;
    return db.pKMatch.findFirst({
      where: {
        OR: [{ roomAId: roomId }, { roomBId: roomId }],
        status: { in: ['PENDING', 'PREPARING', 'COUNTDOWN', 'ACTIVE'] },
      },
      include: {
        roomA: { include: { creator: { select: { id: true, username: true, avatarUrl: true, profile: true } } } },
        roomB: { include: { creator: { select: { id: true, username: true, avatarUrl: true, profile: true } } } },
        hostA: { select: { id: true, username: true, avatarUrl: true, profile: true } },
        hostB: { select: { id: true, username: true, avatarUrl: true, profile: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * Verify room eligibility and operator authorization.
   */
  async verifyRoomEligibility({ roomId, userId }, db = prisma) {
    if (!roomId || !userId) {
      return { eligible: false, code: 'PK_ROOM_NOT_FOUND', error: 'Room ID and User ID are required' };
    }

    const room = await db.room.findUnique({
      where: { id: roomId },
      include: {
        creator: {
          select: { id: true, username: true, avatarUrl: true, profile: true },
        },
        members: {
          where: { userId },
          select: { role: true },
        },
      },
    });

    if (!room) {
      return { eligible: false, code: 'PK_ROOM_NOT_FOUND', error: 'Room does not exist' };
    }

    if (room.status !== 'LIVE') {
      return { eligible: false, code: 'PK_ROOM_INELIGIBLE', error: 'Room is not currently LIVE' };
    }

    if (room.isPrivate) {
      return { eligible: false, code: 'PK_ROOM_INELIGIBLE', error: 'Private rooms cannot participate in PK' };
    }

    // Authorization: Owner or Room Member with Host/Admin role
    const isOwner = room.creatorUserId === userId;
    const isRoomAdmin = room.members.some((m) => m.role === 'ADMIN' || m.role === 'HOST');
    if (!isOwner && !isRoomAdmin) {
      return { eligible: false, code: 'PK_PERMISSION_DENIED', error: 'Only room host or delegated operator may manage PK' };
    }

    // Check restrictions
    const restriction = await this.checkRestriction({ userId, roomId }, db);
    if (restriction) {
      return { eligible: false, code: 'PK_USER_RESTRICTED', error: `PK restricted: ${restriction.reason}` };
    }

    // Check busy status
    const busyMatch = await this.findActiveOrPendingMatchForRoom(roomId, db);
    if (busyMatch) {
      return { eligible: false, code: 'PK_ROOM_BUSY', error: 'Room is already in a PK match or invitation' };
    }

    return { eligible: true, room };
  }

  /**
   * Discover available opponent room/host by Room ID or numeric User ID.
   */
  async discoverOpponent({ query, roomType, excludeRoomId, excludeUserId }, db = prisma) {
    const trimmed = (query || '').trim();
    if (!trimmed) return [];

    const numericQuery = parseInt(trimmed, 10);
    const whereConditions = [
      { id: trimmed },
      { creator: { username: { equals: trimmed, mode: 'insensitive' } } },
    ];

    if (!isNaN(numericQuery) && numericQuery > 0) {
      whereConditions.push({ creator: { profile: { is: { level: { equals: numericQuery } } } } });
    }

    const rooms = await db.room.findMany({
      where: {
        status: 'LIVE',
        isPrivate: false,
        roomType: roomType ? roomType : undefined,
        id: excludeRoomId ? { not: excludeRoomId } : undefined,
        creatorUserId: excludeUserId ? { not: excludeUserId } : undefined,
        OR: whereConditions,
      },
      include: {
        creator: {
          select: {
            id: true,
            username: true,
            avatarUrl: true,
            profile: {
              select: {
                displayName: true,
                level: true,
                vipLevel: true,
              },
            },
          },
        },
      },
      take: 10,
    });

    const results = [];
    for (const r of rooms) {
      const busy = await this.findActiveOrPendingMatchForRoom(r.id, db);
      const restricted = await this.checkRestriction({ userId: r.creatorUserId, roomId: r.id }, db);

      results.push({
        roomId: r.id,
        roomTitle: r.title,
        roomType: r.roomType,
        region: r.category || 'GLOBAL',
        host: {
          id: r.creator.id,
          username: r.creator.username,
          displayName: r.creator.profile?.displayName || r.creator.username,
          avatarUrl: r.creator.avatarUrl || '',
          level: r.creator.profile?.level || 1,
        },
        isEligible: !busy && !restricted,
        ineligibleReason: busy ? 'BUSY' : restricted ? 'RESTRICTED' : null,
      });
    }

    return results;
  }

  /**
   * Create an invitation and initial PKMatch in PENDING status.
   */
  async createInvitationAndMatch({
    roomA,
    roomB,
    inviterUserId,
    targetHostUserId,
    durationSeconds = 300,
    configSnapshot = {},
    invitationTimeoutSeconds = 30,
  }, db = prisma) {
    return db.$transaction(async (tx) => {
      // Re-verify busy status inside transaction
      const busyA = await this.findActiveOrPendingMatchForRoom(roomA.id, tx);
      if (busyA) {
        const err = new Error('Your room is already in an active or pending match.');
        err.code = 'PK_ROOM_BUSY';
        throw err;
      }

      const busyB = await this.findActiveOrPendingMatchForRoom(roomB.id, tx);
      if (busyB) {
        const err = new Error('Opponent room is already in an active or pending match.');
        err.code = 'PK_ROOM_BUSY';
        throw err;
      }

      const now = new Date();
      const expiresAt = new Date(now.getTime() + invitationTimeoutSeconds * 1000);

      const match = await tx.pKMatch.create({
        data: {
          roomAId: roomA.id,
          roomBId: roomB.id,
          hostAUserId: roomA.creatorUserId,
          hostBUserId: targetHostUserId,
          roomType: roomA.roomType,
          region: roomA.category || 'GLOBAL',
          operatorAUserId: inviterUserId,
          operatorBUserId: null,
          status: 'PENDING',
          stateVersion: 1,
          durationSeconds,
          invitationExpiresAt: expiresAt,
          configSnapshotJson: configSnapshot,
        },
      });

      const invitation = await tx.pKInvitation.create({
        data: {
          matchId: match.id,
          inviterUserId,
          targetRoomId: roomB.id,
          targetHostUserId,
          durationSeconds,
          status: 'PENDING',
          expiresAt,
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId: match.id,
          action: 'INVITATION_SENT',
          actorUserId: inviterUserId,
          fromStatus: null,
          toStatus: 'PENDING',
          metadataJson: {
            invitationId: invitation.id,
            targetRoomId: roomB.id,
            durationSeconds,
          },
        },
      });

      return { match, invitation };
    }, TX_CONFIG);
  }

  /**
   * Find invitation by ID with associated match details.
   */
  async findInvitationById(invitationId, db = prisma) {
    return db.pKInvitation.findUnique({
      where: { id: invitationId },
      include: {
        match: {
          include: {
            roomA: { include: { creator: { select: { id: true, username: true, avatarUrl: true, profile: true } } } },
            roomB: { include: { creator: { select: { id: true, username: true, avatarUrl: true, profile: true } } } },
          },
        },
      },
    });
  }

  /**
   * Respond to PK Invitation (ACCEPT or REJECT).
   */
  async respondToInvitation({ invitationId, responderUserId, action, targetRoomId }, db = prisma) {
    return db.$transaction(async (tx) => {
      const invite = await tx.pKInvitation.findUnique({
        where: { id: invitationId },
        include: { match: true },
      });

      if (!invite) {
        const err = new Error('PK Invitation not found.');
        err.code = 'PK_INVITATION_NOT_FOUND';
        throw err;
      }

      if (invite.status !== 'PENDING') {
        const err = new Error(`Invitation is already ${invite.status.toLowerCase()}.`);
        err.code = 'PK_INVALID_STATE';
        throw err;
      }

      if (new Date() > new Date(invite.expiresAt)) {
        await tx.pKInvitation.update({ where: { id: invite.id }, data: { status: 'EXPIRED' } });
        await tx.pKMatch.update({ where: { id: invite.matchId }, data: { status: 'EXPIRED', endReason: 'INVITATION_EXPIRED' } });
        const err = new Error('Invitation has expired.');
        err.code = 'PK_INVITATION_EXPIRED';
        throw err;
      }

      // Check responder authorization (must be target host or target room owner)
      const targetRoom = await tx.room.findUnique({ where: { id: invite.targetRoomId } });
      const isTargetHost = invite.targetHostUserId === responderUserId;
      const isTargetRoomOwner = targetRoom && targetRoom.creatorUserId === responderUserId;
      if (!isTargetHost && !isTargetRoomOwner) {
        const err = new Error('Forbidden: You are not authorized to respond to this invitation.');
        err.code = 'PK_INVITATION_NOT_TARGET';
        throw err;
      }

      const now = new Date();

      if (action === 'REJECT') {
        await tx.pKInvitation.update({
          where: { id: invite.id },
          data: { status: 'REJECTED', respondedAt: now, responderUserId },
        });

        const updatedMatch = await tx.pKMatch.update({
          where: { id: invite.matchId },
          data: {
            status: 'REJECTED',
            endReason: 'INVITATION_REJECTED',
            stateVersion: { increment: 1 },
          },
        });

        await tx.pKLifecycleAudit.create({
          data: {
            matchId: invite.matchId,
            action: 'INVITATION_REJECTED',
            actorUserId: responderUserId,
            fromStatus: 'PENDING',
            toStatus: 'REJECTED',
          },
        });

        return { accepted: false, match: updatedMatch, invitation: invite };
      }

      // ACTION === ACCEPT: Re-verify both rooms are live and not busy
      const busyA = await tx.pKMatch.findFirst({
        where: {
          id: { not: invite.matchId },
          OR: [{ roomAId: invite.match.roomAId }, { roomBId: invite.match.roomAId }],
          status: { in: ['PREPARING', 'COUNTDOWN', 'ACTIVE'] },
        },
      });
      if (busyA) {
        const err = new Error('Inviter room is already participating in another PK match.');
        err.code = 'PK_ROOM_BUSY';
        throw err;
      }

      const busyB = await tx.pKMatch.findFirst({
        where: {
          id: { not: invite.matchId },
          OR: [{ roomAId: invite.targetRoomId }, { roomBId: invite.targetRoomId }],
          status: { in: ['PREPARING', 'COUNTDOWN', 'ACTIVE'] },
        },
      });
      if (busyB) {
        const err = new Error('Your room is already participating in another PK match.');
        err.code = 'PK_ROOM_BUSY';
        throw err;
      }

      const preparationDeadlineAt = new Date(now.getTime() + 15000); // 15s media preparation deadline

      await tx.pKInvitation.update({
        where: { id: invite.id },
        data: { status: 'ACCEPTED', respondedAt: now, responderUserId },
      });

      const updatedMatch = await tx.pKMatch.update({
        where: { id: invite.matchId },
        data: {
          status: 'PREPARING',
          operatorBUserId: responderUserId,
          preparationDeadlineAt,
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId: invite.matchId,
          action: 'INVITATION_ACCEPTED',
          actorUserId: responderUserId,
          fromStatus: 'PENDING',
          toStatus: 'PREPARING',
          metadataJson: { preparationDeadlineAt },
        },
      });

      return { accepted: true, match: updatedMatch, invitation: invite };
    }, TX_CONFIG);
  }

  /**
   * Cancel pending invitation.
   */
  async cancelInvitation({ invitationId, userId, reason = 'Operator cancelled' }, db = prisma) {
    return db.$transaction(async (tx) => {
      const invite = await tx.pKInvitation.findUnique({
        where: { id: invitationId },
        include: { match: true },
      });

      if (!invite) {
        const err = new Error('PK Invitation not found.');
        err.code = 'PK_INVITATION_NOT_FOUND';
        throw err;
      }

      if (invite.inviterUserId !== userId && invite.match.operatorAUserId !== userId) {
        const err = new Error('Forbidden: Only the inviter can cancel this invitation.');
        err.code = 'PK_PERMISSION_DENIED';
        throw err;
      }

      if (invite.status !== 'PENDING') {
        const err = new Error(`Cannot cancel invitation with status ${invite.status}.`);
        err.code = 'PK_INVALID_STATE';
        throw err;
      }

      const now = new Date();
      await tx.pKInvitation.update({
        where: { id: invite.id },
        data: { status: 'CANCELLED', cancelReason: reason },
      });

      const updatedMatch = await tx.pKMatch.update({
        where: { id: invite.matchId },
        data: {
          status: 'CANCELLED',
          endReason: 'INVITATION_CANCELLED',
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId: invite.matchId,
          action: 'INVITATION_CANCELLED',
          actorUserId: userId,
          fromStatus: 'PENDING',
          toStatus: 'CANCELLED',
          metadataJson: { reason },
        },
      });

      return { match: updatedMatch, invitation: invite };
    }, TX_CONFIG);
  }

  /**
   * Update operator readiness and media readiness.
   * If both operators confirm readiness, auto-transitions to COUNTDOWN.
   */
  async setOperatorReady({ matchId, userId, roomId, isReady = true, mediaPrepared = true }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) {
        const err = new Error('PK Match not found.');
        err.code = 'PK_MATCH_NOT_FOUND';
        throw err;
      }

      if (match.status !== 'PREPARING') {
        const err = new Error(`Readiness can only be confirmed in PREPARING status (current: ${match.status}).`);
        err.code = 'PK_INVALID_STATE';
        throw err;
      }

      const isSideA = match.roomAId === roomId || match.operatorAUserId === userId || match.hostAUserId === userId;
      const isSideB = match.roomBId === roomId || match.operatorBUserId === userId || match.hostBUserId === userId;

      if (!isSideA && !isSideB) {
        const err = new Error('Forbidden: User does not belong to this match.');
        err.code = 'PK_PERMISSION_DENIED';
        throw err;
      }

      const updateData = {
        stateVersion: { increment: 1 },
      };

      if (isSideA) {
        updateData.readyA = Boolean(isReady);
        updateData.mediaPreparedA = Boolean(mediaPrepared);
      }
      if (isSideB) {
        updateData.readyB = Boolean(isReady);
        updateData.mediaPreparedB = Boolean(mediaPrepared);
      }

      const effectiveReadyA = isSideA ? Boolean(isReady) : match.readyA;
      const effectiveReadyB = isSideB ? Boolean(isReady) : match.readyB;
      const effectiveMediaA = isSideA ? Boolean(mediaPrepared) : match.mediaPreparedA;
      const effectiveMediaB = isSideB ? Boolean(mediaPrepared) : match.mediaPreparedB;

      const bothReady = effectiveReadyA && effectiveReadyB && effectiveMediaA && effectiveMediaB;

      if (bothReady) {
        updateData.status = 'COUNTDOWN';
        updateData.countdownStartAt = new Date();
      }

      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: updateData,
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: bothReady ? 'COUNTDOWN_STARTED' : 'READINESS_UPDATED',
          actorUserId: userId,
          fromStatus: 'PREPARING',
          toStatus: bothReady ? 'COUNTDOWN' : 'PREPARING',
          metadataJson: {
            readyA: updated.readyA,
            readyB: updated.readyB,
            mediaPreparedA: updated.mediaPreparedA,
            mediaPreparedB: updated.mediaPreparedB,
          },
        },
      });

      return updated;
    }, TX_CONFIG);
  }

  /**
   * Start the PK Battle after the 3-second countdown.
   * Sets authoritative startAt and endAt.
   */
  async startMatch({ matchId }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) {
        const err = new Error('PK Match not found.');
        err.code = 'PK_MATCH_NOT_FOUND';
        throw err;
      }

      if (match.status === 'ACTIVE') {
        return match; // Idempotent
      }

      if (match.status !== 'COUNTDOWN' && match.status !== 'PREPARING') {
        const err = new Error(`Cannot start PK Match in state ${match.status}.`);
        err.code = 'PK_INVALID_STATE';
        throw err;
      }

      const now = new Date();
      const endAt = new Date(now.getTime() + match.durationSeconds * 1000);

      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: {
          status: 'ACTIVE',
          startAt: now,
          endAt,
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: 'MATCH_STARTED',
          actorUserId: match.operatorAUserId,
          fromStatus: match.status,
          toStatus: 'ACTIVE',
          metadataJson: { startAt: now, endAt },
        },
      });

      return updated;
    }, TX_CONFIG);
  }

  /**
   * Transaction-safe, idempotent gift contribution recording.
   * Directly called inside gift transaction commit.
   */
  async recordGiftContribution({
    giftTransactionId,
    senderUserId,
    recipientUserId,
    roomId,
    coins,
    commitTimestamp = new Date(),
  }, db = prisma) {
    const coinVal = BigInt(coins || 0);
    if (coinVal <= 0n) return null;

    return db.$transaction(async (tx) => {
      // Find active match where commitTimestamp falls strictly in startAt <= time < endAt
      const match = await tx.pKMatch.findFirst({
        where: {
          status: 'ACTIVE',
          startAt: { lte: commitTimestamp },
          endAt: { gt: commitTimestamp },
          OR: [
            { hostAUserId: recipientUserId },
            { hostBUserId: recipientUserId },
          ],
        },
      });

      if (!match) {
        return null; // Not part of an active PK window or recipient is not a PK host
      }

      // Check idempotency: giftTransactionId must be unique
      const existing = await tx.pKGiftContribution.findUnique({
        where: { giftTransactionId },
      });
      if (existing) {
        return { match, contribution: existing, duplicate: true };
      }

      const side = match.hostAUserId === recipientUserId ? 'A' : 'B';
      const scoreField = side === 'A' ? 'scoreA' : 'scoreB';

      const contribution = await tx.pKGiftContribution.create({
        data: {
          matchId: match.id,
          giftTransactionId,
          senderUserId,
          recipientUserId,
          side,
          coins: coinVal,
          commitTimestamp,
        },
      });

      const updatedMatch = await tx.pKMatch.update({
        where: { id: match.id },
        data: {
          [scoreField]: { increment: coinVal },
          stateVersion: { increment: 1 },
        },
      });

      return { match: updatedMatch, contribution, side };
    }, TX_CONFIG);
  }

  /**
   * Finalize match authoritatively when duration expires.
   */
  async finishMatch({ matchId, endReason = 'NORMAL_COMPLETION' }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) {
        const err = new Error('PK Match not found.');
        err.code = 'PK_MATCH_NOT_FOUND';
        throw err;
      }

      if (['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED', 'EXPIRED', 'REJECTED'].includes(match.status)) {
        return match; // Idempotent return
      }

      const scoreA = BigInt(match.scoreA || 0);
      const scoreB = BigInt(match.scoreB || 0);

      let winnerHostId = null;
      let isDraw = false;

      if (scoreA > scoreB) {
        winnerHostId = match.hostAUserId;
      } else if (scoreB > scoreA) {
        winnerHostId = match.hostBUserId;
      } else {
        isDraw = true;
      }

      const now = new Date();
      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: {
          status: 'FINISHED',
          winnerHostId,
          isDraw,
          endReason,
          endAt: match.endAt || now,
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: 'MATCH_FINISHED',
          fromStatus: match.status,
          toStatus: 'FINISHED',
          metadataJson: {
            scoreA: scoreA.toString(),
            scoreB: scoreB.toString(),
            winnerHostId,
            isDraw,
            endReason,
          },
        },
      });

      return updated;
    }, TX_CONFIG);
  }

  /**
   * Forfeit match due to host disconnect timeout or intentional exit.
   */
  async forfeitMatch({ matchId, forfeitHostUserId, endReason = 'HOST_FORFEIT' }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) return null;

      if (['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED'].includes(match.status)) {
        return match;
      }

      let winnerHostId = null;
      if (forfeitHostUserId === match.hostAUserId) {
        winnerHostId = match.hostBUserId;
      } else if (forfeitHostUserId === match.hostBUserId) {
        winnerHostId = match.hostAUserId;
      }

      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: {
          status: 'FORFEIT',
          winnerHostId,
          isDraw: false,
          endReason,
          endAt: new Date(),
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: 'MATCH_FORFEITED',
          actorUserId: forfeitHostUserId,
          fromStatus: match.status,
          toStatus: 'FORFEIT',
          metadataJson: { forfeitHostUserId, winnerHostId, endReason },
        },
      });

      return updated;
    }, TX_CONFIG);
  }

  /**
   * Abort match without winner (admin force stop, prep timeout, mutual disconnect).
   */
  async abortMatch({ matchId, actorUserId, endReason = 'ABORTED' }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) return null;

      if (['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED'].includes(match.status)) {
        return match;
      }

      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: {
          status: 'ABORTED',
          winnerHostId: null,
          isDraw: false,
          endReason,
          endAt: new Date(),
          stateVersion: { increment: 1 },
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: 'MATCH_ABORTED',
          actorUserId,
          fromStatus: match.status,
          toStatus: 'ABORTED',
          metadataJson: { endReason },
        },
      });

      return updated;
    }, TX_CONFIG);
  }

  /**
   * Update host connection status and grace timestamp.
   */
  async updateHostConnection({ matchId, hostUserId, status, disconnectedAt }, db = prisma) {
    const match = await db.pKMatch.findUnique({ where: { id: matchId } });
    if (!match) return null;

    const data = {};
    if (match.hostAUserId === hostUserId) {
      data.hostAConnectionStatus = status;
      data.hostADisconnectedAt = disconnectedAt;
    } else if (match.hostBUserId === hostUserId) {
      data.hostBConnectionStatus = status;
      data.hostBDisconnectedAt = disconnectedAt;
    } else {
      return null;
    }

    return db.pKMatch.update({
      where: { id: matchId },
      data,
    });
  }

  /**
   * Calculate top 3 supporters for sides A and B deterministically.
   * Ordering: coins DESC -> reachedAt ASC -> userId ASC
   */
  async getTopSupporters(matchId, db = prisma) {
    const contributions = await db.pKGiftContribution.findMany({
      where: { matchId, isReversed: false },
      orderBy: { commitTimestamp: 'asc' },
    });

    const aggregateSide = (side) => {
      const userMap = new Map();
      for (const c of contributions) {
        if (c.side !== side) continue;
        const uid = c.senderUserId;
        const existing = userMap.get(uid);
        if (!existing) {
          userMap.set(uid, {
            userId: uid,
            totalCoins: BigInt(c.coins),
            earliestTimestamp: c.commitTimestamp,
          });
        } else {
          existing.totalCoins += BigInt(c.coins);
          // earliestTimestamp represents the timestamp when the current total was reached
          existing.earliestTimestamp = c.commitTimestamp;
        }
      }

      const sorted = Array.from(userMap.values()).sort((a, b) => {
        if (b.totalCoins !== a.totalCoins) {
          return b.totalCoins > a.totalCoins ? 1 : -1;
        }
        if (a.earliestTimestamp.getTime() !== b.earliestTimestamp.getTime()) {
          return a.earliestTimestamp.getTime() - b.earliestTimestamp.getTime();
        }
        return a.userId.localeCompare(b.userId);
      });

      return sorted.slice(0, 3);
    };

    const topA = aggregateSide('A');
    const topB = aggregateSide('B');

    const fetchUserDetails = async (items) => {
      const uids = items.map((i) => i.userId);
      if (uids.length === 0) return [];
      const users = await db.user.findMany({
        where: { id: { in: uids } },
        select: {
          id: true,
          username: true,
          avatarUrl: true,
          profile: { select: { displayName: true } },
        },
      });

      return items.map((item, idx) => {
        const u = users.find((user) => user.id === item.userId);
        return {
          rank: idx + 1,
          userId: item.userId,
          displayName: u?.profile?.displayName || u?.username || 'Supporter',
          avatarUrl: u?.avatarUrl || '',
          totalCoins: Number(item.totalCoins),
        };
      });
    };

    const [supportersA, supportersB] = await Promise.all([
      fetchUserDetails(topA),
      fetchUserDetails(topB),
    ]);

    return { sideASupporters: supportersA, sideBSupporters: supportersB };
  }

  /**
   * Get authoritative match snapshot.
   */
  async getMatchSnapshot(matchId, db = prisma) {
    const match = await db.pKMatch.findUnique({
      where: { id: matchId },
      include: {
        roomA: {
          include: {
            creator: { select: { id: true, username: true, avatarUrl: true, profile: true } },
          },
        },
        roomB: {
          include: {
            creator: { select: { id: true, username: true, avatarUrl: true, profile: true } },
          },
        },
        hostA: { select: { id: true, username: true, avatarUrl: true, profile: true } },
        hostB: { select: { id: true, username: true, avatarUrl: true, profile: true } },
      },
    });

    if (!match) return null;

    let remainingSeconds = match.durationSeconds;
    if (match.status === 'ACTIVE' && match.startAt) {
      const elapsed = Math.floor((Date.now() - new Date(match.startAt).getTime()) / 1000);
      remainingSeconds = Math.max(0, match.durationSeconds - elapsed);
    } else if (['FINISHED', 'FORFEIT', 'ABORTED', 'CANCELLED', 'EXPIRED'].includes(match.status)) {
      remainingSeconds = 0;
    }

    const { sideASupporters, sideBSupporters } = await this.getTopSupporters(matchId, db);

    return {
      id: match.id,
      status: match.status,
      stateVersion: match.stateVersion,
      roomType: match.roomType,
      region: match.region,
      durationSeconds: match.durationSeconds,
      remainingSeconds,
      startAt: match.startAt ? match.startAt.toISOString() : null,
      endAt: match.endAt ? match.endAt.toISOString() : null,
      scoreA: match.scoreA.toString(),
      scoreB: match.scoreB.toString(),
      winnerHostId: match.winnerHostId,
      isDraw: match.isDraw,
      endReason: match.endReason,
      sideA: {
        roomId: match.roomAId,
        roomTitle: match.roomA?.title || '',
        hostId: match.hostAUserId,
        displayName: match.hostA?.profile?.displayName || match.hostA?.username || 'Host Blue',
        avatarUrl: match.hostA?.avatarUrl || '',
        score: match.scoreA.toString(),
        connectionStatus: match.hostAConnectionStatus,
        ready: match.readyA,
        mediaPrepared: match.mediaPreparedA,
      },
      sideB: {
        roomId: match.roomBId,
        roomTitle: match.roomB?.title || '',
        hostId: match.hostBUserId,
        displayName: match.hostB?.profile?.displayName || match.hostB?.username || 'Host Red',
        avatarUrl: match.hostB?.avatarUrl || '',
        score: match.scoreB.toString(),
        connectionStatus: match.hostBConnectionStatus,
        ready: match.readyB,
        mediaPrepared: match.mediaPreparedB,
      },
      topSupportersA: sideASupporters,
      topSupportersB: sideBSupporters,
      agoraRelay: {
        channelA: match.roomA?.agoraChannelName || match.roomAId,
        channelB: match.roomB?.agoraChannelName || match.roomBId,
        hostAUid: deriveAgoraUid(match.hostAUserId),
        hostBUid: deriveAgoraUid(match.hostBUserId),
      },
      createdAt: match.createdAt.toISOString(),
    };
  }

  /**
   * Admin: List Matches.
   */
  async listAdminMatches({ page = 1, limit = 20, status, roomType, search }, db = prisma) {
    const skip = (Number(page) - 1) * Number(limit);
    const where = {};
    if (status) where.status = status;
    if (roomType) where.roomType = roomType;
    if (search) {
      where.OR = [
        { id: { contains: search, mode: 'insensitive' } },
        { roomAId: { contains: search, mode: 'insensitive' } },
        { roomBId: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [total, matches] = await Promise.all([
      db.pKMatch.count({ where }),
      db.pKMatch.findMany({
        where,
        skip,
        take: Number(limit),
        include: {
          roomA: { select: { id: true, title: true } },
          roomB: { select: { id: true, title: true } },
          hostA: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
          hostB: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return { total, matches, page: Number(page), limit: Number(limit) };
  }

  /**
   * User: List Match History.
   */
  async listPKHistory({ userId, roomId, page = 1, limit = 20 }, db = prisma) {
    const skip = (Number(page) - 1) * Number(limit);
    const where = {
      status: { in: ['FINISHED', 'FORFEIT', 'ABORTED'] },
    };
    if (userId) {
      where.OR = [
        { hostAUserId: userId },
        { hostBUserId: userId },
      ];
    } else if (roomId) {
      where.OR = [
        { roomAId: roomId },
        { roomBId: roomId },
      ];
    }

    const [total, matches] = await Promise.all([
      db.pKMatch.count({ where }),
      db.pKMatch.findMany({
        where,
        skip,
        take: Number(limit),
        include: {
          roomA: { select: { id: true, title: true } },
          roomB: { select: { id: true, title: true } },
          hostA: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
          hostB: { select: { id: true, username: true, avatarUrl: true, profile: { select: { displayName: true } } } },
        },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return { total, matches, page: Number(page), limit: Number(limit) };
  }

  /**
   * Background sweeper: Expire stale invitations and detect overdue active matches.
   */
  async sweepStaleMatchesAndInvites(now = new Date(), db = prisma) {
    const expiredInvites = await db.$transaction(async (tx) => {
      const staleInvites = await tx.pKInvitation.findMany({
        where: {
          status: 'PENDING',
          expiresAt: { lte: now },
        },
        include: { match: true },
      });

      for (const inv of staleInvites) {
        await tx.pKInvitation.update({
          where: { id: inv.id },
          data: { status: 'EXPIRED' },
        });
        if (inv.match && inv.match.status === 'PENDING') {
          await tx.pKMatch.update({
            where: { id: inv.match.id },
            data: { status: 'EXPIRED', endReason: 'INVITATION_TIMEOUT' },
          });
          await tx.pKLifecycleAudit.create({
            data: {
              matchId: inv.match.id,
              action: 'INVITATION_EXPIRED',
              actorUserId: 'SYSTEM',
              fromStatus: 'PENDING',
              toStatus: 'EXPIRED',
              metadataJson: { expiredAt: now },
            },
          });
        }
      }
      return staleInvites;
    }, TX_CONFIG);

    const overdueActiveMatches = await db.pKMatch.findMany({
      where: {
        status: 'ACTIVE',
        endAt: { lte: now },
      },
    });

    return { expiredInvites, overdueActiveMatches };
  }

  /**
   * Admin: PK Settings.
   */
  async getPKSettings(db = prisma) {
    let setting = await db.pKSetting.findUnique({ where: { id: 'default' } });
    if (!setting) {
      setting = await db.pKSetting.create({
        data: {
          id: 'default',
          audioPkEnabled: true,
          videoPkEnabled: true,
          defaultDurationSeconds: 300,
          allowedDurationsJson: [180, 300, 600],
          invitationTimeoutSeconds: 30,
          preparationTimeoutSeconds: 15,
          reconnectGraceSeconds: 30,
          resultDisplaySeconds: 10,
          invitationRateLimit: 5,
        },
      });
    }
    return setting;
  }

  async updatePKSettings(data, adminUserId, db = prisma) {
    await this.getPKSettings(db);
    return db.pKSetting.update({
      where: { id: 'default' },
      data: {
        ...(data.audioPkEnabled !== undefined ? { audioPkEnabled: Boolean(data.audioPkEnabled) } : {}),
        ...(data.videoPkEnabled !== undefined ? { videoPkEnabled: Boolean(data.videoPkEnabled) } : {}),
        ...(data.defaultDurationSeconds ? { defaultDurationSeconds: Number(data.defaultDurationSeconds) } : {}),
        ...(data.allowedDurationsJson ? { allowedDurationsJson: data.allowedDurationsJson } : {}),
        ...(data.invitationTimeoutSeconds ? { invitationTimeoutSeconds: Number(data.invitationTimeoutSeconds) } : {}),
        ...(data.preparationTimeoutSeconds ? { preparationTimeoutSeconds: Number(data.preparationTimeoutSeconds) } : {}),
        ...(data.reconnectGraceSeconds ? { reconnectGraceSeconds: Number(data.reconnectGraceSeconds) } : {}),
        ...(data.resultDisplaySeconds ? { resultDisplaySeconds: Number(data.resultDisplaySeconds) } : {}),
        ...(data.invitationRateLimit ? { invitationRateLimit: Number(data.invitationRateLimit) } : {}),
        updatedByAdminId: adminUserId,
      },
    });
  }

  /**
   * Admin: PK Restrictions.
   */
  async listRestrictions({ page = 1, limit = 20, status }, db = prisma) {
    const skip = (Number(page) - 1) * Number(limit);
    const where = status ? { status } : {};
    const [total, restrictions] = await Promise.all([
      db.pKRestriction.count({ where }),
      db.pKRestriction.findMany({
        where,
        skip,
        take: Number(limit),
        orderBy: { createdAt: 'desc' },
      }),
    ]);
    return { total, restrictions, page: Number(page), limit: Number(limit) };
  }

  async createRestriction({ targetType, targetId, reason, restrictedByAdminId, durationHours }, db = prisma) {
    const expiresAt = durationHours ? new Date(Date.now() + Number(durationHours) * 3600 * 1000) : null;
    return db.pKRestriction.create({
      data: {
        targetType,
        targetId,
        reason,
        restrictedByAdminId,
        expiresAt,
        status: 'ACTIVE',
      },
    });
  }

  async revokeRestriction(id, db = prisma) {
    return db.pKRestriction.update({
      where: { id },
      data: { status: 'REVOKED' },
    });
  }

  /**
   * Admin: Audited Result Revision.
   */
  async reviseMatchResult({ matchId, adminUserId, reason, revisedScoreA, revisedScoreB, revisedWinnerHostId, revisedIsDraw }, db = prisma) {
    return db.$transaction(async (tx) => {
      const match = await tx.pKMatch.findUnique({ where: { id: matchId } });
      if (!match) throw new Error('Match not found');

      const originalResult = match.originalResultJson || {
        scoreA: match.scoreA.toString(),
        scoreB: match.scoreB.toString(),
        winnerHostId: match.winnerHostId,
        isDraw: match.isDraw,
      };

      const revisedResult = {
        scoreA: revisedScoreA.toString(),
        scoreB: revisedScoreB.toString(),
        winnerHostId: revisedWinnerHostId,
        isDraw: Boolean(revisedIsDraw),
        revisedAt: new Date().toISOString(),
      };

      const updated = await tx.pKMatch.update({
        where: { id: matchId },
        data: {
          originalResultJson: originalResult,
          revisedResultJson: revisedResult,
          revisionNumber: { increment: 1 },
          revisionReason: reason,
          revisedByAdminId: adminUserId,
          scoreA: BigInt(revisedScoreA),
          scoreB: BigInt(revisedScoreB),
          winnerHostId: revisedWinnerHostId,
          isDraw: Boolean(revisedIsDraw),
        },
      });

      await tx.pKLifecycleAudit.create({
        data: {
          matchId,
          action: 'RESULT_REVISED',
          actorUserId: adminUserId,
          metadataJson: { reason, originalResult, revisedResult },
        },
      });

      return updated;
    }, TX_CONFIG);
  }
}

export const pkRepository = new PKRepository();
export default pkRepository;
