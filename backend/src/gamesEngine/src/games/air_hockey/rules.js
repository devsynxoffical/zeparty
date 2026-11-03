import { z } from 'zod';
/**
 * Neon Air Hockey ruleset. Physics constants live in physics.ts (they are part of the
 * netcode contract with the client); only match-format switches are configurable here.
 */
export const AirHockeyRulesSchema = z.object({
    /** First player to reach this many goals wins. */
    goalsToWin: z.number().int().min(1).max(21).default(7),
    /** Match length in seconds. 0 disables the clock (first to goalsToWin only). */
    matchSeconds: z.number().int().min(0).max(900).default(180),
    /** When the clock expires on a tie, the next goal wins. False means a draw. */
    suddenDeath: z.boolean().default(true),
    /** Pause between a goal and the next faceoff, in milliseconds. */
    faceoffPauseMs: z.number().int().min(0).max(10_000).default(1500),
});
export const DEFAULT_AIR_HOCKEY_RULES = AirHockeyRulesSchema.parse({});
/** Unknown keys (for example the room layer's `turnTimeoutSeconds`) are stripped. */
export function resolveAirHockeyRules(input = {}) {
    return AirHockeyRulesSchema.parse(input);
}
