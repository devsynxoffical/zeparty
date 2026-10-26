import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { resolveDartsRules, x01Start, type DartsFormat, type DartsRules } from './rules.js';
import { BOARD_GEOMETRY, BULL, SEGMENTS, computeLanding, scoreAt, type DartScore } from './scoring.js';

export type DartsAction = { type: 'throw'; aimX: number; aimY: number; release: number };

export const CRICKET_NUMBERS: readonly number[] = [20, 19, 18, 17, 16, 15, BULL];
export const DARTS_PER_VISIT = 3;
/** Around the clock: targets 1..20 then the bull (25); `CLOCK_DONE` means the leg is won. */
export const CLOCK_BULL = 25;
export const CLOCK_DONE = 26;

export interface ThrownDart {
  dartIndex: number;
  aim: { x: number; y: number };
  landed: { x: number; y: number };
  segment: number;
  multiplier: number;
  points: number;
  label: string;
  bust?: boolean;
  miss?: boolean;
}

export interface DartsSeatState {
  seat: number;
  userId: string;
  displayName: string;
  /** x01: points left in the current leg. 0 for other formats. */
  remaining: number;
  /** x01 doubleIn: true once the player has started scoring. */
  inOpen: boolean;
  /** Cricket: marks per number ('20'..'15', '25'), 0..3. */
  marks: Record<string, number>;
  /** Cricket points. */
  points: number;
  /** Around the clock: next target 1..20, 25 for bull, 26 when done. */
  clockTarget: number;
  legsWon: number;
  finishedPlacement: number | null;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export interface DartsState {
  rules: DartsRules;
  format: DartsFormat;
  seats: DartsSeatState[];
  turnSeat: number;
  phase: 'throw' | 'finished';
  /** 1-based leg number. */
  leg: number;
  legStarterSeat: number;
  /** Index of the next dart in the current visit, 0..2. */
  dartIndex: number;
  /** Darts thrown so far in the current visit (cleared on turn change). */
  visit: ThrownDart[];
  /** x01: remaining at the start of the visit, restored on a bust. */
  visitStartRemaining: number;
  /** The previous player's complete visit, for rendering after a turn change. */
  lastVisit: { seat: number; darts: ThrownDart[]; score: number } | null;
  legWinners: number[];
  version: number;
  placements: number[];
  turnStartedAt: number;
  turnDeadline: number | null;
  lastEvent: string | null;
  /** Geometry constants so a client can draw an exact board without hardcoding. */
  board: typeof BOARD_GEOMETRY & { segments: readonly number[] };
}

const NOW = () => Date.now();

export class DartsEngine implements GameEngine<DartsState, DartsAction> {
  readonly gameId = 'darts_arena';

