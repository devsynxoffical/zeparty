import type { Server as HttpServer } from 'node:http';
import { WebSocketServer, type WebSocket } from 'ws';
import type { AuthAdapter, ZePartyIdentity } from '../auth/types.js';
import type { MatchmakingQueue } from '../matchmaking/queue.js';
import { RoomError, type Outbound, type RoomManager, type ServerMessage } from '../rooms/roomManager.js';
import type { Room } from '../rooms/types.js';
import { ClientMessageSchema } from './protocol.js';
import type { Logger } from 'pino';

interface Session {
  socket: WebSocket;
  identity: ZePartyIdentity | null;
  alive: boolean;
}

/**
 * One socket per user. A new socket for an already connected user replaces the old one
 * (phone reconnecting on a new network), triggering a resync instead of a disconnect.
 */
export class GameSocketServer implements Outbound {
  private wss: WebSocketServer;
  private sessions = new Map<WebSocket, Session>();
  private byUser = new Map<string, WebSocket>();
  private heartbeat: NodeJS.Timeout;
  public rooms!: RoomManager;
  public matchmaking!: MatchmakingQueue;

  constructor(
    server: HttpServer,
    private readonly auth: AuthAdapter,
    private readonly disconnectGraceSeconds: number,
    private readonly log: Logger,
  ) {
    this.wss = new WebSocketServer({ server, path: '/ws' });
    this.wss.on('connection', (socket) => this.onConnection(socket));
    this.heartbeat = setInterval(() => {
      for (const [socket, s] of this.sessions) {
        if (!s.alive) {
          socket.terminate();
          continue;
        }
        s.alive = false;
        socket.ping();
      }
    }, 15_000);
  }

  close(): void {
    clearInterval(this.heartbeat);
    this.wss.close();
  }

  // Outbound ------------------------------------------------------------------------------

  toUser(userId: string, message: ServerMessage): void {
    const socket = this.byUser.get(userId);
    if (socket && socket.readyState === socket.OPEN) socket.send(JSON.stringify(message));
  }

  toRoom(room: Room, message: ServerMessage, except?: string): void {
    const recipients = [...room.players.map((p) => p.userId), ...room.spectators];
    for (const uid of recipients) if (uid !== except) this.toUser(uid, message);
  }

  connectedUserIds(): string[] {
    return [...this.byUser.keys()];
  }

  // Inbound -------------------------------------------------------------------------------

  private onConnection(socket: WebSocket): void {
    const session: Session = { socket, identity: null, alive: true };
    this.sessions.set(socket, session);
    socket.on('pong', () => (session.alive = true));
    socket.on('message', (raw) => void this.onMessage(session, raw.toString()));
    socket.on('close', () => this.onClose(session));
    socket.on('error', (err) => this.log.warn({ err }, 'socket error'));
    // Unauthenticated sockets are dropped after 10 s.
    setTimeout(() => {
      if (!session.identity && socket.readyState === socket.OPEN) socket.close(4001, 'auth timeout');
    }, 10_000);
  }

  private send(session: Session, message: ServerMessage): void {
    if (session.socket.readyState === session.socket.OPEN) session.socket.send(JSON.stringify(message));
  }

  private onClose(session: Session): void {
    this.sessions.delete(session.socket);
    const id = session.identity;
    if (!id) return;
    if (this.byUser.get(id.userId) === session.socket) {
      this.byUser.delete(id.userId);
      this.rooms.markDisconnected(id.userId, this.disconnectGraceSeconds);
    }
  }

  private async onMessage(session: Session, raw: string): Promise<void> {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return this.send(session, { type: 'error', code: 'bad_json', message: 'message must be JSON' });
    }
    const result = ClientMessageSchema.safeParse(parsed);
    if (!result.success) {
      return this.send(session, { type: 'error', code: 'bad_message', message: result.error.issues.map((i) => i.message).join('; ') });
    }
    const msg = result.data;
    const reqId = msg.reqId;
    try {
      if (msg.type === 'auth') {
        const identity = await this.auth.verify(msg.token);
        if (!identity) {
          this.send(session, { type: 'error', code: 'unauthorized', message: 'invalid token', reqId });
          session.socket.close(4003, 'unauthorized');
          return;
        }
        session.identity = identity;
        const previous = this.byUser.get(identity.userId);
        if (previous && previous !== session.socket) {
          const prevSession = this.sessions.get(previous);
          if (prevSession) prevSession.identity = null; // so its close does not mark us disconnected
          previous.close(4004, 'replaced by new connection');
        }
        this.byUser.set(identity.userId, session.socket);
        this.rooms.markConnected(identity.userId);
        this.send(session, { type: 'player.presence', roomId: this.rooms.roomOf(identity.userId)?.roomId ?? '', userId: identity.userId, connected: true });
        return;
      }
      if (!session.identity) {
        this.send(session, { type: 'error', code: 'unauthorized', message: 'send auth first', reqId });
        return;
      }
      const id = session.identity;
      switch (msg.type) {
        case 'ping':
          this.send(session, { type: 'player.presence', roomId: '', userId: id.userId, connected: true });
          return;
        case 'room.create':
          await this.rooms.createRoom(id, msg.gameId, { isPrivate: msg.isPrivate, maxPlayers: msg.maxPlayers, rules: msg.rules });
          return;
        case 'room.join':
          this.rooms.joinRoom(id, msg.roomId, msg.inviteCode);
          this.rooms.resync(id.userId, 0);
          return;
        case 'room.spectate':
          this.rooms.spectate(id, msg.roomId);
          return;
        case 'room.leave':
          this.rooms.leaveRoom(id.userId, 'left');
          return;
        case 'room.ready':
          this.rooms.setReady(id.userId, msg.ready);
          return;
        case 'room.invite':
          this.rooms.invite(id.userId, msg.roomId, msg.userId);
          return;
        case 'room.kick':
          this.rooms.kick(id.userId, msg.userId);
          return;
        case 'room.start':
          await this.rooms.startMatch(id.userId);
          return;
        case 'room.rematch':
          await this.rooms.voteRematch(id.userId);
          return;
        case 'room.resync':
          this.rooms.resync(id.userId, msg.afterSeq ?? 0);
          return;
        case 'voice.state':
          this.rooms.setVoiceState(id.userId, msg.micActive, msg.muted);
          return;
        case 'matchmaking.join':
          await this.matchmaking.enqueue(id, msg.gameId, msg.tableSize);
          return;
        case 'matchmaking.leave':
          this.matchmaking.dequeue(id.userId);
          return;
        case 'game.action':
          await this.rooms.submitAction(id.userId, msg.roomId, msg.matchId, msg.action, msg.version);
          return;
      }
    } catch (err) {
      if (err instanceof RoomError) {
        this.send(session, { type: 'error', code: err.code, message: err.message, reqId });
      } else {
        this.log.error({ err }, 'unhandled ws error');
        this.send(session, { type: 'error', code: 'internal', message: 'internal error', reqId });
      }
    }
  }
}
