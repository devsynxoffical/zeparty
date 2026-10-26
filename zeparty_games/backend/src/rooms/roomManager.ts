import type { ZePartyIdentity } from '../auth/types.js';
import type { GameConfigStore } from '../admin/gameConfig.js';
import { CryptoRng, isRealtimeEngine, type GameEngine, type Rng } from '../games/engine.js';
import { getCatalogEntry, getEngine } from '../games/registry.js';
import type { WalletService } from '../wallet/service.js';
import { newInviteCode, newMatchId, newRoomId } from './ids.js';
import type { MatchStore } from './matchStore.js';
import { toRoomView, type Room, type RoomPlayer, type RoomSummary, type SequencedEvent } from './types.js';
import type { AchievementService } from '../achievements/service.js';

export class RoomError extends Error {
  public readonly detail: string;
  constructor(
    public readonly code: string,
    detail?: string,
  ) {
    super(detail ? `${code}: ${detail}` : code);
    this.detail = detail ?? code;
    this.name = 'RoomError';
  }
}

/** Outbound messaging abstraction so the manager can be tested without sockets. */
export interface Outbound {
  toUser(userId: string, message: ServerMessage): void;
  toRoom(room: Room, message: ServerMessage, except?: string): void;
}

export type ServerMessage =
  | { type: 'room.state'; room: ReturnType<typeof toRoomView> }
  | { type: 'room.closed'; roomId: string; reason: string }
  | { type: 'room.invite'; roomId: string; gameId: string; fromUserId: string; fromName: string; inviteCode: string }
  | { type: 'game.state'; roomId: string; matchId: string; version: number; seq: number; yourSeat: number | null; state: unknown; deadline: number | null }
  | { type: 'game.events'; roomId: string; matchId: string; events: SequencedEvent[]; state: unknown; version: number }
  | { type: 'game.result'; roomId: string; matchId: string; placements: Array<{ seat: number; userId: string; placement: number; score: number }>; winnerIds: string[]; rewards: Record<string, number> }
  | { type: 'player.presence'; roomId: string; userId: string; connected: boolean; micActive?: boolean; muted?: boolean }
  | { type: 'error'; code: string; message: string; reqId?: string };

interface Timers {
  turn: NodeJS.Timeout | null;
  disconnect: Map<string, NodeJS.Timeout>;
  realtime: NodeJS.Timeout | null;
}

export interface RoomManagerDeps {
  gameConfig: GameConfigStore;
  wallet: WalletService;
  matchStore: MatchStore;
  achievements: AchievementService;
  outbound: Outbound;
  rng?: Rng;
  now?: () => number;
}

/**
 * Authoritative room and match orchestration. Single-process in-memory room state.
 * Horizontal scaling: rooms are sticky to the instance that owns them; see
 * docs/architecture/multiplayer.md for the Redis-backed ownership map plan.
 */
export class RoomManager {
  private rooms = new Map<string, Room>();
  private timers = new Map<string, Timers>();
  private userRoom = new Map<string, string>();
  private readonly rng: Rng;
  private readonly now: () => number;

  constructor(private readonly deps: RoomManagerDeps) {
    this.rng = deps.rng ?? new CryptoRng();
    this.now = deps.now ?? (() => Date.now());
  }

  // ---------------------------------------------------------------------------------------
  // Room lifecycle
  // ---------------------------------------------------------------------------------------

  async createRoom(identity: ZePartyIdentity, gameId: string, opts: { isPrivate?: boolean; rules?: Record<string, unknown>; maxPlayers?: number } = {}): Promise<Room> {
    const entry = getCatalogEntry(gameId);
    if (!entry) throw new RoomError('unknown_game');
    if (!getEngine(gameId)) throw new RoomError('game_unavailable', `${gameId} is not playable yet`);
    const cfg = await this.deps.gameConfig.get(gameId);
    if (!cfg.enabled) throw new RoomError('game_disabled');
    if (this.userRoom.has(identity.userId)) this.leaveRoom(identity.userId, 'left');
    const maxPlayers = Math.min(opts.maxPlayers ?? cfg.maxPlayers, cfg.maxPlayers);
    const room: Room = {
      roomId: newRoomId(),
      gameId,
      hostUserId: identity.userId,
      isPrivate: opts.isPrivate ?? false,
      inviteCode: newInviteCode(),
      rules: { ...cfg.rules, ...(opts.rules ?? {}), turnTimeoutSeconds: cfg.turnTimeoutSeconds },
      maxPlayers,
      minPlayers: cfg.minPlayers,
      players: [],
      spectators: [],
      invitedUserIds: [],
      status: 'waiting',
      match: null,
      createdAt: this.now(),
      rematchVotes: [],
    };
    this.rooms.set(room.roomId, room);
    this.timers.set(room.roomId, { turn: null, disconnect: new Map(), realtime: null });
    this.addPlayer(room, identity);
    this.broadcastRoom(room);
    return room;
  }

