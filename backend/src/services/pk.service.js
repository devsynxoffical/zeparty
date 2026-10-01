import socketEmitter from '../socket/socket.emitter.js';

export class PKService {
  constructor(repo = null) {
    this.customRepo = repo;
    // In-memory matchmaking queue: array of { roomId, hostUserId, region, queuedAt, roomTitle, hostInfo }
    this.matchmakingQueue = [];
    // Pending invitations: map of invitationId -> { id, fromRoomId, fromHostUserId, fromHostInfo, targetRoomId, targetHostUserId, durationSeconds, createdAt }
    this.pendingInvitations = new Map();
  }

  async getRepo() {
    if (this.customRepo) return this.customRepo;
    const module = await import('../repositories/pk.repository.js');
    return module.default;
  }

  /**
   * Start a new PK battle between two active live rooms.
   */
  async startPK({ roomAId, roomBId, hostAUserId, hostBUserId, durationSeconds = 300 }) {
    if (!roomAId || !roomBId) {
      const error = new Error('Both roomAId and roomBId are required to initiate PK battle.');
      error.status = 400;
      error.code = 'INVALID_PK_PARTICIPANTS';
      throw error;
    }

    if (roomAId === roomBId) {
      const error = new Error('A room cannot start a PK battle with itself.');
      error.status = 400;
      error.code = 'SAME_ROOM_PK';
      throw error;
    }

    const repo = await this.getRepo();

    // Check if either room already has an active PK battle
    const [existingPKA, existingPKB] = await Promise.all([
      repo.findActivePKForRoom(roomAId),
      repo.findActivePKForRoom(roomBId),
    ]);

    if (existingPKA || existingPKB) {
      const error = new Error('One or both rooms are already in an active PK battle.');
      error.status = 409;
      error.code = 'PK_ALREADY_ACTIVE';
      throw error;
    }

    const pkEvent = await repo.createPKEvent({
      roomAId,
      roomBId,
      hostAUserId,
      hostBUserId,
      durationSeconds,
    });

    const pkPayload = {
      pkId: pkEvent.id,
      roomAId,
      roomBId,
      hostAUserId,
      hostBUserId,
      hostA: {
        id: pkEvent.roomA?.creator?.id || hostAUserId,
        name: pkEvent.roomA?.creator?.profile?.displayName || pkEvent.roomA?.creator?.username || 'Host Blue',
        username: pkEvent.roomA?.creator?.username || 'host_blue',
        avatarUrl: pkEvent.roomA?.creator?.avatarUrl || '',
      },
      hostB: {
        id: pkEvent.roomB?.creator?.id || hostBUserId,
        name: pkEvent.roomB?.creator?.profile?.displayName || pkEvent.roomB?.creator?.username || 'Host Red',
        username: pkEvent.roomB?.creator?.username || 'host_red',
        avatarUrl: pkEvent.roomB?.creator?.avatarUrl || '',
      },
      durationSeconds,
      status: 'COUNTDOWN',
      hostAScore: '0',
      hostBScore: '0',
    };

    // Broadcast PK started event to both rooms via Socket.IO
    socketEmitter.emitToRoom(roomAId, 'pk:started', pkPayload);
    socketEmitter.emitToRoom(roomBId, 'pk:started', pkPayload);
    socketEmitter.emitToUser(hostAUserId, 'pk:started', pkPayload);
    socketEmitter.emitToUser(hostBUserId, 'pk:started', pkPayload);

    return pkEvent;
  }

  /**
   * Transition PK battle from COUNTDOWN to ACTIVE.
   */
  async activatePK(pkId) {
    const repo = await this.getRepo();
    const pkEvent = await repo.findPKEventById(pkId);
    if (!pkEvent) {
      const error = new Error('PK battle not found.');
      error.status = 404;
      error.code = 'PK_NOT_FOUND';
      throw error;
    }

    if (pkEvent.status !== 'COUNTDOWN') {
      return pkEvent;
    }

    const updated = await repo.updatePKStatus(pkId, { status: 'ACTIVE' });

    socketEmitter.emitToRoom(pkEvent.roomAId, 'pk:active', { pkId, status: 'ACTIVE' });
    socketEmitter.emitToRoom(pkEvent.roomBId, 'pk:active', { pkId, status: 'ACTIVE' });

    return updated;
  }

