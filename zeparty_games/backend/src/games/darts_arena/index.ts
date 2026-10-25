import { DartsEngine } from './engine.js';

export { DartsEngine, CRICKET_NUMBERS, DARTS_PER_VISIT, CLOCK_BULL, CLOCK_DONE } from './engine.js';
export type { DartsAction, DartsState, DartsSeatState, ThrownDart } from './engine.js';
export { DartsRulesSchema, DartsFormatSchema, DEFAULT_DARTS_RULES, resolveDartsRules, x01Start } from './rules.js';
export type { DartsRules, DartsFormat } from './rules.js';
export { BOARD_GEOMETRY, SEGMENTS, BULL, scoreAt, segmentIndexAt, computeLanding, sigmaFor, gaussian, pointFor } from './scoring.js';
export type { DartScore, Landing } from './scoring.js';
export { CHECKOUTS, BOGEY_NUMBERS, checkoutFor, tokenPoints } from './checkouts.js';

export const engine = new DartsEngine();