  listPublicRooms(gameId?: string): RoomSummary[] {
    return [...this.rooms.values()]
      .filter((r) => !r.isPrivate && r.status === 'waiting' && (!gameId || r.gameId === gameId))
      .map((r) => ({ roomId: r.roomId, gameId: r.gameId, hostUserId: r.hostUserId, isPrivate: r.isPrivate, status: r.status, playerCount: r.players.length, maxPlayers: r.maxPlayers, createdAt: r.createdAt }));
  }

  getRoom(roomId: string): Room | null {
    return this.rooms.get(roomId) ?? null;
  }

  roomOf(userId: string): Room | null {
    const id = this.userRoom.get(userId);
    return id ? (this.rooms.get(id) ?? null) : null;
  }

  joinRoom(identity: ZePartyIdentity, roomId: string, inviteCode?: string): Room {
    const room = this.rooms.get(roomId);
    if (!room) throw new RoomError('room_not_found');
    const existing = room.players.find((p) => p.userId === identity.userId);
    if (existing) {
      // Rejoin (e.g. reconnect through a fresh socket) is handled by markConnected.
      return room;
    }
    if (room.isPrivate && inviteCode !== room.inviteCode && !room.invitedUserIds.includes(identity.userId)) {
      throw new RoomError('invite_required');
    }
    if (room.status !== 'waiting') throw new RoomError('match_in_progress', 'join as spectator instead');
    if (room.players.length >= room.maxPlayers) throw new RoomError('room_full');
    if (this.userRoom.has(identity.userId)) this.leaveRoom(identity.userId, 'left');
    this.addPlayer(room, identity);
    this.broadcastRoom(room);
    return room;
  }

  spectate(identity: ZePartyIdentity, roomId: string): Room {
    const room = this.rooms.get(roomId);
    if (!room) throw new RoomError('room_not_found');
    if (room.players.some((p) => p.userId === identity.userId)) throw new RoomError('already_player');
    if (!room.spectators.includes(identity.userId)) room.spectators.push(identity.userId);
    this.userRoom.set(identity.userId, room.roomId);
    this.deps.outbound.toUser(identity.userId, { type: 'room.state', room: toRoomView(room) });
    if (room.match) this.sendState(room, identity.userId);
    return room;
  }

  invite(fromUserId: string, roomId: string, toUserId: string): void {
    const room = this.rooms.get(roomId);
    if (!room) throw new RoomError('room_not_found');
    const from = room.players.find((p) => p.userId === fromUserId);
    if (!from) throw new RoomError('not_in_room');
    if (!room.invitedUserIds.includes(toUserId)) room.invitedUserIds.push(toUserId);
    this.deps.outbound.toUser(toUserId, { type: 'room.invite', roomId, gameId: room.gameId, fromUserId, fromName: from.displayName, inviteCode: room.inviteCode });
  }

  setReady(userId: string, ready: boolean): Room {
    const room = this.requireRoomOf(userId);
    if (room.status !== 'waiting') throw new RoomError('match_in_progress');
    const p = room.players.find((x) => x.userId === userId);
    if (!p) throw new RoomError('not_in_room');
    p.ready = ready;
    this.broadcastRoom(room);
    return room;
  }

