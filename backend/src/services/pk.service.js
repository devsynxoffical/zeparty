import socketEmitter from '../socket/socket.emitter.js';

export class PKService {
  constructor(repo = null) {
    this.customRepo = repo;
    // Active in-memory PK battle sessions: map of pkId -> PKSession
    this.activeSessions = new Map();
    // Pending invitations: map of invitationId -> Invitation
    this.pendingInvitations = new Map();
    // Auto-end timers: map of pkId -> NodeJS.Timeout
    this.endTimers = new Map();
  }

  async getRepo() {
    if (this.customRepo) return this.customRepo;
    const module = await import('../repositories/pk.repository.js');
    return module.default;
  }

  /**
   * Helper to format a participant object safely.
   */
  _formatParticipant({
    userId,
    name,
    username,
    avatarUrl,
    roomId = null,
    slot = 1,
    isHost = false,
    isInitiator = false,
    score = 0,
    status = 'READY',
  }) {
    return {
      userId: userId.toString(),
      name: (name || username || 'Participant').toString(),
      username: (username || 'user').toString(),
      avatarUrl: (avatarUrl || '').toString(),
      roomId: roomId ? roomId.toString() : null,
      slot: Number(slot),
      isHost: Boolean(isHost),
      isInitiator: Boolean(isInitiator),
      score: Number(score) || 0,
      status: status.toString(),
    };
  }

  /**
   * 1. CREATE PK SESSION (Host-Controlled Only)
   * Only the live host can create a PK battle for their active room.
   */
  async createPKSession({
    hostUserId,
    roomId,
    durationSeconds = 300,
    hostInfo = {},
  }) {
    if (!hostUserId || !roomId) {
      const error = new Error('hostUserId and roomId are required to initiate PK.');
      error.status = 400;
      error.code = 'INVALID_PK_REQUEST';
      throw error;
    }

    const repo = await this.getRepo();

    // Verify host authorization on server
    const isLiveHost = await repo.verifyLiveHost(hostUserId, roomId);
    if (!isLiveHost) {
      const error = new Error('Forbidden: Only the active live host of this room can initiate a PK Battle.');
      error.status = 403;
      error.code = 'NOT_LIVE_HOST';
      throw error;
    }

    // Check if room is already in an active PK battle
    const existingPK = await repo.findActivePKForRoom(roomId);
    if (existingPK) {
      const error = new Error('Room is already participating in an active PK battle.');
      error.status = 409;
      error.code = 'PK_ALREADY_ACTIVE';
      throw error;
    }

    const inviteCode = `pk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
    const initiatorParticipant = this._formatParticipant({
      userId: hostUserId,
      name: hostInfo.name || hostInfo.displayName || 'Host Blue',
      username: hostInfo.username || 'host_blue',
      avatarUrl: hostInfo.avatarUrl || '',
      roomId,
      slot: 1,
      isHost: true,
      isInitiator: true,
      score: 0,
      status: 'READY',
    });

    const pkEvent = await repo.createPKEvent({
      initiatorUserId: hostUserId,
      roomAId: roomId,
      hostAUserId: hostUserId,
      durationSeconds: Number(durationSeconds) || 300,
      participants: [initiatorParticipant],
      inviteCode,
      status: 'CREATED',
    });

    const session = {
      pkId: pkEvent.id,
      initiatorUserId: hostUserId,
      primaryRoomId: roomId,
      durationSeconds: Number(durationSeconds) || 300,
      participants: [initiatorParticipant],
      status: 'CREATED',
      startedAt: null, // Timer is explicitly NOT running
      endedAt: null,
      inviteCode,
      createdAt: Date.now(),
    };

    this.activeSessions.set(pkEvent.id, session);

    // Realtime broadcast PK created event to initiator room
    socketEmitter.emitToRoom(roomId, 'pk:created', {
      pkId: pkEvent.id,
      initiatorUserId: hostUserId,
      inviteCode,
      participants: session.participants,
      status: 'CREATED',
      durationSeconds: session.durationSeconds,
      startedAt: null,
    });

    return session;
  }

  /**
   * 2. SEND PK INVITATION (Host-Controlled to Host or User)
   */
  async sendPKInvite({
    pkId,
    fromHostUserId,
    fromRoomId,
    targetRoomId = null,
    targetUserId = null,
    durationSeconds = 300,
    fromHostInfo = {},
  }) {
    let session = pkId ? this.activeSessions.get(pkId) : null;

    if (!session && fromRoomId && fromHostUserId) {
      // Auto-create PK session if host invites without creating session first
      session = await this.createPKSession({
        hostUserId: fromHostUserId,
        roomId: fromRoomId,
        durationSeconds,
        hostInfo: fromHostInfo,
      });
    }

    if (!session) {
      const error = new Error('PK session not found.');
      error.status = 404;
      error.code = 'PK_NOT_FOUND';
      throw error;
    }

    // Host authorization check
    if (session.initiatorUserId !== fromHostUserId) {
      const error = new Error('Only the PK initiator can send PK invitations.');
      error.status = 403;
      error.code = 'UNAUTHORIZED_PK_INVITE';
      throw error;
    }

    // Maximum 4 participants limit check
    if (session.participants.length >= 4) {
      const error = new Error('PK Battle participant limit reached (maximum 4 participants).');
      error.status = 400;
      error.code = 'PK_FULL';
      throw error;
    }

    const invitationId = `pki_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const invite = {
      id: invitationId,
      pkId: session.pkId,
      fromRoomId: session.primaryRoomId,
      fromHostUserId,
      fromHostInfo,
      targetRoomId,
      targetUserId,
      durationSeconds: session.durationSeconds,
      createdAt: Date.now(),
      status: 'PENDING',
    };

    this.pendingInvitations.set(invitationId, invite);

    const payload = {
      invitationId,
      pkId: session.pkId,
      inviteCode: session.inviteCode,
      fromRoomId: session.primaryRoomId,
      fromHost: fromHostInfo,
      targetRoomId,
      targetUserId,
      durationSeconds: session.durationSeconds,
      currentParticipantsCount: session.participants.length,
      maxParticipants: 4,
    };

    // Emit to target room or target user
    if (targetRoomId) {
      socketEmitter.emitToRoom(targetRoomId, 'pk:invitation_received', payload);
    }
    if (targetUserId) {
      socketEmitter.emitToUser(targetUserId, 'pk:invitation_received', payload);
    }

    return {
      success: true,
      invitationId,
      pkId: session.pkId,
      inviteCode: session.inviteCode,
      message: 'PK battle invitation sent successfully.',
    };
  }

