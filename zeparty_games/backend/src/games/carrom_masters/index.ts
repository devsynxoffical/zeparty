import { CarromEngine } from './engine.js';

export const engine = new CarromEngine();
export { CarromEngine, otherSide } from './engine.js';
export type { CarromAction, CarromCoin, CarromSeatState, CarromState, CarromFoul, QueenStatus, Side } from './engine.js';
export { CarromRulesSchema, DEFAULT_CARROM_RULES, resolveCarromRules } from './rules.js';
export type { CarromRules } from './rules.js';
export * as layout from './layout.js';
export { simulateShot, DEFAULT_BOARD, FIXED_DT, FRAME_INTERVAL, kineticEnergy } from './physics.js';
export type { Body, BoardPhysics, Frame, FrameBody, ShotResult, PocketEvent, CollisionEvent } from './physics.js';
