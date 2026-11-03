import { Connect4Engine } from './engine.js';
export { Connect4Engine, EMPTY, findWinningLine, findAnyWin, landingRow, legalColumnsOf, emptyGrid } from './engine.js';
export { Connect4RulesSchema, DEFAULT_CONNECT4_RULES, resolveConnect4Rules } from './rules.js';
export const engine = new Connect4Engine();
