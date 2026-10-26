import { z } from 'zod';

/**
 * Mini Golf Paradise ruleset. Mirrored in Dart (games/mini_golf_paradise/lib/src/model/rules.dart).
 * `holes` indexes into the course list in courses.ts; the default plays all five.
 */
export const MINI_GOLF_COURSE_COUNT = 5;

export const MiniGolfRulesSchema = z.object({
  /** Indices into the course list, played in this order. */
  holes: z.array(z.number().int().min(0).max(MINI_GOLF_COURSE_COUNT - 1)).min(1).max(18).default([0, 1, 2, 3, 4]),
  /** Strokes after which a player picks up and scores this many. */
  maxStrokes: z.number().int().min(2).max(20).default(8),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(45),
  /** Consecutive timeouts before a player is forfeited. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
  /** 'rotation' = fixed seat order skipping holed-out players; 'farthest' = player farthest from the cup putts next. */
  strokeOrder: z.enum(['farthest', 'rotation']).default('rotation'),
});

export type MiniGolfRules = z.infer<typeof MiniGolfRulesSchema>;

export const DEFAULT_MINI_GOLF_RULES: MiniGolfRules = MiniGolfRulesSchema.parse({});

export function resolveMiniGolfRules(input: Record<string, unknown> = {}): MiniGolfRules {
  return MiniGolfRulesSchema.parse({ ...input });
}
