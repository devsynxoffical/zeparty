import pkRepository from '../repositories/pk.repository.js';
import socketEmitter from '../socket/socket.emitter.js';

export class PKService {
  constructor(repo = pkRepository) {
    this.repo = repo;
    // Invite rate limit tracking: map of userId -> array of timestamps
    this.inviteRateLimits = new Map();
    // Sweeper interval handle
    this.sweeperInterval = null;
    this.startBackgroundSweeper();
  }

  /**
   * Periodic background sweeper.
   * Ensures that expired invitations, preparation timeouts, finished matches,
   * and disconnect grace periods are recovered and settled reliably across restarts.
   */
  startBackgroundSweeper() {
    if (this.sweeperInterval) return;
    this.sweeperInterval = setInterval(() => {
      this.runSweeperCycle().catch((err) => {
        console.error('[PKService Sweeper Error]:', err.message);
      });
    }, 3000); // Runs every 3 seconds
  }

  stopBackgroundSweeper() {
    if (this.sweeperInterval) {
      clearInterval(this.sweeperInterval);
      this.sweeperInterval = null;
    }
  }

  async runSweeperCycle() {
    const now = new Date();
    try {
      const { expiredInvites, overdueActiveMatches } = await this.repo.sweepStaleMatchesAndInvites(now);
      if (expiredInvites?.length) {
        for (const inv of expiredInvites) {
          const payload = {
            invitationId: inv.id,
            matchId: inv.match?.id,
            status: 'EXPIRED',
          };
          if (inv.match?.roomAId) socketEmitter.emitToRoom(inv.match.roomAId, 'pk:invitation_expired', payload);
          if (inv.match?.roomBId) socketEmitter.emitToRoom(inv.match.roomBId, 'pk:invitation_expired', payload);
          if (inv.targetHostUserId) socketEmitter.emitToUser(inv.targetHostUserId, 'pk:invitation_expired', payload);
        }
      }

      if (overdueActiveMatches?.length) {
        for (const m of overdueActiveMatches) {
          await this.finishMatch(m.id, 'TIME_EXPIRED');
        }
      }
    } catch (_) {}
  }

  /**
   * Rate limiting guard for sending invitations.
   */
  _checkInviteRateLimit(userId, maxPerMinute = 5) {
    const now = Date.now();
    const timestamps = this.inviteRateLimits.get(userId) || [];
    const recent = timestamps.filter((t) => now - t < 60000);
    if (recent.length >= maxPerMinute) {
      const err = new Error(`Rate limit exceeded. Max ${maxPerMinute} invitations per minute.`);
      err.code = 'PK_RATE_LIMITED';
      err.status = 429;
      throw err;
    }
    recent.push(now);
    this.inviteRateLimits.set(userId, recent);
  }

  /**
   * 1. DISCOVER OPPONENT
   */
  async discoverOpponent({ query, roomType, callerUserId }) {
    return this.repo.discoverOpponent({ query, roomType, excludeUserId: callerUserId });
  }

