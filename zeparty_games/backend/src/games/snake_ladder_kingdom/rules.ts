import { z } from 'zod';

/**
 * Snake & Ladder Kingdom ruleset. Every switch is explicit; the Dart mirror lives in
 * games/snake_ladder_kingdom/lib/src/model/rules.dart and only drives presentation.
 */
export const SnakeLadderRulesSchema = z.object({
  /** Number of squares. The board is always square (8x8 or 10x10). */
  boardSize: z.union([z.literal(64), z.literal(100)]).default(100),
  /** Which fixed, hand-designed ladder/snake layout to use for the chosen board size. */
  layout: z.enum(['kingdom_a', 'kingdom_b']).default('kingdom_a'),
  /**
   * true: the final square must be hit exactly; an overshoot bounces back by the excess
   * (classic rule). false: any roll that reaches or passes the last square finishes.
   */
  exactFinish: z.boolean().default(true),
  /** Rolling a six grants another roll (never after finishing). */
  extraTurnOnSix: z.boolean().default(true),
  /**
   * 0: tokens start on square 0 (off board) and enter with any roll.
   * 1..6: the token stays off board until exactly this value is rolled.
   */
  unlockRoll: z.number().int().min(0).max(6).default(0),
  /** End the match as soon as one player finishes (true) or play out placements (false). */
  endOnFirstWinner: z.boolean().default(false),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(30),
  /** Consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
});

export type SnakeLadderRules = z.infer<typeof SnakeLadderRulesSchema>;

export const DEFAULT_SNAKE_LADDER_RULES: SnakeLadderRules = SnakeLadderRulesSchema.parse({});

export function resolveSnakeLadderRules(input: Record<string, unknown> = {}): SnakeLadderRules {
  return SnakeLadderRulesSchema.parse({ ...input });
}
