import { z } from 'zod';

/**
 * Darts Arena ruleset. Every switch is explicit; the Dart client mirrors the
 * shape in games/darts_arena/lib/src/model/rules.dart.
 */
export const DartsFormatSchema = z.enum(['501', '301', 'cricket', 'around_the_clock']);
export type DartsFormat = z.infer<typeof DartsFormatSchema>;

export const DartsRulesSchema = z.object({
  /** Match format. x01 formats start at that score and count down. */
  format: DartsFormatSchema.default('501'),
  /** x01 only: the leg must be finished on a double (double bull counts). */
  doubleOut: z.boolean().default(true),
  /** x01 only: scoring only starts once the player hits a double. */
  doubleIn: z.boolean().default(false),
  /** Legs a player must win to take the match. */
  legsToWin: z.number().int().min(1).max(9).default(1),
  /** Visit timer in seconds (three darts), 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(30),
  /** Consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
  /**
   * Scatter at release quality 0.6 in board units (board radius 1.0). The applied
   * sigma is baseSigma * (1.6 - release), so a perfect release gives 0.6 * baseSigma.
   */
  baseSigma: z.number().min(0.005).max(0.5).default(0.07),
});

export type DartsRules = z.infer<typeof DartsRulesSchema>;

export const DEFAULT_DARTS_RULES: DartsRules = DartsRulesSchema.parse({});

export function resolveDartsRules(input: Record<string, unknown> = {}): DartsRules {
  return DartsRulesSchema.parse(input);
}

/** Starting score of an x01 format, or null for non-x01 formats. */
export function x01Start(format: DartsFormat): number | null {
  if (format === '501') return 501;
  if (format === '301') return 301;
  return null;
}