  /**
   * 3. GET / VALIDATE INVITATION
   */
  async getInvitationDetails(invitationId) {
    const invite = this.pendingInvitations.get(invitationId);
    if (!invite) {
      const error = new Error('PK invitation expired or not found.');
      error.status = 404;
      error.code = 'INVITE_NOT_FOUND';
      throw error;
    }

    const session = this.activeSessions.get(invite.pkId);
    if (!session || session.status === 'ENDED' || session.status === 'CANCELLED') {
      const error = new Error('This PK Battle has already concluded or was cancelled.');
      error.status = 410;
      error.code = 'PK_ENDED';
      throw error;
    }

    if (session.participants.length >= 4) {
      const error = new Error('PK Battle is full (maximum 4 participants).');
      error.status = 400;
      error.code = 'PK_FULL';
      throw error;
    }

    return {
      invitation: invite,
      session: {
        pkId: session.pkId,
        initiatorUserId: session.initiatorUserId,
        status: session.status,
        participants: session.participants,
        maxParticipants: 4,
        durationSeconds: session.durationSeconds,
      },
    };
  }

  /**
   * 4. RESPOND TO PK INVITATION (ACCEPT / DECLINE)
   */
  async respondPKInvite({
    invitationId,
    responderUserId,
    responderRoomId = null,
    responderInfo = {},
    action = 'ACCEPT',
  }) {
    const invite = this.pendingInvitations.get(invitationId);
    if (!invite) {
      const error = new Error('PK invitation expired or not found.');
      error.status = 404;
      error.code = 'INVITE_NOT_FOUND';
      throw error;
    }

    const session = this.activeSessions.get(invite.pkId);
    if (!session || session.status === 'ENDED' || session.status === 'CANCELLED') {
      this.pendingInvitations.delete(invitationId);
      const error = new Error('PK battle is no longer active.');
      error.status = 410;
      error.code = 'PK_INACTIVE';
      throw error;
    }

    if (action === 'ACCEPT') {
      // Enforce participant limit (MAX 4)
      if (session.participants.length >= 4) {
        this.pendingInvitations.delete(invitationId);
        const error = new Error('PK Battle has already reached the maximum of 4 participants.');
        error.status = 400;
        error.code = 'PK_FULL';
        throw error;
      }

      // Check if user already joined
      const alreadyJoined = session.participants.some(
        (p) => p.userId === responderUserId.toString()
      );

      if (!alreadyJoined) {
        const nextSlot = session.participants.length + 1;
        const newParticipant = this._formatParticipant({
          userId: responderUserId,
          name: responderInfo.name || responderInfo.displayName || `Participant ${nextSlot}`,
          username: responderInfo.username || `user_${nextSlot}`,
          avatarUrl: responderInfo.avatarUrl || '',
          roomId: responderRoomId || invite.targetRoomId,
          slot: nextSlot,
          isHost: Boolean(responderRoomId),
          isInitiator: false,
          score: 0,
          status: 'READY',
        });

        session.participants.push(newParticipant);
      }

      // Once 2 or more participants are on screen, PK enters READY state (Timer still NOT running)
      if (session.participants.length >= 2 && session.status !== 'STARTED') {
        session.status = 'READY';
      }

      this.pendingInvitations.delete(invitationId);

      const repo = await this.getRepo();
      await repo.updatePKStatus(session.pkId, {
        status: session.status,
        participantsJson: session.participants,
        roomBId: responderRoomId || invite.targetRoomId || undefined,
        hostBUserId: responderUserId || undefined,
      });

      const participantPayload = {
        pkId: session.pkId,
        status: session.status,
        participants: session.participants,
        participantCount: session.participants.length,
        durationSeconds: session.durationSeconds,
        startedAt: null, // Timer is explicitly NOT running yet
      };

      // Notify all participant rooms and users
      socketEmitter.emitToRoom(session.primaryRoomId, 'pk:participant_joined', participantPayload);
      if (responderRoomId) {
        socketEmitter.emitToRoom(responderRoomId, 'pk:participant_joined', participantPayload);
      }
      for (const p of session.participants) {
        socketEmitter.emitToUser(p.userId, 'pk:participant_joined', participantPayload);
      }

      if (session.status === 'READY') {
        socketEmitter.emitToRoom(session.primaryRoomId, 'pk:ready', participantPayload);
        if (responderRoomId) {
          socketEmitter.emitToRoom(responderRoomId, 'pk:ready', participantPayload);
        }
      }

      return {
        success: true,
        accepted: true,
        session,
      };
    } else {
      this.pendingInvitations.delete(invitationId);

      socketEmitter.emitToRoom(session.primaryRoomId, 'pk:invitation_declined', {
        invitationId,
        declinedByUserId: responderUserId,
      });

      return {
        success: true,
        accepted: false,
        message: 'PK invitation declined.',
      };
    }
  }

