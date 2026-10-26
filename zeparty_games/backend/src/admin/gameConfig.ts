import { z } from 'zod';
import { getPool, hasDatabase } from '../db/pool.js';
import { DEFAULT_CONNECT4_RULES } from '../games/connect4_galaxy/rules.js';
import { DEFAULT_SNAKE_LADDER_RULES } from '../games/snake_ladder_kingdom/rules.js';
import { DEFAULT_CHESS_RULES } from '../games/chess_legends/rules.js';
import { DEFAULT_COLOR_CLASH_RULES } from '../games/color_clash/rules.js';
import { DEFAULT_CARROM_RULES } from '../games/carrom_masters/rules.js';
import { DEFAULT_POOL_RULES } from '../games/pool_elite/rules.js';
import { DEFAULT_AIR_HOCKEY_RULES } from '../games/air_hockey/rules.js';
import { DEFAULT_DARTS_RULES } from '../games/darts_arena/rules.js';
import { DEFAULT_MINI_GOLF_RULES } from '../games/mini_golf_paradise/rules.js';

export const GameConfigSchema = z.object({
  enabled: z.boolean().default(true),
  featured: z.boolean().default(false),
  minPlayers: z.number().int().min(1).default(2),
  maxPlayers: z.number().int().min(1).default(4),
  turnTimeoutSeconds: z.number().int().min(5).max(600).default(30),
  disconnectGraceSeconds: z.number().int().min(5).max(600).default(60),
  cosmeticsEnabled: z.boolean().default(true),
  rewards: z
    .object({
      participationCoins: z.number().int().min(0).default(10),
      winCoins: z.number().int().min(0).default(40),
    })
    .default({}),
  rules: z.record(z.unknown()).default({}),
  events: z.array(z.object({ id: z.string(), name: z.string(), startsAt: z.string(), endsAt: z.string() })).default([]),
  graphicsPreset: z.enum(['low', 'medium', 'high', 'auto']).default('auto'),
});
export type GameConfig = z.infer<typeof GameConfigSchema>;
export const GameConfigPatchSchema = GameConfigSchema.partial().extend({ rewards: z.object({ participationCoins: z.number().int().min(0).optional(), winCoins: z.number().int().min(0).optional() }).optional() });
export type GameConfigPatch = z.infer<typeof GameConfigPatchSchema>;

export const DEFAULT_GAME_CONFIGS: Record<string, Partial<GameConfig>> = {
  common: { minPlayers: 1, maxPlayers: 1, rewards: { participationCoins: 0, winCoins: 0 } },
  ludo_royale: {
    featured: true,
    minPlayers: 2,
    maxPlayers: 4,
    turnTimeoutSeconds: 30,
    rules: {
      variant: 'classic',
      unlockRoll: 6,
      extraTurnOnSix: true,
      extraTurnOnCapture: true,
      extraTurnOnHome: true,
      threeSixesForfeit: true,
      safeSquares: 'stars_and_starts',
      exactHomeEntry: true,
      stackingAllowed: false,
      captureOnSafe: false,
      maxTokens: 4,
    },
  },
  connect4_galaxy: { featured: true, minPlayers: 2, maxPlayers: 2, rewards: { participationCoins: 5, winCoins: 20 }, rules: { ...DEFAULT_CONNECT4_RULES } },
  snake_ladder_kingdom: { minPlayers: 2, maxPlayers: 4, rules: { ...DEFAULT_SNAKE_LADDER_RULES } },
  chess_legends: { featured: true, minPlayers: 2, maxPlayers: 2, turnTimeoutSeconds: 300, rewards: { participationCoins: 10, winCoins: 50 }, rules: { ...DEFAULT_CHESS_RULES } },
  color_clash: { minPlayers: 2, maxPlayers: 6, turnTimeoutSeconds: 20, rules: { ...DEFAULT_COLOR_CLASH_RULES } },
  carrom_masters: { minPlayers: 2, maxPlayers: 4, turnTimeoutSeconds: 45, rules: { ...DEFAULT_CARROM_RULES } },
  pool_elite: { featured: true, minPlayers: 2, maxPlayers: 2, turnTimeoutSeconds: 45, rules: { ...DEFAULT_POOL_RULES } },
  air_hockey: { minPlayers: 2, maxPlayers: 2, turnTimeoutSeconds: 600, rules: { ...DEFAULT_AIR_HOCKEY_RULES } },
  darts_arena: { minPlayers: 2, maxPlayers: 4, turnTimeoutSeconds: 30, rules: { ...DEFAULT_DARTS_RULES } },
  mini_golf_paradise: { minPlayers: 2, maxPlayers: 4, turnTimeoutSeconds: 45, rules: { ...DEFAULT_MINI_GOLF_RULES } },
};

export class GameConfigStore {
  private cache = new Map<string, GameConfig>();

  constructor(private readonly persistent = hasDatabase()) {}

  async get(gameId: string): Promise<GameConfig> {
    const cached = this.cache.get(gameId);
    if (cached) return cached;
    let stored: unknown = undefined;
    if (this.persistent) {
      const res = await getPool().query(`SELECT config FROM game_config WHERE game_id = $1`, [gameId]);
      stored = res.rows[0]?.config;
    }
    const merged = GameConfigSchema.parse({ ...(DEFAULT_GAME_CONFIGS[gameId] ?? {}), ...((stored as object) ?? {}) });
    this.cache.set(gameId, merged);
    return merged;
  }

  async set(gameId: string, patch: GameConfigPatch): Promise<GameConfig> {
    const current = await this.get(gameId);
    const next = GameConfigSchema.parse({ ...current, ...patch, rewards: { ...current.rewards, ...(patch.rewards ?? {}) }, rules: { ...current.rules, ...(patch.rules ?? {}) } });
    if (this.persistent) {
      await getPool().query(
        `INSERT INTO game_config (game_id, config) VALUES ($1, $2)
         ON CONFLICT (game_id) DO UPDATE SET config = EXCLUDED.config, updated_at = now()`,
        [gameId, JSON.stringify(next)],
      );
    }
    this.cache.set(gameId, next);
    return next;
  }

  async all(gameIds: string[]): Promise<Record<string, GameConfig>> {
    const out: Record<string, GameConfig> = {};
    for (const id of gameIds) out[id] = await this.get(id);
    return out;
  }

  invalidate(): void {
    this.cache.clear();
  }
}
