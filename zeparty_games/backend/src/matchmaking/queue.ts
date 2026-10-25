import type { ZePartyIdentity } from '../auth/types.js';
import type { GameConfigStore } from '../admin/gameConfig.js';
import type { RoomManager } from '../rooms/roomManager.js';

interface Ticket {
  identity: ZePartyIdentity;
  gameId: string;
  /** Requested table size, defaults to the game's max. */
  tableSize: number;
  enqueuedAt: number;
}

/**
 * Simple FIFO matchmaking per (game, tableSize). When enough tickets are queued a room is
 * created and the match starts immediately. After `relaxAfterMs` a partially filled table
 * starts as long as the game minimum is met, so nobody waits forever at off-peak hours.
 */
export class MatchmakingQueue {
  private tickets = new Map<string, Ticket[]>();
  private byUser = new Map<string, string>();
  private sweeper: NodeJS.Timeout | null = null;

  constructor(
    private readonly rooms: RoomManager,
    private readonly gameConfig: GameConfigStore,
    private readonly relaxAfterMs = 20_000,
    private readonly now: () => number = () => Date.now(),
  ) {}

  start(intervalMs = 2000): void {
    if (this.sweeper) return;
    this.sweeper = setInterval(() => void this.sweep(), intervalMs);
  }
  stop(): void {
    if (this.sweeper) clearInterval(this.sweeper);
    this.sweeper = null;
  }

  async enqueue(identity: ZePartyIdentity, gameId: string, tableSize?: number): Promise<{ queued: boolean; position: number }> {
    const cfg = await this.gameConfig.get(gameId);
    if (!cfg.enabled) throw new Error('game_disabled');
    const size = Math.min(Math.max(tableSize ?? cfg.maxPlayers, cfg.minPlayers), cfg.maxPlayers);
    this.dequeue(identity.userId);
    const key = `${gameId}:${size}`;
    const list = this.tickets.get(key) ?? [];
    list.push({ identity, gameId, tableSize: size, enqueuedAt: this.now() });
    this.tickets.set(key, list);
    this.byUser.set(identity.userId, key);
    await this.sweep();
    return { queued: this.byUser.has(identity.userId), position: list.findIndex((t) => t.identity.userId === identity.userId) + 1 };
  }

  dequeue(userId: string): boolean {
    const key = this.byUser.get(userId);
    if (!key) return false;
    const list = this.tickets.get(key) ?? [];
    this.tickets.set(key, list.filter((t) => t.identity.userId !== userId));
    this.byUser.delete(userId);
    return true;
  }

  status(userId: string): { queued: boolean; position: number; waitedMs: number } {
    const key = this.byUser.get(userId);
    if (!key) return { queued: false, position: 0, waitedMs: 0 };
    const list = this.tickets.get(key) ?? [];
    const idx = list.findIndex((t) => t.identity.userId === userId);
    return { queued: idx >= 0, position: idx + 1, waitedMs: idx >= 0 ? this.now() - list[idx]!.enqueuedAt : 0 };
  }

  async sweep(): Promise<void> {
    for (const [key, list] of this.tickets) {
      if (list.length === 0) continue;
      const first = list[0]!;
      const cfg = await this.gameConfig.get(first.gameId);
      const full = list.length >= first.tableSize;
      const relaxed = list.length >= cfg.minPlayers && this.now() - first.enqueuedAt >= this.relaxAfterMs;
      if (!full && !relaxed) continue;
      const group = list.splice(0, Math.min(first.tableSize, list.length));
      this.tickets.set(key, list);
      for (const t of group) this.byUser.delete(t.identity.userId);
      const host = group[0]!;
      const room = await this.rooms.createRoom(host.identity, first.gameId, { isPrivate: true, maxPlayers: first.tableSize });
      for (const t of group.slice(1)) this.rooms.joinRoom(t.identity, room.roomId, room.inviteCode);
      await this.rooms.beginMatch(room);
    }
  }
}
