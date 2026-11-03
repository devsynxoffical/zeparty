/**
 * FIFO matchmaking per (game, tableSize) with fast relaxation (3 seconds) and cross-bucket
 * matching so 2+ players searching for the same game always match even if they selected
 * different table sizes (e.g. 2-player vs 4-player default).
 */
export class MatchmakingQueue {
  rooms;
  gameConfig;
  relaxAfterMs;
  now;
  tickets = new Map();
  byUser = new Map();
  sweeper = null;

  constructor(rooms, gameConfig, relaxAfterMs = 3_000, now = () => Date.now()) {
    this.rooms = rooms;
    this.gameConfig = gameConfig;
    this.relaxAfterMs = relaxAfterMs;
    this.now = now;
  }

  start(intervalMs = 1000) {
    if (this.sweeper) return;
    this.sweeper = setInterval(() => void this.sweep(), intervalMs);
  }

  stop() {
    if (this.sweeper) clearInterval(this.sweeper);
    this.sweeper = null;
  }

  async enqueue(identity, gameId, tableSize) {
    const cfg = await this.gameConfig.get(gameId);
    if (!cfg.enabled) throw new Error('game_disabled');
    const size = Math.min(Math.max(tableSize ?? cfg.minPlayers, cfg.minPlayers), cfg.maxPlayers);
    this.dequeue(identity.userId);
    const key = `${gameId}:${size}`;
    const list = this.tickets.get(key) ?? [];
    list.push({ identity, gameId, tableSize: size, enqueuedAt: this.now() });
    this.tickets.set(key, list);
    this.byUser.set(identity.userId, key);
    await this.sweep();
    return {
      queued: this.byUser.has(identity.userId),
      position: list.findIndex((t) => t.identity.userId === identity.userId) + 1,
    };
  }

  dequeue(userId) {
    const key = this.byUser.get(userId);
    if (!key) return false;
    const list = this.tickets.get(key) ?? [];
    this.tickets.set(
      key,
      list.filter((t) => t.identity.userId !== userId)
    );
    this.byUser.delete(userId);
    return true;
  }

  status(userId) {
    const key = this.byUser.get(userId);
    if (!key) return { queued: false, position: 0, waitedMs: 0 };
    const list = this.tickets.get(key) ?? [];
    const idx = list.findIndex((t) => t.identity.userId === userId);
    return {
      queued: idx >= 0,
      position: idx + 1,
      waitedMs: idx >= 0 ? this.now() - list[idx].enqueuedAt : 0,
    };
  }

  async launchMatchedGroup(gameId, group, maxPlayers) {
    const host = group[0];
    const room = await this.rooms.createRoom(host.identity, gameId, {
      isPrivate: true,
      maxPlayers,
    });
    for (const t of group.slice(1)) {
      this.rooms.joinRoom(t.identity, room.roomId, room.inviteCode);
    }
    // Wait 350ms so Flutter clients finish pushing RoomScreen and subscribing to gameStateStream
    // before beginMatch emits game.state, with a 1000ms resync safety net.
    setTimeout(() => {
      void this.rooms.beginMatch(room).catch(() => {});
    }, 350);
    setTimeout(() => {
      for (const t of group) {
        try {
          this.rooms.resync(t.identity.userId, 0);
        } catch {}
      }
    }, 1000);
  }

  async sweep() {
    // 1. Same-bucket matching
    for (const [key, list] of this.tickets) {
      if (list.length === 0) continue;
      const first = list[0];
      const cfg = await this.gameConfig.get(first.gameId);
      const full = list.length >= first.tableSize;
      const relaxed = list.length >= cfg.minPlayers && this.now() - first.enqueuedAt >= this.relaxAfterMs;
      if (!full && !relaxed) continue;
      const group = list.splice(0, Math.min(first.tableSize, list.length));
      this.tickets.set(key, list);
      for (const t of group) this.byUser.delete(t.identity.userId);
      await this.launchMatchedGroup(first.gameId, group, Math.max(first.tableSize, group.length));
    }

    // 2. Cross-bucket matching for the same gameId (e.g. one player chose 2-player, another chose 4-player)
    const byGame = new Map();
    for (const [, list] of this.tickets) {
      for (const t of list) {
        const arr = byGame.get(t.gameId) ?? [];
        arr.push(t);
        byGame.set(t.gameId, arr);
      }
    }

    for (const [gameId, allTickets] of byGame) {
      if (allTickets.length === 0) continue;
      allTickets.sort((a, b) => a.enqueuedAt - b.enqueuedAt);
      const cfg = await this.gameConfig.get(gameId);
      if (allTickets.length >= cfg.minPlayers && this.now() - allTickets[0].enqueuedAt >= this.relaxAfterMs) {
        const group = allTickets.slice(0, cfg.maxPlayers);
        for (const t of group) this.dequeue(t.identity.userId);
        await this.launchMatchedGroup(gameId, group, Math.max(cfg.minPlayers, group.length));
      }
    }
  }
}
