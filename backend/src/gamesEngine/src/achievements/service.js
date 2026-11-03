import { getPool, hasDatabase } from '../db/pool.js';
export const ACHIEVEMENTS = [
    { achievementId: 'common.first_match', gameId: 'common', name: 'Welcome to the Party', description: 'Finish your first match in any game.', rewardCoins: 25, enabled: true },
    { achievementId: 'common.tutorial', gameId: 'common', name: 'Quick Study', description: 'Complete the beginner tutorial.', rewardCoins: 15, enabled: true },
    { achievementId: 'ludo_royale.first_win', gameId: 'ludo_royale', name: 'Crowned', description: 'Win a Ludo Royale match.', rewardCoins: 50, enabled: true },
    { achievementId: 'ludo_royale.capture_5', gameId: 'ludo_royale', name: 'Palace Guard', description: 'Capture five tokens in a single match.', rewardCoins: 30, enabled: true },
    { achievementId: 'ludo_royale.untouched', gameId: 'ludo_royale', name: 'Untouchable', description: 'Win without losing a token.', rewardCoins: 60, enabled: true },
    { achievementId: 'ludo_royale.triple_six', gameId: 'ludo_royale', name: 'Too Lucky', description: 'Roll three sixes in a row.', rewardCoins: 10, enabled: true },
];
export class MemoryAchievementStore {
    data = new Map();
    async listUser(userId) {
        return [...(this.data.get(userId)?.values() ?? [])];
    }
    async unlock(userId, achievementId) {
        let m = this.data.get(userId);
        if (!m) {
            m = new Map();
            this.data.set(userId, m);
        }
        if (m.has(achievementId))
            return false;
        m.set(achievementId, { achievementId, unlockedAt: new Date().toISOString(), claimedAt: null });
        return true;
    }
    async markClaimed(userId, achievementId) {
        const a = this.data.get(userId)?.get(achievementId);
        if (!a || a.claimedAt)
            return false;
        a.claimedAt = new Date().toISOString();
        return true;
    }
}
export class PgAchievementStore {
    async listUser(userId) {
        const res = await getPool().query(`SELECT achievement_id, unlocked_at, claimed_at FROM user_achievements WHERE user_id=$1`, [userId]);
        return res.rows.map((r) => ({ achievementId: r.achievement_id, unlockedAt: new Date(r.unlocked_at).toISOString(), claimedAt: r.claimed_at ? new Date(r.claimed_at).toISOString() : null }));
    }
    async unlock(userId, achievementId) {
        const res = await getPool().query(`INSERT INTO user_achievements (user_id, achievement_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, [userId, achievementId]);
        return res.rowCount === 1;
    }
    async markClaimed(userId, achievementId) {
        const res = await getPool().query(`UPDATE user_achievements SET claimed_at=now() WHERE user_id=$1 AND achievement_id=$2 AND claimed_at IS NULL`, [userId, achievementId]);
        return res.rowCount === 1;
    }
}
export class AchievementService {
    store;
    wallet;
    constructor(store, wallet) {
        this.store = store;
        this.wallet = wallet;
    }
    static defaultStore() {
        return hasDatabase() ? new PgAchievementStore() : new MemoryAchievementStore();
    }
    async ensureSeeded() {
        if (!hasDatabase())
            return;
        for (const a of ACHIEVEMENTS) {
            await getPool().query(`INSERT INTO achievements (achievement_id, game_id, name, description, reward_coins, enabled) VALUES ($1,$2,$3,$4,$5,$6)
         ON CONFLICT (achievement_id) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, reward_coins=EXCLUDED.reward_coins`, [a.achievementId, a.gameId, a.name, a.description, a.rewardCoins, a.enabled]);
        }
    }
    async list(userId) {
        const mine = new Map((await this.store.listUser(userId)).map((a) => [a.achievementId, a]));
        return ACHIEVEMENTS.filter((a) => a.enabled).map((a) => ({ ...a, unlockedAt: mine.get(a.achievementId)?.unlockedAt ?? null, claimedAt: mine.get(a.achievementId)?.claimedAt ?? null }));
    }
    async onMatchFinished(userId, gameId, outcome) {
        const unlocked = [];
        const tryUnlock = async (id) => {
            if (await this.store.unlock(userId, id))
                unlocked.push(id);
        };
        await tryUnlock('common.first_match');
        if (gameId === 'ludo_royale') {
            const mySeat = outcome.seat;
            if (outcome.won)
                await tryUnlock('ludo_royale.first_win');
            const captures = outcome.events.filter((e) => e.type === 'token_captured' && e.seat === mySeat).length;
            if (captures >= 5)
                await tryUnlock('ludo_royale.capture_5');
            const lost = outcome.events.filter((e) => e.type === 'token_captured' && e.payload['victimSeat'] === mySeat).length;
            if (outcome.won && lost === 0)
                await tryUnlock('ludo_royale.untouched');
            if (outcome.events.some((e) => e.type === 'three_sixes' && e.seat === mySeat))
                await tryUnlock('ludo_royale.triple_six');
        }
        return unlocked;
    }
    async claim(userId, achievementId) {
        const def = ACHIEVEMENTS.find((a) => a.achievementId === achievementId);
        if (!def)
            throw new Error('unknown_achievement');
        const mine = (await this.store.listUser(userId)).find((a) => a.achievementId === achievementId);
        if (!mine)
            throw new Error('not_unlocked');
        const newly = await this.store.markClaimed(userId, achievementId);
        if (!newly)
            throw new Error('already_claimed');
        return this.wallet.grantAchievementReward(userId, achievementId, def.rewardCoins);
    }
    async unlockTutorial(userId) {
        return this.store.unlock(userId, 'common.tutorial');
    }
}
