import { z } from 'zod';

/**
 * Color Clash rules v1. An original ZeParty colour-and-number matching card game.
 * Every switch is explicit; see docs/games/color_clash.md for the full ruleset.
 */
export const ColorClashRulesSchema = z.object({
  /** Cards dealt to each player at the start of every round. */
  startingHand: z.number().int().min(3).max(12).default(7),
  /** Match ends as soon as a player reaches this many points (after a round). */
  targetScore: z.number().int().min(1).max(5000).default(200),
  /** Maximum number of rounds; 1 means a single round decides the match. */
  maxRounds: z.number().int().min(1).max(20).default(1),
  /**
   * When true a player hit by Surge +2 / Prism Surge +4 may answer with a card of the same
   * kind, passing the accumulated penalty on. When false the penalty applies immediately.
   */
  stackSurge: z.boolean().default(false),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(20),
  /** Consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
});

export type ColorClashRules = z.infer<typeof ColorClashRulesSchema>;

export const DEFAULT_COLOR_CLASH_RULES: ColorClashRules = ColorClashRulesSchema.parse({});

export function resolveColorClashRules(input: Record<string, unknown> = {}): ColorClashRules {
  return ColorClashRulesSchema.parse({ ...input });
}

/** Points an opponent's card is worth to the round winner. */
export const ACTION_CARD_POINTS = 20;
export const PRISM_CARD_POINTS = 50;