  leaveRoom(userId: string, reason: 'left' | 'kicked' | 'timeout' = 'left'): void {
    const room = this.roomOf(userId);
    if (!room) return;
    this.userRoom.delete(userId);
    room.spectators = room.spectators.filter((s) => s !== userId);
    const idx = room.players.findIndex((p) => p.userId === userId);
    if (idx === -1) {
      this.broadcastRoom(room);
      return;
    }
    const player = room.players[idx]!;
    if (room.status === 'playing' && room.match) {
      player.connected = false;
      // Forfeit in the engine; the seat stays in the room list so results render.
      const engine = getEngine(room.gameId)!;
      const step = engine.onPlayerLeft(room.match.state, player.seat, this.rng);
      void this.commitStep(room, step, player.seat);
      this.deps.outbound.toUser(userId, { type: 'room.closed', roomId: room.roomId, reason });
      return;
    }
    room.players.splice(idx, 1);
    room.players.forEach((p, i) => (p.seat = i));
    this.deps.outbound.toUser(userId, { type: 'room.closed', roomId: room.roomId, reason });
    if (room.players.length === 0) {
      this.destroyRoom(room, 'empty');
      return;
    }
    if (room.hostUserId === userId) room.hostUserId = room.players[0]!.userId;
    this.broadcastRoom(room);
  }

  kick(hostUserId: string, targetUserId: string): void {
    const room = this.requireRoomOf(hostUserId);
    if (room.hostUserId !== hostUserId) throw new RoomError('not_host');
    if (room.status !== 'waiting') throw new RoomError('match_in_progress');
    this.leaveRoom(targetUserId, 'kicked');
  }

  /** Voice state hooks mirrored from the host app's audio subsystem. */
  setVoiceState(userId: string, micActive: boolean, muted: boolean): void {
    const room = this.roomOf(userId);
    const p = room?.players.find((x) => x.userId === userId);
    if (!room || !p) return;
    p.micActive = micActive;
    p.muted = muted;
    this.deps.outbound.toRoom(room, { type: 'player.presence', roomId: room.roomId, userId, connected: p.connected, micActive, muted });
  }

  private addPlayer(room: Room, identity: ZePartyIdentity): void {
    const player: RoomPlayer = {
      userId: identity.userId,
      displayName: identity.displayName,
      avatarUrl: identity.avatarUrl,
      seat: room.players.length,
      ready: false,
      connected: true,
      disconnectedAt: null,
      micActive: false,
      muted: false,
    };
    room.players.push(player);
    this.userRoom.set(identity.userId, room.roomId);
  }

  private requireRoomOf(userId: string): Room {
    const room = this.roomOf(userId);
    if (!room) throw new RoomError('not_in_room');
    return room;
  }

  private destroyRoom(room: Room, reason: string): void {
    const t = this.timers.get(room.roomId);
    if (t) {
      if (t.turn) clearTimeout(t.turn);
      if (t.realtime) clearInterval(t.realtime);
      t.disconnect.forEach((h) => clearTimeout(h));
    }
    this.timers.delete(room.roomId);
    for (const p of room.players) this.userRoom.delete(p.userId);
    for (const s of room.spectators) this.userRoom.delete(s);
    this.deps.outbound.toRoom(room, { type: 'room.closed', roomId: room.roomId, reason });
    this.rooms.delete(room.roomId);
  }

  private broadcastRoom(room: Room): void {
    this.deps.outbound.toRoom(room, { type: 'room.state', room: toRoomView(room) });
  }

  // ---------------------------------------------------------------------------------------
  // Match lifecycle
  // ---------------------------------------------------------------------------------------

  async startMatch(userId: string): Promise<Room> {
    const room = this.requireRoomOf(userId);
    if (room.hostUserId !== userId) throw new RoomError('not_host');
    if (room.status === 'playing') throw new RoomError('match_in_progress');
    if (room.players.length < room.minPlayers) throw new RoomError('not_enough_players');
    const notReady = room.players.filter((p) => !p.ready && p.userId !== room.hostUserId);
    if (notReady.length > 0) throw new RoomError('players_not_ready', notReady.map((p) => p.displayName).join(', '));
    return this.beginMatch(room);
  }

