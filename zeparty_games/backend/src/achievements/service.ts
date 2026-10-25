import { getPool, hasDatabase } from '../db/pool.js';
import type { GameEvent } from '../games/engine.js';
import type { WalletService } from '../wallet/service.js';

export interface AchievementDef {
  achievementId: string;
  gameId: string;
  name: string;
  description: string;
  rewardCoins: number;
  enabled: boolean;
}

export interface UserAchievement {
  achievementId: string;
  unlockedAt: string;
  claimedAt: string | null;
}

export interface MatchOutcome {
  won: boolean;
  placement: number;
  seat: number;
  events: GameEvent[];
}

export const ACHIEVEMENTS: AchievementDef[] = [
  { achievementId: 'common.first_match', gameId: 'common', name: 'Welcome to the Party', description: 'Finish your first match in any game.', rewardCoins: 25, enabled: true },
  { achievementId: 'common.tutorial', gameId: 'common', name: 'Quick Study', description: 'Complete the beginner tutorial.', rewardCoins: 15, enabled: true },
  { achievementId: 'ludo_royale.first_win', gameId: 'ludo_royale', name: 'Crowned', description: 'Win a Ludo Royale match.', rewardCoins: 50, enabled: true },
  { achievementId: 'ludo_royale.capture_5', gameId: 'ludo_royale', name: 'Palace Guard', description: 'Capture five tokens in a single match.', rewardCoins: 30, enabled: true },
  { achievementId: 'ludo_royale.untouched', gameId: 'ludo_royale', name: 'Untouchable', description: 'Win without losing a token.', rewardCoins: 60, enabled: true },
  { achievementId: 'ludo_royale.triple_six', gameId: 'ludo_royale', name: 'Too Lucky', description: 'Roll three sixes in a row.', rewardCoins: 10, enabled: true },
];

export interface AchievementStore {
  listUser(userId: string): Promise<UserAchievement[]>;
  unlock(userId: string, achievementId: string): Promise<boolean>; // true when newly unlocked
  markClaimed(userId: string, achievementId: string): Promise<boolean>; // true when newly claimed
}

export class MemoryAchievementStore implements AchievementStore {
  private data = new Map<string, Map<string, UserAchievement>>();
  async listUser(userId: string) {
    return [...(this.data.get(userId)?.values() ?? [])];
  }
  async unlock(userId: string, achievementId: string) {
    let m = this.data.get(userId);
    if (!m) {
      m = new Map();
      this.data.set(userId, m);
    }
    if (m.has(achievementId)) return false;
    m.set(achievementId, { achievementId, unlockedAt: new Date().toISOString(), claimedAt: null });
    return true;
  }
  async markClaimed(userId: string, achievementId: string) {
    const a = this.data.get(userId)?.get(achievementId);
    if (!a || a.claimedAt) return false;
    a.claimedAt = new Date().toISOString();
    return true;
  }
}

export class PgAchievementStore implements AchievementStore {
  async listUser(userId: string) {
    const res = await getPool().query(`SELECT achievement_id, unlocked_at, claimed_at FROM user_achievements WHERE user_id=$1`, [userId]);
    return res.rows.map((r) => ({ achievementId: r.achievement_id, unlockedAt: new Date(r.unlocked_at).toISOString(), claimedAt: r.claimed_at ? new Date(r.claimed_at).toISOString() : null }));
  }
  async unlock(userId: string, achievementId: string) {
    const res = await getPool().query(`INSERT INTO user_achievements (user_id, achievement_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [userId, achievementId]);
    return res.rowCount === 1;
  }
  async markClaimed(userId: string, achievementId: string) {
    const res = await getPool().query(`UPDATE user_achievements SET claimed_at=now() WHERE user_id=$1 AND achievement_id=$2 AND claimed_at IS NULL`, [userId, achievementId]);
    return res.rowCount === 1;
  }
}

export class AchievementService {
  constructor(
    private readonly store: AchievementStore,
    private readonly wallet: WalletService,
  ) {}

  static defaultStore(): AchievementStore {
    return hasDatabase() ? new PgAchievementStore() : new MemoryAchievementStore();
  }

  async ensureSeeded(): Promise<void> {
    if (!hasDatabase()) return;
    for (const a of ACHIEVEMENTS) {
      await getPool().query(
        `INSERT INTO achievements (achievement_id, game_id, name, description, reward_coins, enabled) VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (achievement_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, reward_coins=EXCLUDED.reward_coins`,
        [a.achievementId, a.gameId, a.name, a.description, a.rewardCoins, a.enabled],
      );
    }
  }

  async list(userId: string): Promise<Array<AchievementDef & { unlockedAt: string | null; claimedAt: string | null }>> {
    const mine = new Map((await this.store.listUser(userId)).map((a) => [a.achievementId, a]));
    return ACHIEVEMENTS.filter((a) => a.enabled).map((a) => ({ ...a, unlockedAt: mine.get(a.achievementId)?.unlockedAt ?? null, claimedAt: mine.get(a.achievementId)?.claimedAt ?? null }));
  }

  async onMatchFinished(userId: string, gameId: string, outcome: MatchOutcome): Promise<string[]> {
    const unlocked: string[] = [];
    const tryUnlock = async (id: string) => {
      if (await this.store.unlock(userId, id)) unlocked.push(id);
    };
    await tryUnlock('common.first_match');
    if (gameId === 'ludo_royale') {
      const mySeat = outcome.seat;
      if (outcome.won) await tryUnlock('ludo_royale.first_win');
      const captures = outcome.events.filter((e) => e.type === 'token_captured' && e.seat === mySeat).length;
      if (captures >= 5) await tryUnlock('ludo_royale.capture_5');
      const lost = outcome.events.filter((e) => e.type === 'token_captured' && e.payload['victimSeat'] === mySeat).length;
      if (outcome.won && lost === 0) await tryUnlock('ludo_royale.untouched');
      if (outcome.events.some((e) => e.type === 'three_sixes' && e.seat === mySeat)) await tryUnlock('ludo_royale.triple_six');
    }
    return unlocked;
  }

  async claim(userId: string, achievementId: string) {
    const def = ACHIEVEMENTS.find((a) => a.achievementId === achievementId);
    if (!def) throw new Error('unknown_achievement');
    const mine = (await this.store.listUser(userId)).find((a) => a.achievementId === achievementId);
    if (!mine) throw new Error('not_unlocked');
    const newly = await this.store.markClaimed(userId, achievementId);
    if (!newly) throw new Error('already_claimed');
    return this.wallet.grantAchievementReward(userId, achievementId, def.rewardCoins);
  }

  async unlockTutorial(userId: string): Promise<boolean> {
    return this.store.unlock(userId, 'common.tutorial');
  }
}
