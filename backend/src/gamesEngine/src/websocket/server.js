import { WebSocketServer } from 'ws';
import { RoomError } from '../rooms/roomManager.js';
import { ClientMessageSchema } from './protocol.js';

/**
 * Multiplexed WebSocket server for ZeParty Games (/ws).
 * Uses `noServer: true` so it coexists cleanly on the same HTTP server as Socket.IO (/socket.io/).
 */
export class GameSocketServer {
  auth;
  disconnectGraceSeconds;
  log;
  wss;
  sessions = new Map();
  byUser = new Map();
  heartbeat;
  rooms;
  matchmaking;

  constructor(server, auth, disconnectGraceSeconds, log) {
    this.auth = auth;
    this.disconnectGraceSeconds = disconnectGraceSeconds;
    this.log = log;
    this.wss = new WebSocketServer({ noServer: true });

    server.on('upgrade', (req, socket, head) => {
      try {
        const pathname = new URL(req.url ?? '/', 'http://localhost').pathname;
        if (
          pathname === '/ws' ||
          pathname === '/api/games-hub/ws' ||
          pathname === '/api/v1/games-hub/ws' ||
          pathname === '/api/v1/games/ws'
        ) {
          this.wss.handleUpgrade(req, socket, head, (ws) => {
            this.wss.emit('connection', ws, req);
          });
        }
      } catch {
        // Ignore malformed upgrade URLs; let Socket.IO handle its own paths
      }
    });

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

  close() {
    clearInterval(this.heartbeat);
    this.wss.close();
  }

  toUser(userId, message) {
    const socket = this.byUser.get(userId);
    if (socket && socket.readyState === socket.OPEN) {
      socket.send(JSON.stringify(message));
    }
  }

  toRoom(room, message, except) {
    const recipients = [...room.players.map((p) => p.userId), ...room.spectators];
    for (const uid of recipients) {
      if (uid !== except) this.toUser(uid, message);
    }
  }

  connectedUserIds() {
    return [...this.byUser.keys()];
  }

  onConnection(socket) {
    const session = { socket, identity: null, alive: true };
    this.sessions.set(socket, session);
    socket.on('pong', () => (session.alive = true));
    socket.on('message', (raw) => void this.onMessage(session, raw.toString()));
    socket.on('close', () => this.onClose(session));
    socket.on('error', (err) => this.log.warn({ err }, 'socket error'));
    setTimeout(() => {
      if (!session.identity && socket.readyState === socket.OPEN) {
        socket.close(4001, 'auth timeout');
      }
    }, 10_000);
  }

  send(session, message) {
    if (session.socket.readyState === session.socket.OPEN) {
      // `t` lets clients align turn deadlines / chess clocks to the server's clock
      // instead of the device clock (see ServerClock in zeparty_game_core).
      session.socket.send(JSON.stringify({ ...message, t: Date.now() }));
    }
  }

  onClose(session) {
    this.sessions.delete(session.socket);
    const id = session.identity;
    if (!id) return;
    if (this.byUser.get(id.userId) === session.socket) {
      this.byUser.delete(id.userId);
      this.rooms.markDisconnected(id.userId, this.disconnectGraceSeconds);
    }
  }

  async onMessage(session, raw) {
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return this.send(session, { type: 'error', code: 'bad_json', message: 'message must be JSON' });
    }
    const result = ClientMessageSchema.safeParse(parsed);
    if (!result.success) {
      return this.send(session, {
        type: 'error',
        code: 'bad_message',
        message: result.error.issues.map((i) => i.message).join('; '),
      });
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
          if (prevSession) prevSession.identity = null;
          previous.close(4004, 'replaced by new connection');
        }
        this.byUser.set(identity.userId, session.socket);
        this.rooms.markConnected(identity.userId);
        this.send(session, {
          type: 'player.presence',
          roomId: this.rooms.roomOf(identity.userId)?.roomId ?? '',
          userId: identity.userId,
          connected: true,
        });
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
          await this.rooms.createRoom(id, msg.gameId, {
            isPrivate: msg.isPrivate,
            maxPlayers: msg.maxPlayers,
            rules: msg.rules,
          });
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
        this.log.warn({ userId: session.identity?.userId, msgType: msg.type, code: err.code, roomId: msg.roomId, matchId: msg.matchId }, 'ws command rejected');
        this.send(session, { type: 'error', code: err.code, message: err.message, reqId });
        // The client's idea of the room/match is behind the server's: push the
        // current state so it recovers without a reconnect.
        if (session.identity && (err.code === 'stale_match' || err.code === 'no_active_match' || err.code === 'not_a_player')) {
          try { this.rooms.resync(session.identity.userId, 0); } catch { /* no room for this user */ }
        }
      } else {
        this.log.error({ err, userId: session.identity?.userId, msgType: msg.type, roomId: msg.roomId, matchId: msg.matchId }, 'unhandled ws error');
        // Surface the reason: the app shows it in the "Action rejected (...)" toast, which is the
        // only diagnostic a tester can relay.
        const detail = String(err?.message ?? 'internal error').replace(/\s+/g, ' ').slice(0, 160);
        this.send(session, { type: 'error', code: 'internal', message: detail, reqId });
      }
    }
  }
}