  /** Used by matchmaking when the table fills: no host, everyone is implicitly ready. */
  async beginMatch(room: Room): Promise<Room> {
    const engine = getEngine(room.gameId);
    if (!engine) throw new RoomError('game_unavailable');
    const seats = room.players.map((p) => ({ seat: p.seat, userId: p.userId, displayName: p.displayName }));
    const state = engine.createInitialState(seats, room.rules, this.rng);
    const match = {
      matchId: newMatchId(),
      gameId: room.gameId,
      state,
      seq: 0,
      events: [],
      startedAt: this.now(),
      endedAt: null,
      rewardsGranted: false,
    };
    room.match = match;
    room.status = 'playing';
    room.rematchVotes = [];
    room.players.forEach((p) => (p.ready = false));
    await this.deps.matchStore.start({
      matchId: match.matchId,
      roomId: room.roomId,
      gameId: room.gameId,
      rules: room.rules,
      status: 'active',
      startedAt: new Date(match.startedAt).toISOString(),
      endedAt: null,
      winnerIds: [],
      participants: room.players.map((p) => ({ userId: p.userId, seat: p.seat, placement: null, score: 0 })),
    });
    this.broadcastRoom(room);
    for (const p of room.players) this.sendState(room, p.userId);
    for (const s of room.spectators) this.sendState(room, s);
    this.armTurnTimer(room);
    this.startRealtimeLoop(room);
    return room;
  }

  /** Server clock for real-time engines. Ticks the simulation and batches broadcasts. */
  private startRealtimeLoop(room: Room): void {
    const engine = getEngine(room.gameId);
    const t = this.timers.get(room.roomId);
    if (!engine || !t || !isRealtimeEngine(engine) || !room.match) return;
    if (t.realtime) clearInterval(t.realtime);
    const matchId = room.match.matchId;
    const tickMs = 1000 / engine.tickRateHz;
    const broadcastEvery = Math.max(1, Math.round(engine.tickRateHz / engine.broadcastHz));
    let last = this.now();
    let n = 0;
    let pending: Array<{ type: string; seat?: number; payload: Record<string, unknown> }> = [];
    t.realtime = setInterval(() => {
      const m = room.match;
      if (!m || m.matchId !== matchId || room.status !== 'playing') {
        if (t.realtime) clearInterval(t.realtime);
        t.realtime = null;
        return;
      }
      const nowMs = this.now();
      const dt = Math.min(100, nowMs - last);
      last = nowMs;
      const step = engine.tick(m.state, dt, this.rng);
      m.state = step.state;
      pending.push(...step.events);
      n++;
      const finished = engine.getResult(m.state).finished;
      if (n % broadcastEvery === 0 || finished) {
        const events = pending;
        pending = [];
        events.push({ type: 'state_tick', payload: { at: nowMs } });
        void this.commitStep(room, { state: m.state, events }, null);
      }
    }, tickMs);
  }

  private seatOf(room: Room, userId: string): number | null {
    return room.players.find((p) => p.userId === userId)?.seat ?? null;
  }

  private sendState(room: Room, userId: string): void {
    const m = room.match;
    if (!m) return;
    const engine = getEngine(room.gameId)!;
    const seat = this.seatOf(room, userId);
    const deadline = (m.state as { turnDeadline?: number | null }).turnDeadline ?? null;
    this.deps.outbound.toUser(userId, {
      type: 'game.state',
      roomId: room.roomId,
      matchId: m.matchId,
      version: (m.state as { version?: number }).version ?? m.seq,
      seq: m.seq,
      yourSeat: seat,
      state: engine.getView(m.state, seat),
      deadline,
    });
  }

  /** Reconnection: resend room, full state and any events after `afterSeq`. */
  resync(userId: string, afterSeq = 0): void {
    const room = this.roomOf(userId);
    if (!room) return;
    this.deps.outbound.toUser(userId, { type: 'room.state', room: toRoomView(room) });
    if (!room.match) return;
    this.sendState(room, userId);
    const missed = room.match.events.filter((e) => e.seq > afterSeq);
    if (missed.length > 0) {
      const engine = getEngine(room.gameId)!;
      this.deps.outbound.toUser(userId, {
        type: 'game.events',
        roomId: room.roomId,
        matchId: room.match.matchId,
        events: missed,
        state: engine.getView(room.match.state, this.seatOf(room, userId)),
        version: (room.match.state as { version?: number }).version ?? room.match.seq,
      });
    }
  }