  /**
   * 5. JOIN VIA INVITE CODE / SHARE LINK
   */
  async joinByInviteCode({
    inviteCode,
    userId,
    userInfo = {},
    roomId = null,
  }) {
    if (!inviteCode || !userId) {
      const error = new Error('inviteCode and userId are required.');
      error.status = 400;
      throw error;
    }

    let session = Array.from(this.activeSessions.values()).find(
      (s) => s.inviteCode === inviteCode
    );

    if (!session) {
      const repo = await this.getRepo();
      const pkEvent = await repo.findPKEventByInviteCode(inviteCode);
      if (!pkEvent) {
        const error = new Error('Invalid or expired PK Battle invitation code.');
        error.status = 404;
        error.code = 'INVALID_INVITE_CODE';
        throw error;
      }
      session = this._rehydrateSessionFromDB(pkEvent);
      this.activeSessions.set(session.pkId, session);
    }

    if (session.status === 'ENDED' || session.status === 'CANCELLED') {
      const error = new Error('This PK Battle has already ended.');
      error.status = 410;
      error.code = 'PK_ENDED';
      throw error;
    }

    if (session.participants.length >= 4) {
      const error = new Error('PK Battle is full (maximum 4 participants reached).');
      error.status = 400;
      error.code = 'PK_FULL';
      throw error;
    }

    const alreadyJoined = session.participants.some(
      (p) => p.userId === userId.toString()
    );

    if (!alreadyJoined) {
      const nextSlot = session.participants.length + 1;
      const newParticipant = this._formatParticipant({
        userId,
        name: userInfo.name || userInfo.displayName || `Participant ${nextSlot}`,
        username: userInfo.username || `user_${nextSlot}`,
        avatarUrl: userInfo.avatarUrl || '',
        roomId,
        slot: nextSlot,
        isHost: Boolean(roomId),
        isInitiator: false,
        score: 0,
        status: 'READY',
      });

      session.participants.push(newParticipant);
    }

    if (session.participants.length >= 2 && session.status !== 'STARTED') {
      session.status = 'READY';
    }

    const repo = await this.getRepo();
    await repo.updatePKStatus(session.pkId, {
      status: session.status,
      participantsJson: session.participants,
    });

    const payload = {
      pkId: session.pkId,
      status: session.status,
      participants: session.participants,
      participantCount: session.participants.length,
      durationSeconds: session.durationSeconds,
      startedAt: session.startedAt,
    };

    socketEmitter.emitToRoom(session.primaryRoomId, 'pk:participant_joined', payload);
    for (const p of session.participants) {
      socketEmitter.emitToUser(p.userId, 'pk:participant_joined', payload);
    }

    return session;
  }

