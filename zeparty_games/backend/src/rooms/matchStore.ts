import { getPool } from '../db/pool.js';
import type { SequencedEvent } from './types.js';

export interface MatchRecord {
  matchId: string;
  roomId: string;
  gameId: string;
  rules: Record<string, unknown>;
  status: 'active' | 'completed' | 'abandoned';
  startedAt: string;
  endedAt: string | null;
  winnerIds: string[];
  participants: Array<{ userId: string; seat: number; placement: number | null; score: number }>;
}

export interface LeaderboardRow {
  userId: string;
  wins: number;
  matches: number;
  score: number;
  rank: number;
}

export interface MatchStore {
  start(record: MatchRecord): Promise<void>;
  appendEvents(matchId: string, events: SequencedEvent[]): Promise<void>;
  finish(matchId: string, finalState: unknown, placements: Array<{ userId: string; placement: number; score: number }>, winnerIds: string[]): Promise<void>;
  get(matchId: string): Promise<MatchRecord | null>;
  history(userId: string, limit: number): Promise<MatchRecord[]>;
  leaderboard(gameId: string, period: string, limit: number): Promise<LeaderboardRow[]>;
  userRank(gameId: string, period: string, userId: string): Promise<LeaderboardRow | null>;
}

export function weeklyPeriod(d = new Date()): string {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `weekly:${date.getUTCFullYear()}-${String(week).padStart(2, '0')}`;
}

export class MemoryMatchStore implements MatchStore {
  private matches = new Map<string, MatchRecord & { finalState?: unknown; events: SequencedEvent[] }>();
  private boards = new Map<string, Map<string, { wins: number; matches: number; score: number }>>();

  async start(record: MatchRecord): Promise<void> {
    this.matches.set(record.matchId, { ...record, events: [] });
  }
  async appendEvents(matchId: string, events: SequencedEvent[]): Promise<void> {
    this.matches.get(matchId)?.events.push(...events);
  }
  async finish(matchId: string, finalState: unknown, placements: Array<{ userId: string; placement: number; score: number }>, winnerIds: string[]): Promise<void> {
    const m = this.matches.get(matchId);
    if (!m) return;
    m.status = 'completed';
    m.endedAt = new Date().toISOString();
    m.finalState = finalState;
    m.winnerIds = winnerIds;
    for (const p of placements) {
      const part = m.participants.find((x) => x.userId === p.userId);
      if (part) {
        part.placement = p.placement;
        part.score = p.score;
      }
      for (const period of ['alltime', weeklyPeriod()]) {
        const key = `${m.gameId}|${period}`;
        let b = this.boards.get(key);
        if (!b) {
          b = new Map();
          this.boards.set(key, b);
        }
        const row = b.get(p.userId) ?? { wins: 0, matches: 0, score: 0 };
        row.matches += 1;
        if (winnerIds.includes(p.userId)) row.wins += 1;
        row.score += scoreFor(p.placement, placements.length);
        b.set(p.userId, row);
      }
    }
  }
  async get(matchId: string): Promise<MatchRecord | null> {
    const m = this.matches.get(matchId);
    if (!m) return null;
    const { events: _e, finalState: _f, ...rest } = m;
    return rest;
  }
  async history(userId: string, limit: number): Promise<MatchRecord[]> {
    return [...this.matches.values()]
      .filter((m) => m.participants.some((p) => p.userId === userId))
      .sort((a, b) => (a.startedAt < b.startedAt ? 1 : -1))
      .slice(0, limit)
      .map(({ events: _e, finalState: _f, ...rest }) => rest);
  }
  async leaderboard(gameId: string, period: string, limit: number): Promise<LeaderboardRow[]> {
    const b = this.boards.get(`${gameId}|${period}`) ?? new Map();
    return [...b.entries()]
      .map(([userId, r]) => ({ userId, ...r }))
      .sort((a, b) => b.score - a.score || b.wins - a.wins)
      .slice(0, limit)
      .map((r, i) => ({ ...r, rank: i + 1 }));
  }
  async userRank(gameId: string, period: string, userId: string): Promise<LeaderboardRow | null> {
    const all = await this.leaderboard(gameId, period, 10_000);
    return all.find((r) => r.userId === userId) ?? null;
  }
}

/** Leaderboard points: first place earns the most, scaled by table size. */
export function scoreFor(placement: number, tableSize: number): number {
  return Math.max(0, (tableSize - placement + 1) * 10);
}

