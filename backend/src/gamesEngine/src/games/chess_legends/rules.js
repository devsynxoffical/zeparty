import { z } from 'zod';
/**
 * Chess Legends ruleset. Standard FIDE chess; the only configurable part is the
 * time control. Defaults are 5 + 3 (five minutes, three seconds increment).
 */
export const ChessRulesSchema = z.object({
    /** Starting clock per side in seconds. */
    initialSeconds: z.number().int().min(10).max(7200).default(300),
    /** Fischer increment added after each completed move, in seconds. */
    incrementSeconds: z.number().int().min(0).max(60).default(3),
    /** When false no clocks run and the room layer gets no turn deadline. */
    clockEnabled: z.boolean().default(true),
});
export const DEFAULT_CHESS_RULES = ChessRulesSchema.parse({});
export function resolveChessRules(input = {}) {
    return ChessRulesSchema.parse({ ...input });
}
