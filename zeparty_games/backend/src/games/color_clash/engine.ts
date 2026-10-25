import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { CARD_COLORS, buildDeck, handPoints, shuffle, type Card, type CardColor } from './deck.js';
import { resolveColorClashRules, type ColorClashRules } from './rules.js';

export type ColorClashAction =
  | { type: 'play'; cardId: string; color?: CardColor }
  | { type: 'draw' }
  | { type: 'pass' }
  | { type: 'declare' }
  | { type: 'catch'; target: number };

export interface ColorClashSeatState {
  seat: number;
  userId: string;
  displayName: string;
  hand: Card[];
  score: number;
  /** Player announced their final card (hand size 1). Reset whenever the hand grows. */
  declared: boolean;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export type ColorClashPhase = 'play' | 'drawn' | 'finished';

export interface ColorClashState {
  rules: ColorClashRules;
  seats: ColorClashSeatState[];
  round: number;
  phase: ColorClashPhase;
  turnSeat: number;
  direction: 1 | -1;
  drawPile: Card[];
  /** Bottom first, top last. */
  discardPile: Card[];
  currentColor: CardColor;
  /** Number the next player must match while an Echo is active, null otherwise. */
  echoNumber: number | null;
  /** Accumulated Surge penalty awaiting the current seat (stackSurge only). */
  pendingDraw: number;
  /** Card id the current seat just drew and may play or pass on (phase 'drawn'). */
  drawnCardId: string | null;
  /** Seat sitting at one undeclared card whom opponents may catch, null when closed. */
  catchable: number | null;
  version: number;
  turnStartedAt: number;
  turnDeadline: number | null;
  /** Final placement order (seat ids) once finished. */
  placements: number[];
  /** Seats in the order they forfeited (earliest first); they rank last, latest leaver highest. */
  forfeitOrder: number[];
  lastRound: { winnerSeat: number; points: number } | null;
}

/** Projection sent to one viewer; other hands and pile contents are hidden. */
export interface ColorClashView {
  rules: ColorClashRules;
  round: number;
  phase: ColorClashPhase;
  turnSeat: number;
  direction: 1 | -1;
  drawCount: number;
  discardCount: number;
  topCard: Card | null;
  currentColor: CardColor;
  echoNumber: number | null;
  pendingDraw: number;
  catchable: number | null;
  version: number;
  turnDeadline: number | null;
  placements: number[];
  lastRound: { winnerSeat: number; points: number } | null;
  seats: Array<{
    seat: number;
    userId: string;
    displayName: string;
    handCount: number;
    score: number;
    declared: boolean;
    consecutiveTimeouts: number;
    forfeited: boolean;
    connected: boolean;
  }>;
  viewerSeat: number | null;
  myHand: Card[] | null;
  /** Card ids the viewer may play right now (empty when it is not their turn). */
  playable: string[];
  /** The card the viewer just drew (phase 'drawn'), only for the drawing seat. */
  drawnCardId: string | null;
  canDeclare: boolean;
  canDraw: boolean;
  canPass: boolean;
  /** Seats the viewer may catch right now. */
  catchTargets: number[];
}

const NOW = () => Date.now();

export class ColorClashEngine implements GameEngine<ColorClashState, ColorClashAction> {
  readonly gameId = 'color_clash';