  /**
   * 6. START PK BATTLE (Authoritative Start Condition & Timer Start)
   * The PK timer starts ONLY when host/server explicitly transitions to STARTED.
   */
  async startPKBattle({ pkId, hostUserId }) {
    let session = this.activeSessions.get(pkId);
    const repo = await this.getRepo();

    if (!session) {
      const pkEvent = await repo.findPKEventById(pkId);
      if (!pkEvent) {
        const error = new Error('PK Battle session not found.');
        error.status = 404;
        error.code = 'PK_NOT_FOUND';
        throw error;
      }
      session = this._rehydrateSessionFromDB(pkEvent);
      this.activeSessions.set(pkId, session);
    }

    // Host authorization check
    if (session.initiatorUserId !== hostUserId) {
      const error = new Error('Only the PK host initiator can start the battle.');
      error.status = 403;
      error.code = 'UNAUTHORIZED_PK_START';
      throw error;
    }

    // Minimum 2 participants required to start
    if (session.participants.length < 2) {
      const error = new Error('Cannot start PK Battle with fewer than 2 participants.');
      error.status = 400;
      error.code = 'NOT_ENOUGH_PARTICIPANTS';
      throw error;
    }

    if (session.status === 'STARTED') {
      return session;
    }

    const now = new Date();
    session.status = 'STARTED';
    session.startedAt = now.toISOString();

    await repo.updatePKStatus(pkId, {
      status: 'STARTED',
      startedAt: now,
      participantsJson: session.participants,
    });

    const startPayload = {
      pkId: session.pkId,
      status: 'STARTED',
      startedAt: session.startedAt,
      durationSeconds: session.durationSeconds,
      participants: session.participants,
      participantCount: session.participants.length,
      hostA: session.participants[0] ? {
        id: session.participants[0].userId,
        name: session.participants[0].name,
        username: session.participants[0].username,
        avatarUrl: session.participants[0].avatarUrl,
      } : {},
      hostB: session.participants[1] ? {
        id: session.participants[1].userId,
        name: session.participants[1].name,
        username: session.participants[1].username,
        avatarUrl: session.participants[1].avatarUrl,
      } : {},
      hostAScore: (session.participants[0]?.score || 0).toString(),
      hostBScore: (session.participants[1]?.score || 0).toString(),
    };

    // Broadcast authoritative PK Started event to all participant rooms
    for (const p of session.participants) {
      if (p.roomId) {
        socketEmitter.emitToRoom(p.roomId, 'pk:started', startPayload);
      }
      socketEmitter.emitToUser(p.userId, 'pk:started', startPayload);
    }
    socketEmitter.emitToRoom(session.primaryRoomId, 'pk:started', startPayload);

    // Schedule authoritative server-side auto-end timer
    if (this.endTimers.has(pkId)) {
      clearTimeout(this.endTimers.get(pkId));
    }
    const timer = setTimeout(() => {
      this.endPKBattle(pkId).catch((err) => {
        console.error(`[PKService] Auto-end PK error for ${pkId}:`, err);
      });
    }, session.durationSeconds * 1000);
    this.endTimers.set(pkId, timer);

    return session;
  }

