import { ColorClashEngine } from './engine.js';

export { ColorClashEngine } from './engine.js';
export type { ColorClashAction, ColorClashState, ColorClashView, ColorClashSeatState } from './engine.js';
export { ColorClashRulesSchema, DEFAULT_COLOR_CLASH_RULES, resolveColorClashRules } from './rules.js';
export type { ColorClashRules } from './rules.js';
export { buildDeck, cardPoints, handPoints, CARD_COLORS, DECK_SIZE } from './deck.js';
export type { Card, CardColor, CardKind } from './deck.js';

export const engine = new ColorClashEngine();
