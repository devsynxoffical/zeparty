import { ChessEngine } from './engine.js';

export { ChessEngine } from './engine.js';
export type { ChessAction, ChessState, ChessView, ChessMoveRecord, ChessEndReason, ChessOutcome } from './engine.js';
export { ChessRulesSchema, DEFAULT_CHESS_RULES, resolveChessRules } from './rules.js';
export type { ChessRules } from './rules.js';
export * as chess from './chess.js';

export const engine = new ChessEngine();
