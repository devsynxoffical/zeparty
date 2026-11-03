import { PoolEliteEngine } from './engine.js';
export { PoolEliteEngine, rackBalls, groupOf, otherGroup } from './engine.js';
export { PoolRulesSchema, DEFAULT_POOL_RULES, resolvePoolRules } from './rules.js';
export { simulateShot, placementBlocked, nearestFreeSpot } from './physics.js';
export * from './table.js';
export const engine = new PoolEliteEngine();