  /**
   * 7. ACCUMULATE SCORE (Live Gifting to any Participant Slot)
   */
  async addPKScore({ roomId, targetUserId, giftCoinValue }) {
    let session = null;
    for (const s of this.activeSessions.values()) {
      if (
        (s.status === 'STARTED' || s.status === 'ACTIVE' || s.status === 'READY') &&
        (s.primaryRoomId === roomId || s.participants.some((p) => p.roomId === roomId || p.userId === targetUserId))
      ) {
        session = s;
        break;
      }
    }

    if (!session) {
      return null;
    }

    const val = Number(giftCoinValue) || 0;
    let targetIndex = -1;

    if (targetUserId) {
      targetIndex = session.participants.findIndex((p) => p.userId === targetUserId.toString());
    } else if (roomId) {
      targetIndex = session.participants.findIndex((p) => p.roomId === roomId.toString());
    }

    if (targetIndex === -1 && session.participants.length > 0) {
      targetIndex = 0; // Default to host/slot 1
    }

    session.participants[targetIndex].score += val;

    const repo = await this.getRepo();
    if (targetIndex === 0) {
      await repo.incrementHostScore(session.pkId, 'hostA', val);
    } else if (targetIndex === 1) {
      await repo.incrementHostScore(session.pkId, 'hostB', val);
    }

    const scorePayload = {
      pkId: session.pkId,
      status: session.status,
      participants: session.participants,
      hostAScore: (session.participants[0]?.score || 0).toString(),
      hostBScore: (session.participants[1]?.score || 0).toString(),
      recentGiftCoins: val,
      scoredUserId: session.participants[targetIndex]?.userId,
      scoredSlot: session.participants[targetIndex]?.slot,
    };

    for (const p of session.participants) {
      if (p.roomId) {
        socketEmitter.emitToRoom(p.roomId, 'pk:score_updated', scorePayload);
      }
    }
    socketEmitter.emitToRoom(session.primaryRoomId, 'pk:score_updated', scorePayload);

    return session;
  }

  /**
   * 8. END PK BATTLE (Authoritative Result Calculation)
   */
  async endPKBattle(pkId) {
    let session = this.activeSessions.get(pkId);
    const repo = await this.getRepo();

    if (!session) {
      const pkEvent = await repo.findPKEventById(pkId);
      if (!pkEvent) {
        const error = new Error('PK Battle session not found.');
        error.status = 404;
        throw error;
      }
      session = this._rehydrateSessionFromDB(pkEvent);
    }

    if (session.status === 'ENDED') {
      return session;
    }

    if (this.endTimers.has(pkId)) {
      clearTimeout(this.endTimers.get(pkId));
      this.endTimers.delete(pkId);
    }

    session.status = 'ENDED';
    session.endedAt = new Date().toISOString();

    // Determine winner among all participants by highest score
    let highestScore = -1;
    let winnerParticipant = null;
    let isTie = false;

    for (const p of session.participants) {
      if (p.score > highestScore) {
        highestScore = p.score;
        winnerParticipant = p;
        isTie = false;
      } else if (p.score === highestScore && highestScore > 0) {
        isTie = true;
      }
    }

    const winnerUserId = (!isTie && winnerParticipant && highestScore > 0) ? winnerParticipant.userId : null;

    await repo.updatePKStatus(pkId, {
      status: 'ENDED',
      winnerHostUserId: winnerUserId,
      endedAt: new Date(),
      participantsJson: session.participants,
    });

    const endPayload = {
      pkId: session.pkId,
      status: 'ENDED',
      winnerUserId,
      winnerName: winnerParticipant ? winnerParticipant.name : null,
      isTie,
      participants: session.participants,
      hostAScore: (session.participants[0]?.score || 0).toString(),
      hostBScore: (session.participants[1]?.score || 0).toString(),
    };

    for (const p of session.participants) {
      if (p.roomId) {
        socketEmitter.emitToRoom(p.roomId, 'pk:ended', endPayload);
      }
      socketEmitter.emitToUser(p.userId, 'pk:ended', endPayload);
    }
    socketEmitter.emitToRoom(session.primaryRoomId, 'pk:ended', endPayload);

    return session;
  }

  /**
   * 9. GET AUTHORITATIVE PK SESSION (For Reconnect or Room Load)
   */
  async getPKSession(pkId) {
    let session = this.activeSessions.get(pkId);
    if (!session) {
      const repo = await this.getRepo();
      const pkEvent = await repo.findPKEventById(pkId);
      if (!pkEvent) return null;
      session = this._rehydrateSessionFromDB(pkEvent);
      this.activeSessions.set(pkId, session);
    }

    // Calculate elapsed time from server authoritative startedAt
    let remainingSeconds = session.durationSeconds;
    if (session.status === 'STARTED' && session.startedAt) {
      const elapsed = Math.floor((Date.now() - new Date(session.startedAt).getTime()) / 1000);
      remainingSeconds = Math.max(0, session.durationSeconds - elapsed);
    } else if (session.status === 'ENDED') {
      remainingSeconds = 0;
    }

    return {
      ...session,
      remainingSeconds,
    };
  }