  constructor(private readonly now: () => number = NOW) {}

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, rng: Rng): ColorClashState {
    if (players.length < 2 || players.length > 6) throw new Error('color clash requires 2 to 6 players');
    const rules = resolveColorClashRules(rulesInput);
    const seats: ColorClashSeatState[] = players.map((p) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      hand: [],
      score: 0,
      declared: false,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const t = this.now();
    const state: ColorClashState = {
      rules,
      seats,
      round: 0,
      phase: 'play',
      turnSeat: seats[0]!.seat,
      direction: 1,
      drawPile: [],
      discardPile: [],
      currentColor: 'ruby',
      echoNumber: null,
      pendingDraw: 0,
      drawnCardId: null,
      catchable: null,
      version: 0,
      turnStartedAt: t,
      turnDeadline: null,
      placements: [],
      forfeitOrder: [],
      lastRound: null,
    };
    this.startRound(state, seats[0]!.seat, rng, []);
    return state;
  }

  private startRound(state: ColorClashState, starter: number, rng: Rng, events: GameEvent[]): void {
    state.round += 1;
    const deck = shuffle(buildDeck(), rng);
    for (const s of state.seats) {
      s.hand = [];
      s.declared = false;
    }
    const active = this.activeSeats(state);
    for (let i = 0; i < state.rules.startingHand; i++) {
      for (const s of active) s.hand.push(deck.pop()!);
    }
    // The first discard is always a number card so the round opens without an effect.
    let starterIdx = deck.length - 1;
    while (starterIdx >= 0 && deck[starterIdx]!.kind !== 'number') starterIdx--;
    const first = deck.splice(starterIdx, 1)[0]!;
    state.drawPile = deck;
    state.discardPile = [first];
    state.currentColor = first.color as CardColor;
    state.echoNumber = null;
    state.pendingDraw = 0;
    state.drawnCardId = null;
    state.catchable = null;
    state.direction = 1;
    state.phase = 'play';
    state.turnSeat = this.seatState(state, starter).forfeited ? this.nextActiveSeat(state, starter, 1) : starter;
    this.resetTurnClock(state);
    events.push({ type: 'round_started', payload: { round: state.round, starter: state.turnSeat, topCard: first } });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  currentSeat(state: ColorClashState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: ColorClashState, seat: number): ColorClashSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  private activeSeats(state: ColorClashState): ColorClashSeatState[] {
    return state.seats.filter((s) => !s.forfeited);
  }

  private topCard(state: ColorClashState): Card | null {
    return state.discardPile[state.discardPile.length - 1] ?? null;
  }

  /** Walk `steps` active seats from `from` in the current direction. */
  private nextActiveSeat(state: ColorClashState, from: number, steps: number): number {
    const order = state.seats.map((s) => s.seat);
    let idx = order.indexOf(from);
    let remaining = steps;
    for (let guard = 0; guard < order.length * (steps + 1) && remaining > 0; guard++) {
      idx = (idx + state.direction + order.length) % order.length;
      if (!this.seatState(state, order[idx]!).forfeited) remaining--;
    }
    return order[idx]!;
  }

  private resetTurnClock(state: ColorClashState): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  private holdsCurrentColor(state: ColorClashState, hand: Card[]): boolean {
    return hand.some((c) => c.color === state.currentColor);
  }

  /** Pure legality of one card for `hand` against the current table (ignores phase/turn). */
  cardPlayable(state: ColorClashState, hand: Card[], card: Card): boolean {
    const top = this.topCard(state);
    if (!top) return false;
    if (state.pendingDraw > 0) {
      // Only stacking the same kind of surge is allowed.
      if (card.kind !== top.kind) return false;
      if (card.kind === 'prism_surge') return !this.holdsCurrentColor(state, hand);
      return card.kind === 'surge';
    }
    if (state.echoNumber !== null) {
      return card.kind === 'number' && card.value === state.echoNumber;
    }
    switch (card.kind) {
      case 'prism':
      case 'echo':
        return true;
      case 'prism_surge':
        return !this.holdsCurrentColor(state, hand);
      case 'number':
        return card.color === state.currentColor || (top.kind === 'number' && top.value === card.value);
      default:
        return card.color === state.currentColor || top.kind === card.kind;
    }
  }

  playableCardIds(state: ColorClashState, seat: number): string[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    const me = this.seatState(state, seat);
    if (me.forfeited) return [];
    if (state.phase === 'drawn') {
      const drawn = me.hand.find((c) => c.id === state.drawnCardId);
      return drawn && this.cardPlayable(state, me.hand, drawn) ? [drawn.id] : [];
    }
    return me.hand.filter((c) => this.cardPlayable(state, me.hand, c)).map((c) => c.id);
  }

  private catchTargetsFor(state: ColorClashState, seat: number): number[] {
    if (state.phase === 'finished' || state.catchable === null || state.catchable === seat) return [];
    const target = this.seatState(state, state.catchable);
    if (target.forfeited || target.declared || target.hand.length !== 1) return [];
    const me = this.seatState(state, seat);
    return me.forfeited ? [] : [state.catchable];
  }

  private canDeclare(state: ColorClashState, seat: number): boolean {
    if (state.phase === 'finished') return false;
    const me = this.seatState(state, seat);
    return !me.forfeited && me.hand.length === 1 && !me.declared;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  validateAction(state: ColorClashState, seat: number, action: ColorClashAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    const me = state.seats.find((s) => s.seat === seat);
    if (!me) return { ok: false, code: 'unknown_seat', message: 'unknown seat' };
    if (me.forfeited) return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };

    if (action.type === 'declare') {
      if (me.hand.length !== 1) return { ok: false, code: 'not_final_card', message: 'declare only with one card left' };
      if (me.declared) return { ok: false, code: 'already_declared', message: 'already declared' };
      return { ok: true };
    }
    if (action.type === 'catch') {
      if (!Number.isInteger(action.target)) return { ok: false, code: 'bad_target', message: 'target must be a seat' };
      if (action.target === seat) return { ok: false, code: 'bad_target', message: 'cannot catch yourself' };
      if (!this.catchTargetsFor(state, seat).includes(action.target)) return { ok: false, code: 'no_catch', message: 'that player cannot be caught now' };
      return { ok: true };
    }

    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };

    if (action.type === 'draw') {
      if (state.phase !== 'play') return { ok: false, code: 'wrong_phase', message: 'you already drew; play it or pass' };
      return { ok: true };
    }
    if (action.type === 'pass') {
      if (state.phase !== 'drawn') return { ok: false, code: 'wrong_phase', message: 'you must play or draw' };
      return { ok: true };
    }
    if (action.type === 'play') {
      if (typeof action.cardId !== 'string') return { ok: false, code: 'bad_card', message: 'cardId required' };
      const card = me.hand.find((c) => c.id === action.cardId);
      if (!card) return { ok: false, code: 'not_in_hand', message: 'card not in hand' };
      if (state.phase === 'drawn' && card.id !== state.drawnCardId) return { ok: false, code: 'only_drawn_card', message: 'only the drawn card may be played now' };
      if (!this.cardPlayable(state, me.hand, card)) {
        if (card.kind === 'prism_surge' && state.pendingDraw === 0 && state.echoNumber === null) {
          return { ok: false, code: 'prism_surge_blocked', message: 'Prism Surge only when you hold no card of the current colour' };
        }
        return { ok: false, code: 'illegal_card', message: 'card does not match the table' };
      }
      if (card.kind === 'prism' || card.kind === 'prism_surge') {
        if (!action.color || !(CARD_COLORS as readonly string[]).includes(action.color)) {
          return { ok: false, code: 'color_required', message: 'choose a colour for the wild card' };
        }
      }
      return { ok: true };
    }
    return { ok: false, code: 'bad_action', message: 'unknown action' };
  }

  getLegalActions(state: ColorClashState, seat: number): ColorClashAction[] {
    if (state.phase === 'finished') return [];
    const me = state.seats.find((s) => s.seat === seat);
    if (!me || me.forfeited) return [];
    const out: ColorClashAction[] = [];
    if (this.canDeclare(state, seat)) out.push({ type: 'declare' });
    for (const t of this.catchTargetsFor(state, seat)) out.push({ type: 'catch', target: t });
    if (state.turnSeat !== seat) return out;
    for (const id of this.playableCardIds(state, seat)) {
      const card = me.hand.find((c) => c.id === id)!;
      if (card.kind === 'prism' || card.kind === 'prism_surge') {
        for (const color of CARD_COLORS) out.push({ type: 'play', cardId: id, color });
      } else {
        out.push({ type: 'play', cardId: id });
      }
    }
    if (state.phase === 'play') out.push({ type: 'draw' });
    if (state.phase === 'drawn') out.push({ type: 'pass' });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Apply
  // ---------------------------------------------------------------------------

  applyAction(state: ColorClashState, seat: number, action: ColorClashAction, rng: Rng): EngineStep<ColorClashState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: ColorClashState = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).consecutiveTimeouts = 0;
    switch (action.type) {
      case 'declare':
        this.doDeclare(next, seat, events);
        break;
      case 'catch':
        this.doCatch(next, seat, action.target, rng, events);
        break;
      case 'draw':
        this.doDraw(next, seat, rng, events);
        break;
      case 'pass':
        this.doPass(next, seat, events);
        break;
      case 'play':
        this.doPlay(next, seat, action.cardId, action.color, rng, events);
        break;
    }
    next.version += 1;
    return { state: next, events };
  }