  /**
   * 2. SEND INVITATION
   */
  async sendInvitation({ fromRoomId, targetRoomId, targetHostUserId, durationSeconds = 300, callerUserId }) {
    const settings = await this.repo.getPKSettings();

    // Feature enablement check
    const isAudio = fromRoomId.includes('audio') || durationSeconds > 0;
    if (!settings.audioPkEnabled && !settings.videoPkEnabled) {
      const err = new Error('PK Matches are currently disabled by platform administration.');
      err.code = 'PK_FEATURE_DISABLED';
      err.status = 403;
      throw err;
    }

    this._checkInviteRateLimit(callerUserId, settings.invitationRateLimit);

    // Verify Inviter Room eligibility & caller operator rights
    const fromCheck = await this.repo.verifyRoomEligibility({ roomId: fromRoomId, userId: callerUserId });
    if (!fromCheck.eligible) {
      const err = new Error(fromCheck.error);
      err.code = fromCheck.code;
      err.status = fromCheck.code === 'PK_PERMISSION_DENIED' ? 403 : 400;
      throw err;
    }

    // Verify Target Room eligibility
    const targetCheck = await this.repo.verifyRoomEligibility({ roomId: targetRoomId, userId: targetHostUserId });
    if (!targetCheck.eligible) {
      const err = new Error(targetCheck.error);
      err.code = targetCheck.code;
      err.status = 400;
      throw err;
    }

    // Check Room Type parity
    if (fromCheck.room.roomType !== targetCheck.room.roomType) {
      const err = new Error('Cannot match different room types (Audio vs Video).');
      err.code = 'PK_WRONG_ROOM_TYPE';
      err.status = 400;
      throw err;
    }

    // Allowed duration check
    const allowed = Array.isArray(settings.allowedDurationsJson) ? settings.allowedDurationsJson : [180, 300, 600];
    const duration = allowed.includes(Number(durationSeconds)) ? Number(durationSeconds) : settings.defaultDurationSeconds;

    const configSnapshot = {
      durationSeconds: duration,
      reconnectGraceSeconds: settings.reconnectGraceSeconds,
      preparationTimeoutSeconds: settings.preparationTimeoutSeconds,
      multipliersEnabled: false,
      additionalRewardsEnabled: false,
    };

    const { match, invitation } = await this.repo.createInvitationAndMatch({
      roomA: fromCheck.room,
      roomB: targetCheck.room,
      inviterUserId: callerUserId,
      targetHostUserId,
      durationSeconds: duration,
      configSnapshot,
      invitationTimeoutSeconds: settings.invitationTimeoutSeconds,
    });

    const invitePayload = {
      invitationId: invitation.id,
      matchId: match.id,
      durationSeconds: duration,
      expiresAt: invitation.expiresAt.toISOString(),
      expiresInSeconds: settings.invitationTimeoutSeconds,
      fromRoom: {
        id: fromCheck.room.id,
        title: fromCheck.room.title,
        roomType: fromCheck.room.roomType,
      },
      fromHost: {
        id: fromCheck.room.creator.id,
        username: fromCheck.room.creator.username,
        displayName: fromCheck.room.creator.profile?.displayName || fromCheck.room.creator.username,
        avatarUrl: fromCheck.room.creator.avatarUrl || '',
      },
    };

    // Emit realtime invitation notification directly to target user and room
    socketEmitter.emitToUser(targetHostUserId, 'pk:invitation_received', invitePayload);
    socketEmitter.emitToRoom(targetRoomId, 'pk:invitation_received', invitePayload);

    return {
      invitationId: invitation.id,
      matchId: match.id,
      status: 'PENDING',
      durationSeconds: duration,
      expiresAt: invitation.expiresAt.toISOString(),
      expiresInSeconds: settings.invitationTimeoutSeconds,
    };
  }

  /**
   * 3. RESPOND TO INVITATION (ACCEPT / REJECT)
   */
  async respondInvitation({ invitationId, responderUserId, action, targetRoomId }) {
    const act = (action || 'ACCEPT').toUpperCase();
    if (act !== 'ACCEPT' && act !== 'REJECT') {
      const err = new Error("Action must be either 'ACCEPT' or 'REJECT'.");
      err.code = 'INVALID_ACTION';
      err.status = 400;
      throw err;
    }

    const result = await this.repo.respondToInvitation({
      invitationId,
      responderUserId,
      action: act,
      targetRoomId,
    });

    const matchSnapshot = await this.repo.getMatchSnapshot(result.match.id);

    if (result.accepted) {
      // Broadcast preparing event to both rooms
      socketEmitter.emitToRoom(result.match.roomAId, 'pk:preparing', matchSnapshot);
      socketEmitter.emitToRoom(result.match.roomBId, 'pk:preparing', matchSnapshot);
    } else {
      // Notify inviter room of rejection
      socketEmitter.emitToRoom(result.match.roomAId, 'pk:invitation_responded', {
        invitationId,
        matchId: result.match.id,
        action: 'REJECT',
      });
    }

    return {
      invitationId,
      matchId: result.match.id,
      action: act,
      status: result.match.status,
      match: matchSnapshot,
    };
  }