export class PgMatchStore implements MatchStore {
  async start(r: MatchRecord): Promise<void> {
    const client = await getPool().connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `INSERT INTO matches (match_id, room_id, game_id, ruleset, status, started_at) VALUES ($1,$2,$3,$4,'active',$5)`,
        [r.matchId, r.roomId, r.gameId, JSON.stringify(r.rules), r.startedAt],
      );
      for (const p of r.participants) {
        await client.query(`INSERT INTO match_participants (match_id, user_id, seat) VALUES ($1,$2,$3)`, [r.matchId, p.userId, p.seat]);
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
  async appendEvents(matchId: string, events: SequencedEvent[]): Promise<void> {
    if (events.length === 0) return;
    const values: unknown[] = [];
    const rows = events.map((e, i) => {
      values.push(matchId, e.seq, e.actorSeat, e.event.type, JSON.stringify({ ...e.event, at: e.at }));
      const b = i * 5;
      return `($${b + 1},$${b + 2},$${b + 3},$${b + 4},$${b + 5})`;
    });
    await getPool().query(
      `INSERT INTO match_events (match_id, seq, actor_id, event_type, payload) VALUES ${rows.join(',')} ON CONFLICT DO NOTHING`,
      values,
    );
  }
  async finish(matchId: string, finalState: unknown, placements: Array<{ userId: string; placement: number; score: number }>, winnerIds: string[]): Promise<void> {
    const client = await getPool().connect();
    try {
      await client.query('BEGIN');
      const m = await client.query(`UPDATE matches SET status='completed', ended_at=now(), final_state=$2, winner_ids=$3 WHERE match_id=$1 RETURNING game_id`, [
        matchId,
        JSON.stringify(finalState),
        winnerIds,
      ]);
      const gameId = m.rows[0]?.game_id as string;
      for (const p of placements) {
        await client.query(`UPDATE match_participants SET placement=$3, score=$4 WHERE match_id=$1 AND user_id=$2`, [matchId, p.userId, p.placement, p.score]);
        for (const period of ['alltime', weeklyPeriod()]) {
          await client.query(
            `INSERT INTO leaderboard_entries (game_id, period, user_id, wins, matches, score) VALUES ($1,$2,$3,$4,1,$5)
             ON CONFLICT (game_id, period, user_id) DO UPDATE SET wins = leaderboard_entries.wins + EXCLUDED.wins,
               matches = leaderboard_entries.matches + 1, score = leaderboard_entries.score + EXCLUDED.score, updated_at = now()`,
            [gameId, period, p.userId, winnerIds.includes(p.userId) ? 1 : 0, scoreFor(p.placement, placements.length)],
          );
        }
      }
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
  async get(matchId: string): Promise<MatchRecord | null> {
    const m = await getPool().query(`SELECT * FROM matches WHERE match_id=$1`, [matchId]);
    if (!m.rows[0]) return null;
    const parts = await getPool().query(`SELECT user_id, seat, placement, score FROM match_participants WHERE match_id=$1 ORDER BY seat`, [matchId]);
    const r = m.rows[0];
    return {
      matchId: r.match_id,
      roomId: r.room_id,
      gameId: r.game_id,
      rules: r.ruleset,
      status: r.status,
      startedAt: new Date(r.started_at).toISOString(),
      endedAt: r.ended_at ? new Date(r.ended_at).toISOString() : null,
      winnerIds: r.winner_ids,
      participants: parts.rows.map((p) => ({ userId: p.user_id, seat: p.seat, placement: p.placement, score: Number(p.score) })),
    };
  }
  async history(userId: string, limit: number): Promise<MatchRecord[]> {
    const ids = await getPool().query(
      `SELECT m.match_id FROM matches m JOIN match_participants p ON p.match_id = m.match_id WHERE p.user_id=$1 ORDER BY m.started_at DESC LIMIT $2`,
      [userId, limit],
    );
    const out: MatchRecord[] = [];
    for (const row of ids.rows) {
      const rec = await this.get(row.match_id);
      if (rec) out.push(rec);
    }
    return out;
  }
  async leaderboard(gameId: string, period: string, limit: number): Promise<LeaderboardRow[]> {
    const res = await getPool().query(
      `SELECT user_id, wins, matches, score, RANK() OVER (ORDER BY score DESC, wins DESC) AS rank
       FROM leaderboard_entries WHERE game_id=$1 AND period=$2 ORDER BY rank LIMIT $3`,
      [gameId, period, limit],
    );
    return res.rows.map((r) => ({ userId: r.user_id, wins: r.wins, matches: r.matches, score: Number(r.score), rank: Number(r.rank) }));
  }
  async userRank(gameId: string, period: string, userId: string): Promise<LeaderboardRow | null> {
    const res = await getPool().query(
      `SELECT * FROM (SELECT user_id, wins, matches, score, RANK() OVER (ORDER BY score DESC, wins DESC) AS rank
       FROM leaderboard_entries WHERE game_id=$1 AND period=$2) t WHERE user_id=$3`,
      [gameId, period, userId],
    );
    const r = res.rows[0];
    return r ? { userId: r.user_id, wins: r.wins, matches: r.matches, score: Number(r.score), rank: Number(r.rank) } : null;
  }
}