  private doDeclare(state: ColorClashState, seat: number, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    me.declared = true;
    if (state.catchable === seat) state.catchable = null;
    events.push({ type: 'declared', seat, payload: {} });
  }

  private doCatch(state: ColorClashState, seat: number, target: number, rng: Rng, events: GameEvent[]): void {
    state.catchable = null;
    const drawn = this.dealTo(state, target, 2, rng, events);
    events.push({ type: 'caught', seat: target, payload: { by: seat, count: drawn } });
  }

  /** Current seat draws one card; may play it if legal, otherwise the turn passes. */
  private doDraw(state: ColorClashState, seat: number, rng: Rng, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    this.closeCatchWindow(state, seat);
    if (state.pendingDraw > 0) {
      const n = state.pendingDraw;
      state.pendingDraw = 0;
      this.dealTo(state, seat, n, rng, events);
      events.push({ type: 'surge', seat, payload: { count: n, resolved: true } });
      this.advanceTurn(state, events, 1);
      return;
    }
    if (state.echoNumber !== null) {
      // Echo: draw one and the constraint is lifted whether or not it was matched.
      this.dealTo(state, seat, 1, rng, events);
      const drawn = me.hand[me.hand.length - 1];
      if (drawn && this.cardPlayable(state, me.hand, drawn)) {
        state.phase = 'drawn';
        state.drawnCardId = drawn.id;
        this.resetTurnClock(state);
        return;
      }
      state.echoNumber = null;
      this.advanceTurn(state, events, 1);
      return;
    }
    const dealt = this.dealTo(state, seat, 1, rng, events);
    const drawn = dealt > 0 ? me.hand[me.hand.length - 1] : undefined;
    if (drawn && this.cardPlayable(state, me.hand, drawn)) {
      state.phase = 'drawn';
      state.drawnCardId = drawn.id;
      this.resetTurnClock(state);
      return;
    }
    this.advanceTurn(state, events, 1);
  }

