import { z } from 'zod';

/**
 * Connect 4 Galaxy ruleset. Grid size and the connect length are explicit so the
 * admin config can offer variants (e.g. 8x7 / connect 5) without engine changes.
 * Mirrored in Dart (games/connect4_galaxy/lib/src/model/rules.dart).
 */
export const Connect4RulesSchema = z.object({
  columns: z.number().int().min(4).max(12).default(7),
  rows: z.number().int().min(4).max(12).default(6),
  /** Discs in a line needed to win. */
  connect: z.number().int().min(3).max(6).default(4),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(30),
  /** How many consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
  /** Who drops first: random (via rng) or always seat 0. */
  firstMove: z.enum(['random', 'seat0']).default('random'),
});

export type Connect4Rules = z.infer<typeof Connect4RulesSchema>;

export const DEFAULT_CONNECT4_RULES: Connect4Rules = Connect4RulesSchema.parse({});

export function resolveConnect4Rules(input: Record<string, unknown> = {}): Connect4Rules {
  const rules = Connect4RulesSchema.parse(input);
  if (rules.connect > Math.max(rules.columns, rules.rows)) {
    throw new Error('connect length exceeds grid size');
  }
  return rules;
}
