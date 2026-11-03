import { ACTION_CARD_POINTS, PRISM_CARD_POINTS } from './rules.js';
export const CARD_COLORS = ['ruby', 'sapphire', 'emerald', 'gold'];
export const DECK_SIZE = 112;
/**
 * Color Clash deck composition (112 cards):
 * per colour: 1x 0, 2x 1..9, 2 Skip, 2 Flip, 2 Surge +2 (25 per colour, 100 total)
 * colourless: 4 Prism, 4 Prism Surge +4, 4 Echo.
 * Ids are stable (`c0`..`c111`) so clients can reference cards without revealing identity.
 */
export function buildDeck() {
    const cards = [];
    let n = 0;
    const push = (color, kind, value) => {
        const c = { id: `c${n++}`, color, kind };
        if (value !== undefined)
            c.value = value;
        cards.push(c);
    };
    for (const color of CARD_COLORS) {
        push(color, 'number', 0);
        for (let v = 1; v <= 9; v++) {
            push(color, 'number', v);
            push(color, 'number', v);
        }
        for (let i = 0; i < 2; i++)
            push(color, 'skip');
        for (let i = 0; i < 2; i++)
            push(color, 'flip');
        for (let i = 0; i < 2; i++)
            push(color, 'surge');
    }
    for (let i = 0; i < 4; i++)
        push('wild', 'prism');
    for (let i = 0; i < 4; i++)
        push('wild', 'prism_surge');
    for (let i = 0; i < 4; i++)
        push('wild', 'echo');
    return cards;
}
/** In-place Fisher-Yates using only the engine rng. */
export function shuffle(items, rng) {
    for (let i = items.length - 1; i > 0; i--) {
        const j = rng.int(0, i);
        const tmp = items[i];
        items[i] = items[j];
        items[j] = tmp;
    }
    return items;
}
export function isWild(card) {
    return card.kind === 'prism' || card.kind === 'prism_surge';
}
export function isActionKind(kind) {
    return kind !== 'number';
}
/** Scoring value of a card left in a loser's hand. */
export function cardPoints(card) {
    if (card.kind === 'number')
        return card.value ?? 0;
    if (card.kind === 'prism' || card.kind === 'prism_surge')
        return PRISM_CARD_POINTS;
    return ACTION_CARD_POINTS;
}
export function handPoints(hand) {
    return hand.reduce((acc, c) => acc + cardPoints(c), 0);
}