  private doPass(state: ColorClashState, seat: number, events: GameEvent[]): void {
    this.closeCatchWindow(state, seat);
    state.drawnCardId = null;
    state.phase = 'play';
    if (state.echoNumber !== null) state.echoNumber = null;
    events.push({ type: 'passed', seat, payload: {} });
    this.advanceTurn(state, events, 1);
  }

  private doPlay(state: ColorClashState, seat: number, cardId: string, chosen: CardColor | undefined, rng: Rng, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    this.closeCatchWindow(state, seat);
    const idx = me.hand.findIndex((c) => c.id === cardId);
    const card = me.hand.splice(idx, 1)[0]!;
    state.discardPile.push(card);
    state.drawnCardId = null;
    state.phase = 'play';
    const wasEcho = state.echoNumber !== null;
    state.echoNumber = null;
    if (card.kind === 'prism' || card.kind === 'prism_surge') state.currentColor = chosen!;
    else if (card.color !== 'wild') state.currentColor = card.color;
    const ev: GameEvent = { type: 'card_played', seat, payload: { card, handCount: me.hand.length } };
    if (chosen) ev.payload['chosenColor'] = chosen;
    if (wasEcho) ev.payload['echoMatched'] = true;
    events.push(ev);

    if (me.hand.length === 1 && !me.declared) state.catchable = seat;
    if (me.hand.length > 1) me.declared = false;

    let skip = 0;
    switch (card.kind) {
      case 'skip': {
        const victim = this.nextActiveSeat(state, seat, 1);
        if (victim !== seat) events.push({ type: 'turn_skipped', seat: victim, payload: { by: seat } });
        skip = 1;
        break;
      }
      case 'flip': {
        if (this.activeSeats(state).length === 2) {
          // With two players a Flip acts as a Skip (the direction change would be invisible).
          const victim = this.nextActiveSeat(state, seat, 1);
          events.push({ type: 'direction_flipped', seat, payload: { direction: state.direction, actsAsSkip: true } });
          if (victim !== seat) events.push({ type: 'turn_skipped', seat: victim, payload: { by: seat } });
          skip = 1;
        } else {
          state.direction = state.direction === 1 ? -1 : 1;
          events.push({ type: 'direction_flipped', seat, payload: { direction: state.direction, actsAsSkip: false } });
        }
        break;
      }
      case 'surge':
      case 'prism_surge': {
        const amount = card.kind === 'surge' ? 2 : 4;
        const victim = this.nextActiveSeat(state, seat, 1);
        if (state.rules.stackSurge) {
          state.pendingDraw += amount;
          events.push({ type: 'surge', seat: victim, payload: { count: state.pendingDraw, by: seat, pending: true } });
        } else {
          this.dealTo(state, victim, amount, rng, events);
          events.push({ type: 'surge', seat: victim, payload: { count: amount, by: seat, pending: false } });
          if (victim !== seat) events.push({ type: 'turn_skipped', seat: victim, payload: { by: seat } });
          skip = 1;
        }
        break;
      }
      case 'echo': {
        const number = this.lastNumberValue(state);
        state.echoNumber = number;
        events.push({ type: 'echo_active', seat, payload: { number } });
        break;
      }
      default:
        break;
    }

    if (me.hand.length === 0) {
      this.endRound(state, seat, rng, events);
      return;
    }
    this.advanceTurn(state, events, 1 + skip);
  }