  /**
   * Accumulate PK battle score upon live gift sending.
   */
  async addPKScore({ roomId, giftCoinValue }) {
    const repo = await this.getRepo();
    const activePK = await repo.findActivePKForRoom(roomId);
    if (!activePK || (activePK.status !== 'ACTIVE' && activePK.status !== 'COUNTDOWN')) {
      return null;
    }

    const isHostA = activePK.roomAId === roomId;
    const hostKey = isHostA ? 'hostA' : 'hostB';

    const updated = await repo.incrementHostScore(activePK.id, hostKey, giftCoinValue);

    const scorePayload = {
      pkId: activePK.id,
      hostAScore: updated.hostAScore.toString(),
      hostBScore: updated.hostBScore.toString(),
      recentGiftCoins: giftCoinValue,
      scoredRoomId: roomId,
    };

    socketEmitter.emitToRoom(activePK.roomAId, 'pk:score_updated', scorePayload);
    socketEmitter.emitToRoom(activePK.roomBId, 'pk:score_updated', scorePayload);

    return updated;
  }

  /**
   * Conclude PK battle and determine winner.
   */
  async endPK(pkId) {
    const repo = await this.getRepo();
    const pkEvent = await repo.findPKEventById(pkId);
    if (!pkEvent) {
      const error = new Error('PK battle not found.');
      error.status = 404;
      error.code = 'PK_NOT_FOUND';
      throw error;
    }

    if (pkEvent.status === 'ENDED') {
      return pkEvent;
    }

    let winnerHostUserId = null;
    if (pkEvent.hostAScore > pkEvent.hostBScore) {
      winnerHostUserId = pkEvent.hostAUserId;
    } else if (pkEvent.hostBScore > pkEvent.hostAScore) {
      winnerHostUserId = pkEvent.hostBUserId;
    }

    const updated = await repo.updatePKStatus(pkId, {
      status: 'ENDED',
      winnerHostUserId,
      endedAt: new Date(),
    });

    const endPayload = {
      pkId: pkEvent.id,
      status: 'ENDED',
      winnerHostUserId,
      isTie: winnerHostUserId === null,
      hostAScore: pkEvent.hostAScore.toString(),
      hostBScore: pkEvent.hostBScore.toString(),
    };

    socketEmitter.emitToRoom(pkEvent.roomAId, 'pk:ended', endPayload);
    socketEmitter.emitToRoom(pkEvent.roomBId, 'pk:ended', endPayload);

    return updated;
  }

  /**
   * Get active PK status for a live room.
   */
  async getRoomPKStatus(roomId) {
    const repo = await this.getRepo();
    const activePK = await repo.findActivePKForRoom(roomId);
    return activePK || null;
  }

  // ─── Real-Time Matchmaking Queue ──────────────────────────────────────────

  async joinMatchmaking({ roomId, hostUserId, region = 'GLOBAL', hostInfo = {} }) {
    const repo = await this.getRepo();

    // Check if room is already in an active PK
    const existing = await repo.findActivePKForRoom(roomId);
    if (existing) {
      return {
        matched: true,
        pkEvent: existing,
        message: 'Room already in an active PK battle.',
      };
    }

    // Clean stale items in queue (> 60s)
    const now = Date.now();
    this.matchmakingQueue = this.matchmakingQueue.filter(
      (item) => now - item.queuedAt < 60000 && item.roomId !== roomId
    );

    // Look for match in queue (prefer same region, or any other live host)
    let matchIdx = this.matchmakingQueue.findIndex(
      (item) => item.hostUserId !== hostUserId && item.roomId !== roomId && item.region === region
    );
    if (matchIdx === -1) {
      matchIdx = this.matchmakingQueue.findIndex(
        (item) => item.hostUserId !== hostUserId && item.roomId !== roomId
      );
    }

    if (matchIdx !== -1) {
      const opponent = this.matchmakingQueue.splice(matchIdx, 1)[0];
      const pkEvent = await this.startPK({
        roomAId: opponent.roomId,
        roomBId: roomId,
        hostAUserId: opponent.hostUserId,
        hostBUserId,
        durationSeconds: 300,
      });

      return {
        matched: true,
        pkEvent,
        opponent: opponent.hostInfo,
      };
    }

    // Check available active live rooms in DB to see if any available host can be matched
    const availableRooms = await repo.findAvailableLiveRooms({
      excludeRoomId: roomId,
      excludeUserId: hostUserId,
    });

    // Filter rooms not currently in active PK
    const validRooms = [];
    for (const r of availableRooms) {
      const active = await repo.findActivePKForRoom(r.id);
      if (!active) {
        validRooms.push(r);
      }
    }

    if (validRooms.length > 0) {
      // Direct match with first eligible active live room
      const targetRoom = validRooms[0];
      const pkEvent = await this.startPK({
        roomAId: roomId,
        roomBId: targetRoom.id,
        hostAUserId,
        hostBUserId: targetRoom.creatorUserId,
        durationSeconds: 300,
      });

      return {
        matched: true,
        pkEvent,
        opponent: {
          id: targetRoom.creator.id,
          username: targetRoom.creator.username,
          name: targetRoom.creator.profile?.displayName || targetRoom.creator.username,
          avatarUrl: targetRoom.creator.avatarUrl || '',
          roomTitle: targetRoom.title,
        },
      };
    }

    // Enqueue
    this.matchmakingQueue.push({
      roomId,
      hostUserId,
      region,
      hostInfo,
      queuedAt: now,
    });

    return {
      matched: false,
      inQueue: true,
      message: 'Searching for live opponent in your region...',
    };
  }

