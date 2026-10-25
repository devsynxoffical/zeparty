import { AirHockeyEngine } from './engine.js';

export { AirHockeyEngine } from './engine.js';
export type { AirHockeyAction, AirHockeyState, AirHockeySeatState, PaddleState, AirHockeyPhase, FinishReason } from './engine.js';
export { AirHockeyRulesSchema, DEFAULT_AIR_HOCKEY_RULES, resolveAirHockeyRules } from './rules.js';
export type { AirHockeyRules } from './rules.js';
export * from './physics.js';

export const engine = new AirHockeyEngine();