  /** Value of the most recent number card on the discard pile (the round starter guarantees one). */
  private lastNumberValue(state: ColorClashState): number {
    for (let i = state.discardPile.length - 1; i >= 0; i--) {
      const c = state.discardPile[i]!;
      if (c.kind === 'number') return c.value ?? 0;
    }
    return 0;
  }

  /** Any turn-consuming action by a seat closes a catch window on another seat. */
  private closeCatchWindow(state: ColorClashState, _actor: number): void {
    state.catchable = null;
  }

  /** Move up to `count` cards from the draw pile to `seat`, reshuffling the discard when needed. */
  private dealTo(state: ColorClashState, seat: number, count: number, rng: Rng, events: GameEvent[]): number {
    const me = this.seatState(state, seat);
    let dealt = 0;
    for (let i = 0; i < count; i++) {
      if (state.drawPile.length === 0) this.reshuffle(state, rng, events);
      const c = state.drawPile.pop();
      if (!c) break;
      me.hand.push(c);
      dealt++;
    }
    if (dealt > 0) {
      me.declared = false;
      if (state.catchable === seat) state.catchable = null;
      events.push({ type: 'card_drawn', seat, payload: { count: dealt, handCount: me.hand.length } });
    }
    return dealt;
  }

  private reshuffle(state: ColorClashState, rng: Rng, events: GameEvent[]): void {
    if (state.discardPile.length <= 1) return;
    const top = state.discardPile.pop()!;
    const rest = state.discardPile;
    state.discardPile = [top];
    state.drawPile = shuffle(rest, rng);
    events.push({ type: 'pile_reshuffled', payload: { count: state.drawPile.length } });
  }