  async submitAction(userId: string, roomId: string, matchId: string, action: unknown, clientVersion?: number): Promise<void> {
    const room = this.rooms.get(roomId);
    if (!room || !room.match) throw new RoomError('no_active_match');
    if (room.match.matchId !== matchId) throw new RoomError('stale_match', 'action targets a different match');
    if (room.status !== 'playing') throw new RoomError('no_active_match');
    const seat = this.seatOf(room, userId);
    if (seat === null) throw new RoomError('not_a_player');
    const engine = getEngine(room.gameId)!;
    const version = (room.match.state as { version?: number }).version ?? room.match.seq;
    if (clientVersion !== undefined && clientVersion !== version) {
      // Duplicate or out-of-date submission; resync instead of applying twice.
      this.resync(userId, 0);
      throw new RoomError('version_mismatch', `expected ${version}`);
    }
    const v = engine.validateAction(room.match.state, seat, action);
    if (!v.ok) throw new RoomError(v.code, v.message);
    const step = engine.applyAction(room.match.state, seat, action, this.rng);
    await this.commitStep(room, step, seat);
  }

  private async commitStep(room: Room, step: { state: unknown; events: Array<{ type: string; seat?: number; payload: Record<string, unknown> }> }, actorSeat: number | null): Promise<void> {
    const m = room.match;
    if (!m) return;
    m.state = step.state;
    const sequenced: SequencedEvent[] = step.events.map((event) => ({ seq: ++m.seq, at: this.now(), actorSeat, event }));
    m.events.push(...sequenced);
    const engine = getEngine(room.gameId)!;
    const version = (m.state as { version?: number }).version ?? m.seq;
    // Per-viewer broadcast so hidden information stays private.
    const recipients = [...room.players.map((p) => p.userId), ...room.spectators];
    for (const uid of recipients) {
      this.deps.outbound.toUser(uid, {
        type: 'game.events',
        roomId: room.roomId,
        matchId: m.matchId,
        events: sequenced,
        state: engine.getView(m.state, this.seatOf(room, uid)),
        version,
      });
    }
    const durable = sequenced.filter((e) => e.event.type !== 'state_tick');
    if (durable.length > 0) void this.deps.matchStore.appendEvents(m.matchId, durable).catch(() => undefined);
    const result = engine.getResult(m.state);
    if (result.finished) await this.finishMatch(room);
    else this.armTurnTimer(room);
  }

  private armTurnTimer(room: Room): void {
    const t = this.timers.get(room.roomId);
    const m = room.match;
    if (!t || !m) return;
    if (t.turn) clearTimeout(t.turn);
    t.turn = null;
    const deadline = (m.state as { turnDeadline?: number | null }).turnDeadline ?? null;
    if (deadline === null) return;
    const delay = Math.max(0, deadline - this.now());
    t.turn = setTimeout(() => void this.fireTimeout(room.roomId, m.matchId, deadline), delay + 250);
  }

  private async fireTimeout(roomId: string, matchId: string, deadline: number): Promise<void> {
    const room = this.rooms.get(roomId);
    if (!room?.match || room.match.matchId !== matchId || room.status !== 'playing') return;
    const current = (room.match.state as { turnDeadline?: number | null }).turnDeadline ?? null;
    if (current !== deadline) return; // state moved on already
    const engine = getEngine(room.gameId)!;
    const step = engine.onTimeout(room.match.state, this.rng);
    await this.commitStep(room, step, engine.currentSeat(room.match.state));
  }