  constructor(private readonly now: () => number = NOW) {}

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, _rng: Rng): DartsState {
    if (players.length < 2 || players.length > 4) throw new Error('darts requires 2 to 4 players');
    const rules = resolveDartsRules(rulesInput);
    const seats: DartsSeatState[] = players.map((p) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      remaining: 0,
      inOpen: false,
      marks: {},
      points: 0,
      clockTarget: 1,
      legsWon: 0,
      finishedPlacement: null,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const t = this.now();
    const state: DartsState = {
      rules,
      format: rules.format,
      seats,
      turnSeat: seats[0]!.seat,
      phase: 'throw',
      leg: 1,
      legStarterSeat: seats[0]!.seat,
      dartIndex: 0,
      visit: [],
      visitStartRemaining: 0,
      lastVisit: null,
      legWinners: [],
      version: 0,
      placements: [],
      turnStartedAt: t,
      turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
      lastEvent: null,
      board: { ...BOARD_GEOMETRY, segments: [...SEGMENTS] },
    };
    for (const s of seats) this.resetSeatForLeg(state, s);
    state.visitStartRemaining = seats[0]!.remaining;
    return state;
  }

  private resetSeatForLeg(state: DartsState, s: DartsSeatState): void {
    const start = x01Start(state.format);
    s.remaining = start ?? 0;
    s.inOpen = !state.rules.doubleIn;
    s.marks = Object.fromEntries(CRICKET_NUMBERS.map((n) => [String(n), 0]));
    s.points = 0;
    s.clockTarget = 1;
  }

  currentSeat(state: DartsState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: DartsState, seat: number): DartsSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  private activeSeats(state: DartsState): DartsSeatState[] {
    return state.seats.filter((s) => !s.forfeited);
  }

  validateAction(state: DartsState, seat: number, action: DartsAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
    const me = this.seatState(state, seat);
    if (me.forfeited) return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
    if (action.type !== 'throw') return { ok: false, code: 'bad_action', message: 'unknown action' };
    const { aimX, aimY, release } = action;
    if (![aimX, aimY, release].every((v) => typeof v === 'number' && Number.isFinite(v))) {
      return { ok: false, code: 'bad_throw', message: 'aim and release must be finite numbers' };
    }
    if (Math.hypot(aimX, aimY) > BOARD_GEOMETRY.maxAimRadius) return { ok: false, code: 'bad_aim', message: 'aim is off the board' };
    if (release < 0 || release > 1) return { ok: false, code: 'bad_release', message: 'release must be within 0..1' };
    return { ok: true };
  }

  getLegalActions(state: DartsState, seat: number): DartsAction[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    // Continuous action space: return a representative throw at the bull.
    return [{ type: 'throw', aimX: 0, aimY: 0, release: 1 }];
  }

  applyAction(state: DartsState, seat: number, action: DartsAction, rng: Rng): EngineStep<DartsState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: DartsState = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).consecutiveTimeouts = 0;
    this.throwDart(next, seat, action.aimX, action.aimY, action.release, rng, events);
    next.version += 1;
    return { state: next, events };
  }

  // ---------------------------------------------------------------------------
  // Throw resolution
  // ---------------------------------------------------------------------------

  private throwDart(state: DartsState, seat: number, aimX: number, aimY: number, release: number, rng: Rng, events: GameEvent[]): void {
    const landing = computeLanding(aimX, aimY, release, state.rules.baseSigma, rng);
    const score = scoreAt(landing.x, landing.y);
    const me = this.seatState(state, seat);
    const dart: ThrownDart = {
      dartIndex: state.dartIndex,
      aim: { x: aimX, y: aimY },
      landed: { x: landing.x, y: landing.y },
      segment: score.segment,
      multiplier: score.multiplier,
      points: score.points,
      label: score.label,
    };
    if (score.multiplier === 0) dart.miss = true;

    let outcome: 'continue' | 'bust' | 'leg_won';
    switch (state.format) {
      case '501':
      case '301':
        outcome = this.applyX01(state, me, score, dart);
        break;
      case 'cricket':
        outcome = this.applyCricket(state, me, score);
        break;
      case 'around_the_clock':
        outcome = this.applyClock(me, score);
        break;
    }
    if (outcome === 'bust') dart.bust = true;
    state.visit.push(dart);
    events.push({ type: 'dart_thrown', seat, payload: { ...dart, seat, sigma: landing.sigma } });
    state.lastEvent = 'dart_thrown';

    if (outcome === 'bust') {
      events.push({ type: 'bust', seat, payload: { remaining: me.remaining } });
      this.endVisit(state, seat, 0, events);
      return;
    }
    if (outcome === 'leg_won') {
      this.winLeg(state, seat, events);
      return;
    }
    state.dartIndex += 1;
    if (state.dartIndex >= DARTS_PER_VISIT) {
      this.endVisit(state, seat, this.visitScore(state), events);
    }
  }

  private visitScore(state: DartsState): number {
    return state.visit.reduce((a, d) => a + (d.bust ? 0 : d.points), 0);
  }

  private applyX01(state: DartsState, me: DartsSeatState, score: DartScore, dart: ThrownDart): 'continue' | 'bust' | 'leg_won' {
    const r = state.rules;
    if (!me.inOpen) {
      if (score.multiplier !== 2) {
        // Not in yet: the dart counts for nothing, no bust.
        dart.points = 0;
        return 'continue';
      }
      me.inOpen = true;
    }
    const after = me.remaining - score.points;
    if (after < 0) return this.bustX01(state, me);
    if (r.doubleOut) {
      if (after === 1) return this.bustX01(state, me);
      if (after === 0 && score.multiplier !== 2) return this.bustX01(state, me);
    }
    me.remaining = after;
    return after === 0 ? 'leg_won' : 'continue';
  }

  private bustX01(state: DartsState, me: DartsSeatState): 'bust' {
    me.remaining = state.visitStartRemaining;
    return 'bust';
  }

  private applyCricket(state: DartsState, me: DartsSeatState, score: DartScore): 'continue' | 'leg_won' {
    if (score.multiplier === 0 || !CRICKET_NUMBERS.includes(score.segment)) return 'continue';
    const key = String(score.segment);
    const value = score.segment; // bull scores 25 per mark
    const others = this.activeSeats(state).filter((s) => s.seat !== me.seat);
    for (let i = 0; i < score.multiplier; i++) {
      const have = me.marks[key] ?? 0;
      if (have < 3) {
        me.marks[key] = have + 1;
      } else if (others.some((o) => (o.marks[key] ?? 0) < 3)) {
        me.points += value;
      }
    }
    const allClosed = CRICKET_NUMBERS.every((n) => (me.marks[String(n)] ?? 0) >= 3);
    if (allClosed && others.every((o) => me.points >= o.points)) return 'leg_won';
    return 'continue';
  }

  private applyClock(me: DartsSeatState, score: DartScore): 'continue' | 'leg_won' {
    if (score.multiplier === 0) return 'continue';
    if (score.segment !== me.clockTarget) return 'continue';
    me.clockTarget = me.clockTarget === 20 ? CLOCK_BULL : me.clockTarget === CLOCK_BULL ? CLOCK_DONE : me.clockTarget + 1;
    return me.clockTarget === CLOCK_DONE ? 'leg_won' : 'continue';
  }

  // ---------------------------------------------------------------------------
  // Visits, turns, legs
  // ---------------------------------------------------------------------------

  private endVisit(state: DartsState, seat: number, visitScore: number, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    events.push({ type: 'visit_ended', seat, payload: { visitScore, remaining: me.remaining, points: me.points, clockTarget: me.clockTarget } });
    state.lastVisit = { seat, darts: [...state.visit], score: visitScore };
    this.advanceTurn(state, events);
  }

  private advanceTurn(state: DartsState, events: GameEvent[]): void {
    if (state.phase === 'finished') return;
    const order = state.seats.map((s) => s.seat);
    let idx = order.indexOf(state.turnSeat);
    for (let i = 0; i < order.length; i++) {
      idx = (idx + 1) % order.length;
      const cand = this.seatState(state, order[idx]!);
      if (!cand.forfeited) {
        state.turnSeat = cand.seat;
        break;
      }
    }
    this.startVisit(state, events);
  }

  private startVisit(state: DartsState, events: GameEvent[]): void {
    state.visit = [];
    state.dartIndex = 0;
    state.visitStartRemaining = this.seatState(state, state.turnSeat).remaining;
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, leg: state.leg } });
  }

  private resetTurnClock(state: DartsState): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  private winLeg(state: DartsState, seat: number, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    me.legsWon += 1;
    state.legWinners.push(seat);
    const visitScore = this.visitScore(state);
    events.push({ type: 'leg_won', seat, payload: { leg: state.leg, legsWon: me.legsWon, legsToWin: state.rules.legsToWin, visitScore } });
    state.lastVisit = { seat, darts: [...state.visit], score: visitScore };
    if (me.legsWon >= state.rules.legsToWin) {
      this.finishMatch(state, events, seat);
      return;
    }
    // Next leg: the player after the previous starter throws first.
    state.leg += 1;
    for (const s of state.seats) this.resetSeatForLeg(state, s);
    const order = state.seats.map((s) => s.seat);
    let idx = order.indexOf(state.legStarterSeat);
    for (let i = 0; i < order.length; i++) {
      idx = (idx + 1) % order.length;
      const cand = this.seatState(state, order[idx]!);
      if (!cand.forfeited) {
        state.legStarterSeat = cand.seat;
        break;
      }
    }
    state.turnSeat = state.legStarterSeat;
    events.push({ type: 'leg_started', payload: { leg: state.leg, starterSeat: state.turnSeat } });
    this.startVisit(state, events);
  }

  /** Progress used to order non-winning seats: higher is better. */
  private progress(state: DartsState, s: DartsSeatState): number {
    const legs = s.legsWon * 1_000_000;
    switch (state.format) {
      case '501':
      case '301':
        return legs + ((x01Start(state.format) ?? 0) - s.remaining);
      case 'cricket': {
        const marks = CRICKET_NUMBERS.reduce((a, n) => a + Math.min(3, s.marks[String(n)] ?? 0), 0);
        return legs + marks * 1000 + s.points;
      }
      case 'around_the_clock':
        return legs + s.clockTarget;
    }
  }

  private finishMatch(state: DartsState, events: GameEvent[], winnerSeat: number | null): void {
    const placements: number[] = [];
    if (winnerSeat !== null) placements.push(winnerSeat);
    const rest = state.seats.filter((s) => s.seat !== winnerSeat && !s.forfeited).sort((a, b) => this.progress(state, b) - this.progress(state, a));
    for (const s of rest) placements.push(s.seat);
    const forfeited = state.seats.filter((s) => s.forfeited && s.seat !== winnerSeat).sort((a, b) => this.progress(state, b) - this.progress(state, a));
    for (const s of forfeited) placements.push(s.seat);
    placements.forEach((seat, i) => {
      this.seatState(state, seat).finishedPlacement = i + 1;
    });
    state.placements = placements;
    state.phase = 'finished';
    state.turnDeadline = null;
    state.lastEvent = 'match_finished';
    events.push({ type: 'match_finished', payload: { placements: [...placements] } });
  }

  // ---------------------------------------------------------------------------
  // Timeouts and leaving
  // ---------------------------------------------------------------------------

  onTimeout(state: DartsState, rng: Rng): EngineStep<DartsState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: DartsState = structuredClone(state);
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
    // Throw the rest of the visit for the idle player: low quality darts aimed loosely at the board.
    const guard = DARTS_PER_VISIT + 1;
    for (let i = 0; i < guard && next.phase === 'throw' && next.turnSeat === seat; i++) {
      const a = rng.float() * Math.PI * 2;
      const r = rng.float() * 0.5;
      this.throwDart(next, seat, Math.sin(a) * r, -Math.cos(a) * r, 0.1, rng, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  private forfeit(state: DartsState, seat: number, reason: string, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    me.forfeited = true;
    events.push({ type: 'player_forfeited', seat, payload: { reason } });
    const active = this.activeSeats(state);
    if (active.length <= 1) {
      this.finishMatch(state, events, active[0]?.seat ?? null);
      return;
    }
    if (state.turnSeat === seat) {
      state.lastVisit = state.visit.length > 0 ? { seat, darts: [...state.visit], score: this.visitScore(state) } : state.lastVisit;
      this.advanceTurn(state, events);
    }
  }

  onPlayerLeft(state: DartsState, seat: number, _rng: Rng): EngineStep<DartsState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: DartsState = structuredClone(state);
    const me = this.seatState(next, seat);
    if (me.forfeited) return { state, events: [] };
    const events: GameEvent[] = [];
    me.connected = false;
    this.forfeit(next, seat, 'left', events);
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: DartsState): MatchResult {
    const finished = state.phase === 'finished';
    const placements = state.seats
      .map((s) => ({ seat: s.seat, placement: s.finishedPlacement ?? state.seats.length, score: this.progress(state, s) }))
      .sort((a, b) => a.placement - b.placement);
    return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
  }

  /** Darts has no hidden information; the full state is the view. */
  getView(state: DartsState, _viewerSeat: number | null): DartsState {
    return state;
  }
}