  private advanceTurn(state: ColorClashState, events: GameEvent[], steps: number): void {
    if (state.phase === 'finished') return;
    state.phase = 'play';
    state.drawnCardId = null;
    state.turnSeat = this.nextActiveSeat(state, state.turnSeat, steps);
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, pendingDraw: state.pendingDraw, echoNumber: state.echoNumber } });
  }

  // ---------------------------------------------------------------------------
  // Round and match end
  // ---------------------------------------------------------------------------

  private endRound(state: ColorClashState, winner: number, rng: Rng, events: GameEvent[]): void {
    const points = state.seats.filter((s) => s.seat !== winner && !s.forfeited).reduce((acc, s) => acc + handPoints(s.hand), 0);
    const w = this.seatState(state, winner);
    w.score += points;
    state.lastRound = { winnerSeat: winner, points };
    state.catchable = null;
    state.echoNumber = null;
    state.pendingDraw = 0;
    events.push({ type: 'round_won', seat: winner, payload: { points, round: state.round, hands: state.seats.map((s) => ({ seat: s.seat, points: handPoints(s.hand) })) } });
    const done = w.score >= state.rules.targetScore || state.round >= state.rules.maxRounds;
    if (done) {
      this.finish(state, events, winner);
      return;
    }
    this.startRound(state, this.nextActiveSeat(state, winner, 1), rng, events);
  }

  /** Placements: score descending, ties by remaining hand value ascending, forfeited last. */
  private finish(state: ColorClashState, events: GameEvent[], roundWinner: number | null): void {
    const active = this.activeSeats(state);
    const ranked = [...active].sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (a.seat === roundWinner) return -1;
      if (b.seat === roundWinner) return 1;
      return handPoints(a.hand) - handPoints(b.hand);
    });
    const forfeited = [...state.forfeitOrder].reverse();
    state.placements = [...ranked.map((s) => s.seat), ...forfeited];
    state.phase = 'finished';
    state.turnDeadline = null;
    state.drawnCardId = null;
    events.push({ type: 'match_finished', payload: { placements: [...state.placements] } });
  }

  getResult(state: ColorClashState): MatchResult {
    const finished = state.phase === 'finished';
    const order = finished ? state.placements : state.seats.map((s) => s.seat);
    const placements = order.map((seat, i) => {
      const s = this.seatState(state, seat);
      return { seat, placement: i + 1, score: s.score };
    });
    return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
  }

  // ---------------------------------------------------------------------------
  // Timeout and leaving
  // ---------------------------------------------------------------------------

  onTimeout(state: ColorClashState, rng: Rng): EngineStep<ColorClashState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: ColorClashState = structuredClone(state);
    const events: GameEvent[] = [];
    const seat = next.turnSeat;
    const me = this.seatState(next, seat);
    me.consecutiveTimeouts += 1;
    events.push({ type: 'turn_timeout', seat, payload: { count: me.consecutiveTimeouts } });
    if (me.consecutiveTimeouts >= next.rules.timeoutsToForfeit) {
      this.forfeit(next, seat, 'timeouts', events);
      next.version += 1;
      return { state: next, events };
    }
    if (next.phase === 'drawn') {
      this.doPass(next, seat, events);
    } else {
      // Auto-play: draw, and if the drawn card happens to be playable, pass on it.
      this.doDraw(next, seat, rng, events);
      if ((next.phase as ColorClashPhase) === 'drawn') this.doPass(next, seat, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  onPlayerLeft(state: ColorClashState, seat: number, _rng: Rng): EngineStep<ColorClashState> {
    if (state.phase === 'finished') return { state, events: [] };
    const me = this.seatState(state, seat);
    if (me.forfeited) return { state, events: [] };
    const next: ColorClashState = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).connected = false;
    this.forfeit(next, seat, 'left', events);
    next.version += 1;
    return { state: next, events };
  }

  private forfeit(state: ColorClashState, seat: number, reason: string, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    me.forfeited = true;
    state.forfeitOrder.push(seat);
    // Their cards return under the discard pile so they re-enter play on the next reshuffle.
    state.discardPile.unshift(...me.hand);
    me.hand = [];
    me.declared = false;
    if (state.catchable === seat) state.catchable = null;
    events.push({ type: 'player_forfeited', seat, payload: { reason } });
    const active = this.activeSeats(state);
    if (active.length <= 1) {
      this.finish(state, events, active[0]?.seat ?? null);
      return;
    }
    if (state.turnSeat === seat) {
      // Any penalty waiting for the leaver evaporates with them.
      state.pendingDraw = 0;
      state.echoNumber = null;
      state.drawnCardId = null;
      state.phase = 'play';
      // Step from the previous active seat so the walk lands on the next live player.
      const order = state.seats.map((s) => s.seat);
      const idx = order.indexOf(seat);
      state.turnSeat = order[(idx - state.direction + order.length) % order.length]!;
      this.advanceTurn(state, events, 1);
    }
  }

  // ---------------------------------------------------------------------------
  // View
  // ---------------------------------------------------------------------------

  getView(state: ColorClashState, viewerSeat: number | null): ColorClashView {
    const me = viewerSeat === null ? null : state.seats.find((s) => s.seat === viewerSeat) ?? null;
    const myTurn = me !== null && state.phase !== 'finished' && state.turnSeat === me.seat && !me.forfeited;
    return {
      rules: state.rules,
      round: state.round,
      phase: state.phase,
      turnSeat: state.turnSeat,
      direction: state.direction,
      drawCount: state.drawPile.length,
      discardCount: state.discardPile.length,
      topCard: this.topCard(state),
      currentColor: state.currentColor,
      echoNumber: state.echoNumber,
      pendingDraw: state.pendingDraw,
      catchable: state.catchable,
      version: state.version,
      turnDeadline: state.turnDeadline,
      placements: [...state.placements],
      lastRound: state.lastRound,
      seats: state.seats.map((s) => ({
        seat: s.seat,
        userId: s.userId,
        displayName: s.displayName,
        handCount: s.hand.length,
        score: s.score,
        declared: s.declared,
        consecutiveTimeouts: s.consecutiveTimeouts,
        forfeited: s.forfeited,
        connected: s.connected,
      })),
      viewerSeat,
      myHand: me ? me.hand.map((c) => ({ ...c })) : null,
      playable: me ? this.playableCardIds(state, me.seat) : [],
      drawnCardId: myTurn && state.phase === 'drawn' ? state.drawnCardId : null,
      canDeclare: me ? this.canDeclare(state, me.seat) : false,
      canDraw: myTurn && state.phase === 'play',
      canPass: myTurn && state.phase === 'drawn',
      catchTargets: me ? this.catchTargetsFor(state, me.seat) : [],
    };
  }
}