  /**
   * 4. CANCEL PENDING INVITATION
   */
  async cancelInvitation({ invitationId, callerUserId, reason }) {
    const result = await this.repo.cancelInvitation({ invitationId, userId: callerUserId, reason });

    const payload = {
      invitationId,
      matchId: result.match.id,
      status: 'CANCELLED',
      reason,
    };

    socketEmitter.emitToRoom(result.match.roomAId, 'pk:invitation_cancelled', payload);
    socketEmitter.emitToRoom(result.match.roomBId, 'pk:invitation_cancelled', payload);
    socketEmitter.emitToUser(result.invitation.targetHostUserId, 'pk:invitation_cancelled', payload);

    return payload;
  }

  /**
   * 5. SET OPERATOR READINESS & TRIGGER COUNTDOWN
   */
  async setOperatorReady({ matchId, userId, roomId, isReady, mediaPrepared }) {
    const updated = await this.repo.setOperatorReady({
      matchId,
      userId,
      roomId,
      isReady,
      mediaPrepared,
    });

    const snapshot = await this.repo.getMatchSnapshot(matchId);

    // Broadcast readiness change
    socketEmitter.emitToRoom(updated.roomAId, 'pk:ready_changed', snapshot);
    socketEmitter.emitToRoom(updated.roomBId, 'pk:ready_changed', snapshot);

    // If both operators confirmed readiness, countdown started
    if (updated.status === 'COUNTDOWN') {
      const countdownPayload = {
        matchId: updated.id,
        stateVersion: updated.stateVersion,
        countdownSeconds: 3,
        countdownStartAt: updated.countdownStartAt?.toISOString(),
      };

      socketEmitter.emitToRoom(updated.roomAId, 'pk:countdown_started', countdownPayload);
      socketEmitter.emitToRoom(updated.roomBId, 'pk:countdown_started', countdownPayload);

      // Trigger automatic start after 3 seconds
      setTimeout(() => {
        this.startMatch(matchId).catch((err) => {
          console.error(`[PKService] Auto-start match ${matchId} error:`, err.message);
        });
      }, 3000);
    }

    return snapshot;
  }

  /**
   * 6. START MATCH AUTHORITATIVELY
   */
  async startMatch(matchId) {
    const started = await this.repo.startMatch({ matchId });
    const snapshot = await this.repo.getMatchSnapshot(matchId);

    socketEmitter.emitToRoom(started.roomAId, 'pk:match_started', snapshot);
    socketEmitter.emitToRoom(started.roomBId, 'pk:match_started', snapshot);

    // Schedule authoritative end timer
    const remainingMs = Math.max(0, new Date(started.endAt).getTime() - Date.now());
    setTimeout(() => {
      this.finishMatch(matchId, 'TIME_EXPIRED').catch((err) => {
        console.error(`[PKService] Auto-end match ${matchId} error:`, err.message);
      });
    }, remainingMs);

    return snapshot;
  }

  /**
   * 7. GET AUTHORITATIVE MATCH SNAPSHOT
   */
  async getMatchSnapshot(matchId) {
    return this.repo.getMatchSnapshot(matchId);
  }

  /**
   * 8. GET ACTIVE MATCH FOR ROOM
   */
  async getActiveMatchForRoom(roomId) {
    const active = await this.repo.findActiveOrPendingMatchForRoom(roomId);
    if (!active) return null;
    return this.repo.getMatchSnapshot(active.id);
  }

  /**
   * 9. TOP 3 SUPPORTERS PER SIDE
   */
  async getTopSupporters(matchId) {
    return this.repo.getTopSupporters(matchId);
  }

