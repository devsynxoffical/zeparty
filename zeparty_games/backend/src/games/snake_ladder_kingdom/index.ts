import { SnakeLadderEngine } from './engine.js';

export const engine = new SnakeLadderEngine();
export { SnakeLadderEngine } from './engine.js';
export type { SnakeLadderAction, SnakeLadderState, SnakeLadderSeatState } from './engine.js';
export { SnakeLadderRulesSchema, DEFAULT_SNAKE_LADDER_RULES, resolveSnakeLadderRules } from './rules.js';
export type { SnakeLadderRules } from './rules.js';
export { LAYOUTS, getLayout, cellForSquare, columnsFor, validateLayout } from './layouts.js';
export type { BoardLayout, Link, LayoutId, BoardSize } from './layouts.js';
