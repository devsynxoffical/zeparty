import { z } from 'zod';

/**
 * Carrom Masters ruleset. Every switch is explicit; the admin config in
 * backend/src/admin/gameConfig.ts merges over these defaults.
 */
export const CarromRulesSchema = z.object({
  /** Coins per side (white and black each). Standard carrom uses 9. */
  coinsPerSide: z.number().int().min(1).max(9).default(9),
  /**
   * When true the queen must be covered: after pocketing it the shooter has to
   * pocket one of their own coins in the same strike or the next strike of the
   * same turn, otherwise the queen returns to the centre.
   */
  queenRequired: z.boolean().default(true),
  /**
   * Pocketing the striker returns one of the shooter's pocketed coins to the
   * centre. When the shooter has none, a due is recorded and paid later.
   */
  penaltyOnStrikerPocket: z.boolean().default(true),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(45),
  /** Consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
  /** Boards a side must win to take the match. 1 = single board. */
  pointsToWin: z.number().int().min(1).max(9).default(1),
});

export type CarromRules = z.infer<typeof CarromRulesSchema>;

export const DEFAULT_CARROM_RULES: CarromRules = CarromRulesSchema.parse({});

export function resolveCarromRules(input: Record<string, unknown> = {}): CarromRules {
  return CarromRulesSchema.parse({ ...input });
}