  /**
   * 10. RECORD GIFT SCORING CONTRIBUTION
   * Called within the gift transaction lifecycle.
   */
  async recordGiftContribution({ giftTransactionId, senderUserId, recipientUserId, roomId, coins, commitTimestamp }) {
    const result = await this.repo.recordGiftContribution({
      giftTransactionId,
      senderUserId,
      recipientUserId,
      roomId,
      coins,
      commitTimestamp,
    });

    if (!result || result.duplicate) return null;

    const snapshot = await this.repo.getMatchSnapshot(result.match.id);

    const scorePayload = {
      matchId: result.match.id,
      stateVersion: result.match.stateVersion,
      scoreA: snapshot.scoreA,
      scoreB: snapshot.scoreB,
      recentGift: {
        scoredSide: result.side,
        coins: Number(coins),
        senderUserId,
        recipientUserId,
      },
      topSupportersA: snapshot.topSupportersA,
      topSupportersB: snapshot.topSupportersB,
    };

    socketEmitter.emitToRoom(result.match.roomAId, 'pk:score_updated', scorePayload);
    socketEmitter.emitToRoom(result.match.roomBId, 'pk:score_updated', scorePayload);

    return result;
  }

  /**
   * 11. FINISH MATCH (END BOUNDARY)
   */
  async finishMatch(matchId, endReason = 'NORMAL_COMPLETION') {
    const finished = await this.repo.finishMatch({ matchId, endReason });
    const snapshot = await this.repo.getMatchSnapshot(matchId);

    const endPayload = {
      matchId,
      stateVersion: finished.stateVersion,
      status: 'FINISHED',
      scoreA: snapshot.scoreA,
      scoreB: snapshot.scoreB,
      winnerHostId: snapshot.winnerHostId,
      isDraw: snapshot.isDraw,
      endReason: snapshot.endReason,
      displayDurationSeconds: 10,
      topSupportersA: snapshot.topSupportersA,
      topSupportersB: snapshot.topSupportersB,
    };

    socketEmitter.emitToRoom(finished.roomAId, 'pk:match_finished', endPayload);
    socketEmitter.emitToRoom(finished.roomBId, 'pk:match_finished', endPayload);

    return snapshot;
  }

  /**
   * 12. FORFEIT MATCH (Host intentionally exits or grace timeout expires)
   */
  async forfeitMatch(matchId, forfeitHostUserId, endReason = 'HOST_FORFEIT') {
    const forfeited = await this.repo.forfeitMatch({ matchId, forfeitHostUserId, endReason });
    if (!forfeited) return null;

    const snapshot = await this.repo.getMatchSnapshot(matchId);

    const payload = {
      matchId,
      status: 'FORFEIT',
      winnerHostId: snapshot.winnerHostId,
      forfeitHostUserId,
      endReason,
    };

    socketEmitter.emitToRoom(forfeited.roomAId, 'pk:match_forfeited', payload);
    socketEmitter.emitToRoom(forfeited.roomBId, 'pk:match_forfeited', payload);

    return snapshot;
  }

  /**
   * 13. ABORT MATCH (Mutual disconnect, admin force stop)
   */
  async abortMatch(matchId, actorUserId, endReason = 'ABORTED') {
    const aborted = await this.repo.abortMatch({ matchId, actorUserId, endReason });
    if (!aborted) return null;

    const payload = {
      matchId,
      status: 'ABORTED',
      endReason,
      winnerHostId: null,
      isDraw: false,
    };

    socketEmitter.emitToRoom(aborted.roomAId, 'pk:match_aborted', payload);
    socketEmitter.emitToRoom(aborted.roomBId, 'pk:match_aborted', payload);

    return payload;
  }