  async leaveMatchmaking(roomId) {
    this.matchmakingQueue = this.matchmakingQueue.filter((item) => item.roomId !== roomId);
    return { success: true, message: 'Left PK matchmaking queue.' };
  }

  // ─── Manual Host-to-Host Invitations ──────────────────────────────────────

  async sendPKInvite({ fromRoomId, fromHostUserId, targetRoomId, targetUserId, durationSeconds = 300, fromHostInfo = {} }) {
    const repo = await this.getRepo();

    // Check if inviter or target already in active PK
    const [pkA, pkB] = await Promise.all([
      repo.findActivePKForRoom(fromRoomId),
      targetRoomId ? repo.findActivePKForRoom(targetRoomId) : Promise.resolve(null),
    ]);

    if (pkA) {
      const error = new Error('Your room is already in an active PK battle.');
      error.status = 400;
      throw error;
    }
    if (pkB) {
      const error = new Error('Target room is already in an active PK battle.');
      error.status = 400;
      throw error;
    }

    const invitationId = `pki_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;
    const invite = {
      id: invitationId,
      fromRoomId,
      fromHostUserId,
      fromHostInfo,
      targetRoomId,
      targetUserId,
      durationSeconds,
      createdAt: Date.now(),
      status: 'PENDING',
    };

    this.pendingInvitations.set(invitationId, invite);

    const payload = {
      invitationId,
      fromRoomId,
      fromHost: fromHostInfo,
      targetRoomId,
      targetUserId,
      durationSeconds,
    };

    // Emit to target room and target user
    if (targetRoomId) {
      socketEmitter.emitToRoom(targetRoomId, 'pk:invitation_received', payload);
    }
    if (targetUserId) {
      socketEmitter.emitToUser(targetUserId, 'pk:invitation_received', payload);
    }

    return {
      success: true,
      invitationId,
      message: 'PK battle invitation sent successfully.',
    };
  }

  async respondPKInvite({ invitationId, responderUserId, responderRoomId, action }) {
    const invite = this.pendingInvitations.get(invitationId);
    if (!invite) {
      const error = new Error('PK invitation expired or not found.');
      error.status = 404;
      throw error;
    }

    if (action === 'ACCEPT') {
      const targetRoomId = responderRoomId || invite.targetRoomId;
      if (!targetRoomId) {
        const error = new Error('Responder must have an active live room.');
        error.status = 400;
        throw error;
      }

      this.pendingInvitations.delete(invitationId);

      const pkEvent = await this.startPK({
        roomAId: invite.fromRoomId,
        roomBId: targetRoomId,
        hostAUserId: invite.fromHostUserId,
        hostBUserId: responderUserId || invite.targetUserId,
        durationSeconds: invite.durationSeconds || 300,
      });

      socketEmitter.emitToRoom(invite.fromRoomId, 'pk:invitation_accepted', {
        invitationId,
        pkId: pkEvent.id,
      });

      return {
        success: true,
        accepted: true,
        pkEvent,
      };
    } else {
      this.pendingInvitations.delete(invitationId);

      socketEmitter.emitToRoom(invite.fromRoomId, 'pk:invitation_declined', {
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

  // ─── Available Live Hosts Discovery ───────────────────────────────────────

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
   * List PK events for Admin oversight.
   */
  async listAdminPKEvents(params) {
    const repo = await this.getRepo();
    return repo.listPKEvents(params);
  }
}

export const pkService = new PKService();
export default pkService;
