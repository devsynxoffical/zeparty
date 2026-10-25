import { z } from 'zod';

/**
 * 8 Ball Pool Elite ruleset. Standard 8-ball with explicit switches; nothing is implied.
 */
export const PoolRulesSchema = z.object({
  /** What happens when the 8 drops on the break: instant win for the breaker, or respot it. */
  eightOnBreak: z.enum(['win', 'respot']).default('respot'),
  /** After a foul the incoming player may place the cue ball anywhere (true) or only behind the head string (false). */
  ballInHandAnywhere: z.boolean().default(true),
  /** Called shots. Not enforced by this engine version; kept explicit for the client UI. */
  callShots: z.boolean().default(false),
  /** Turn timer in seconds, 0 disables. */
  turnTimeoutSeconds: z.number().int().min(0).max(600).default(45),
  /** Consecutive timeouts before a player forfeits. */
  timeoutsToForfeit: z.number().int().min(1).max(10).default(3),
});

export type PoolRules = z.infer<typeof PoolRulesSchema>;

export const DEFAULT_POOL_RULES: PoolRules = PoolRulesSchema.parse({});

export function resolvePoolRules(input: Record<string, unknown> = {}): PoolRules {
  return PoolRulesSchema.parse({ ...input });
}