  /**
   * 14. HOST DISCONNECT & RECONNECT GRACE TRACKING
   */
  async handleHostDisconnect({ roomId, userId }) {
    const active = await this.repo.findActiveOrPendingMatchForRoom(roomId);
    if (!active || active.status !== 'ACTIVE') return;

    const isHostA = active.hostAUserId === userId;
    const isHostB = active.hostBUserId === userId;
    if (!isHostA && !isHostB) return;

    await this.repo.updateHostConnection({
      matchId: active.id,
      hostUserId: userId,
      status: 'DISCONNECTED',
      disconnectedAt: new Date(),
    });

    const side = isHostA ? 'A' : 'B';
    const payload = {
      matchId: active.id,
      hostId: userId,
      side,
      connectionStatus: 'DISCONNECTED',
      graceRemainingSeconds: 30,
    };

    socketEmitter.emitToRoom(active.roomAId, 'pk:host_connection_changed', payload);
    socketEmitter.emitToRoom(active.roomBId, 'pk:host_connection_changed', payload);

    // Schedule 30s disconnect grace period check
    setTimeout(async () => {
      const current = await this.repo.getMatchSnapshot(active.id);
      if (!current || current.status !== 'ACTIVE') return;

      const hostDisconnected = isHostA ? current.sideA.connectionStatus === 'DISCONNECTED' : current.sideB.connectionStatus === 'DISCONNECTED';
      const opponentDisconnected = isHostA ? current.sideB.connectionStatus === 'DISCONNECTED' : current.sideA.connectionStatus === 'DISCONNECTED';

      if (hostDisconnected && opponentDisconnected) {
        // Both hosts offline after grace -> Abort without winner
        await this.abortMatch(active.id, 'SYSTEM', 'MUTUAL_DISCONNECT');
      } else if (hostDisconnected) {
        // One host failed to return -> Opponent wins by forfeit
        await this.forfeitMatch(active.id, userId, 'DISCONNECT_GRACE_EXPIRED');
      }
    }, 30000);
  }

  async handleHostReconnect({ roomId, userId }) {
    const active = await this.repo.findActiveOrPendingMatchForRoom(roomId);
    if (!active || active.status !== 'ACTIVE') return;

    await this.repo.updateHostConnection({
      matchId: active.id,
      hostUserId: userId,
      status: 'CONNECTED',
      disconnectedAt: null,
    });

    const isHostA = active.hostAUserId === userId;
    const payload = {
      matchId: active.id,
      hostId: userId,
      side: isHostA ? 'A' : 'B',
      connectionStatus: 'CONNECTED',
    };

    socketEmitter.emitToRoom(active.roomAId, 'pk:host_connection_changed', payload);
    socketEmitter.emitToRoom(active.roomBId, 'pk:host_connection_changed', payload);
  }

  /**
   * 15. REQUEST REMATCH
   * Creates a fresh invitation with fresh state; never mutates finished match.
   */
  async requestRematch({ matchId, callerUserId }) {
    const previous = await this.repo.getMatchSnapshot(matchId);
    if (!previous) {
      const err = new Error('Previous PK match not found.');
      err.code = 'PK_MATCH_NOT_FOUND';
      err.status = 404;
      throw err;
    }

    const isSideA = previous.sideA.hostId === callerUserId;
    const fromRoomId = isSideA ? previous.sideA.roomId : previous.sideB.roomId;
    const targetRoomId = isSideA ? previous.sideB.roomId : previous.sideA.roomId;
    const targetHostUserId = isSideA ? previous.sideB.hostId : previous.sideA.hostId;

    return this.sendInvitation({
      fromRoomId,
      targetRoomId,
      targetHostUserId,
      durationSeconds: previous.durationSeconds,
      callerUserId,
    });
  }

  /**
   * 16. ADMIN: FORCE STOP
   */
  async adminForceStop({ matchId, adminUserId, reason }) {
    return this.abortMatch(matchId, adminUserId, `ADMIN_FORCE_STOP: ${reason}`);
  }

  /**
   * 17. ADMIN: REVISE RESULT
   */
  async adminReviseResult(data) {
    return this.repo.reviseMatchResult(data);
  }

  /**
   * 18. ADMIN: SETTINGS & RESTRICTIONS
   */
  async getSettings() {
    return this.repo.getPKSettings();
  }

  async updateSettings(data, adminUserId) {
    return this.repo.updatePKSettings(data, adminUserId);
  }

  async listRestrictions(params) {
    return this.repo.listRestrictions(params);
  }

  async createRestriction(data) {
    return this.repo.createRestriction(data);
  }

  async revokeRestriction(id) {
    return this.repo.revokeRestriction(id);
  }

  async listAdminMatches(params) {
    return this.repo.listAdminMatches(params);
  }

  async getHistory(params) {
    return this.repo.listPKHistory(params);
  }
}

export const pkService = new PKService();
export default pkService;