  private async finishMatch(room: Room): Promise<void> {
    const m = room.match;
    if (!m || m.endedAt) return;
    m.endedAt = this.now();
    room.status = 'finished';
    const t = this.timers.get(room.roomId);
    if (t?.turn) clearTimeout(t.turn);
    const engine = getEngine(room.gameId)!;
    const result = engine.getResult(m.state);
    const placements = result.placements.map((p) => ({
      seat: p.seat,
      userId: room.players.find((x) => x.seat === p.seat)?.userId ?? 'unknown',
      placement: p.placement,
      score: p.score,
    }));
    const winnerIds = placements.filter((p) => result.winnerSeats.includes(p.seat)).map((p) => p.userId);
    await this.deps.matchStore.finish(m.matchId, m.state, placements.map(({ userId, placement, score }) => ({ userId, placement, score })), winnerIds).catch(() => undefined);
    const rewards: Record<string, number> = {};
    if (!m.rewardsGranted) {
      m.rewardsGranted = true;
      for (const p of placements) {
        let total = 0;
        const part = await this.deps.wallet.grantMatchReward(p.userId, room.gameId, m.matchId, 'participation').catch(() => null);
        if (part && part.status === 'applied') total += part.transaction.amount;
        if (winnerIds.includes(p.userId)) {
          const win = await this.deps.wallet.grantMatchReward(p.userId, room.gameId, m.matchId, 'win').catch(() => null);
          if (win && win.status === 'applied') total += win.transaction.amount;
        }
        rewards[p.userId] = total;
        await this.deps.achievements.onMatchFinished(p.userId, room.gameId, { won: winnerIds.includes(p.userId), placement: p.placement, seat: p.seat, events: m.events.map((e) => e.event) }).catch(() => undefined);
      }
    }
    this.deps.outbound.toRoom(room, { type: 'game.result', roomId: room.roomId, matchId: m.matchId, placements, winnerIds, rewards });
    // Drop players who left mid-match so the lobby reflects who is still here.
    room.players = room.players.filter((p) => p.connected);
    room.players.forEach((p, i) => (p.seat = i));
    if (room.players.length === 0) {
      this.destroyRoom(room, 'empty');
      return;
    }
    if (!room.players.some((p) => p.userId === room.hostUserId)) room.hostUserId = room.players[0]!.userId;
    room.status = 'waiting';
    room.match = null;
    this.broadcastRoom(room);
  }

  /** Rematch: when every current player votes, a new match begins on the same room. */
  async voteRematch(userId: string): Promise<Room> {
    const room = this.requireRoomOf(userId);
    if (room.status !== 'waiting') throw new RoomError('match_in_progress');
    if (!room.players.some((p) => p.userId === userId)) throw new RoomError('not_in_room');
    if (!room.rematchVotes.includes(userId)) room.rematchVotes.push(userId);
    const everyone = room.players.every((p) => room.rematchVotes.includes(p.userId));
    if (everyone && room.players.length >= room.minPlayers) return this.beginMatch(room);
    this.broadcastRoom(room);
    return room;
  }

  // ---------------------------------------------------------------------------------------
  // Connection tracking
  // ---------------------------------------------------------------------------------------

  markDisconnected(userId: string, graceSeconds: number): void {
    const room = this.roomOf(userId);
    if (!room) return;
    const p = room.players.find((x) => x.userId === userId);
    if (!p) {
      room.spectators = room.spectators.filter((s) => s !== userId);
      this.userRoom.delete(userId);
      return;
    }
    p.connected = false;
    p.disconnectedAt = this.now();
    this.deps.outbound.toRoom(room, { type: 'player.presence', roomId: room.roomId, userId, connected: false }, userId);
    const t = this.timers.get(room.roomId);
    if (!t) return;
    const existing = t.disconnect.get(userId);
    if (existing) clearTimeout(existing);
    t.disconnect.set(
      userId,
      setTimeout(() => {
        const still = this.roomOf(userId)?.players.find((x) => x.userId === userId);
        if (still && !still.connected) this.leaveRoom(userId, 'timeout');
      }, graceSeconds * 1000),
    );
  }

  markConnected(userId: string): void {
    const room = this.roomOf(userId);
    if (!room) return;
    const p = room.players.find((x) => x.userId === userId);
    if (p) {
      p.connected = true;
      p.disconnectedAt = null;
      const pendingDisconnect = this.timers.get(room.roomId)?.disconnect.get(userId);
      if (pendingDisconnect) clearTimeout(pendingDisconnect);
      this.timers.get(room.roomId)?.disconnect.delete(userId);
      this.deps.outbound.toRoom(room, { type: 'player.presence', roomId: room.roomId, userId, connected: true }, userId);
    }
    this.resync(userId, 0);
  }

  /** Test and admin helper. */
  engineFor(gameId: string): GameEngine<unknown, unknown> | null {
    return getEngine(gameId);
  }
}