  /**
   * 10. GET ACTIVE PK FOR ROOM
   */
  async getRoomPKStatus(roomId) {
    for (const session of this.activeSessions.values()) {
      if (
        (session.status === 'CREATED' || session.status === 'READY' || session.status === 'STARTED') &&
        (session.primaryRoomId === roomId || session.participants.some((p) => p.roomId === roomId))
      ) {
        return this.getPKSession(session.pkId);
      }
    }

    const repo = await this.getRepo();
    const active = await repo.findActivePKForRoom(roomId);
    if (!active) return null;

    const session = this._rehydrateSessionFromDB(active);
    this.activeSessions.set(session.pkId, session);
    return this.getPKSession(session.pkId);
  }

  /**
   * 11. DISCOVER AVAILABLE LIVE HOSTS (For Path A Host vs Host)
   */
  async getAvailablePKHosts({ excludeRoomId = null, excludeUserId = null } = {}) {
    const repo = await this.getRepo();
    const activeRooms = await repo.findAvailableLiveRooms({ excludeRoomId, excludeUserId });

    const available = [];
    for (const room of activeRooms) {
      const activePK = await repo.findActivePKForRoom(room.id);
      if (!activePK) {
        available.push({
          roomId: room.id,
          roomTitle: room.title,
          coverImageUrl: room.coverImageUrl || '',
          category: room.category,
          viewerCount: room.currentViewersCount,
          host: {
            id: room.creator.id,
            username: room.creator.username,
            name: room.creator.profile?.displayName || room.creator.username,
            avatarUrl: room.creator.avatarUrl || '',
            level: room.creator.profile?.level || 1,
            vipLevel: room.creator.profile?.vipLevel || 0,
          },
        });
      }
    }

    return available;
  }

  /**
   * Rehydrate active session in memory from DB entity.
   */
  _rehydrateSessionFromDB(pkEvent) {
    const participants = Array.isArray(pkEvent.participantsJson) && pkEvent.participantsJson.length > 0
      ? pkEvent.participantsJson
      : [
          this._formatParticipant({
            userId: pkEvent.hostAUserId,
            name: pkEvent.roomA?.creator?.profile?.displayName || pkEvent.roomA?.creator?.username || 'Host Blue',
            username: pkEvent.roomA?.creator?.username || 'host_blue',
            avatarUrl: pkEvent.roomA?.creator?.avatarUrl || '',
            roomId: pkEvent.roomAId,
            slot: 1,
            isHost: true,
            isInitiator: true,
            score: Number(pkEvent.hostAScore) || 0,
          }),
          ...(pkEvent.hostBUserId ? [
            this._formatParticipant({
              userId: pkEvent.hostBUserId,
              name: pkEvent.roomB?.creator?.profile?.displayName || pkEvent.roomB?.creator?.username || 'Host Red',
              username: pkEvent.roomB?.creator?.username || 'host_red',
              avatarUrl: pkEvent.roomB?.creator?.avatarUrl || '',
              roomId: pkEvent.roomBId,
              slot: 2,
              isHost: true,
              isInitiator: false,
              score: Number(pkEvent.hostBScore) || 0,
            }),
          ] : []),
        ];

    return {
      pkId: pkEvent.id,
      initiatorUserId: pkEvent.initiatorUserId || pkEvent.hostAUserId,
      primaryRoomId: pkEvent.roomAId,
      durationSeconds: pkEvent.durationSeconds || 300,
      participants,
      status: pkEvent.status,
      startedAt: pkEvent.startedAt ? pkEvent.startedAt.toISOString() : null,
      endedAt: pkEvent.endedAt ? pkEvent.endedAt.toISOString() : null,
      inviteCode: pkEvent.inviteCode,
      createdAt: pkEvent.createdAt ? new Date(pkEvent.createdAt).getTime() : Date.now(),
    };
  }

  /**
   * List PK events for Admin oversight.
   */
  async listAdminPKEvents(params) {
    const repo = await this.getRepo();
    return repo.listPKEvents(params);
  }
}

export const pkService = new PKService();
export default pkService;
