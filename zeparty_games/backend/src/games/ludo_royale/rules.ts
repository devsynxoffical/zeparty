import { z } from 'zod';

/**
 * Ludo Royale ruleset. Every regional variation is an explicit switch here; nothing is
 * implied. The same schema is mirrored in Dart (games/ludo_royale/lib/src/rules.dart) and
 * both are checked against tests/fixtures/ludo_rules_vectors.json.
 */
export const LudoRulesSchema = z.object({
  /** Named preset, informational. Explicit fields below always win. */
  variant: z.enum(['classic', 'quick', 'tournament']).default('classic'),
  /** Roll needed to move a token out of the base. */
  unlockRoll: z.number().int().min(1).max(6).default(6),
  /** Number of tokens per player (1 to 4). */
  maxTokens: z.number().int().min(1).max(4).default(4),
  /** Tokens that start already on the start square (quick variant). */
  tokensStartingOut: z.number().int().min(0).max(4).default(0),
  extraTurnOnSix: z.boolean().default(true),
  extraTurnOnCapture: z.boolean().default(true),
  extraTurnOnHome: z.boolean().default(true),
  /** Three consecutive sixes forfeit the turn. */
  threeSixesForfeit: z.boolean().default(true),
  /** Which squares are safe from capture. */
  safeSquares: z.enum(['none', 'starts', 'stars_and_starts']).default('stars_and_starts'),
  /** Must a token roll the exact number to reach home? */
  exactHomeEntry: z.boolean().default(true),
  /** Two own tokens on a square form a block that cannot be passed or captured. */
  stackingAllowed: z.boolean().default(false),
  /** Captures allowed on safe squares (normally false). */
  captureOnSafe: z.boolean().default(false),
  /** End the match as soon as one player finishes (true) or play out placements (false). */
  endOnFirstWinner: z.boolean().default(false),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(30),
  /** How many consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
});

export type LudoRules = z.infer<typeof LudoRulesSchema>;

export const LUDO_PRESETS: Record<LudoRules['variant'], Partial<LudoRules>> = {
  classic: {},
  quick: { tokensStartingOut: 1, maxTokens: 2, endOnFirstWinner: true, extraTurnOnHome: false },
  tournament: { threeSixesForfeit: true, exactHomeEntry: true, stackingAllowed: true, captureOnSafe: false, endOnFirstWinner: false },
};

export function resolveLudoRules(input: Record<string, unknown> = {}): LudoRules {
  const variant = (input['variant'] as LudoRules['variant']) ?? 'classic';
  return LudoRulesSchema.parse({ ...LUDO_PRESETS[variant], ...input, variant });
}
