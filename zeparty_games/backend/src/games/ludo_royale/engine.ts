import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { COLOR_ORDER, HOME_STEP, LAST_TRACK_STEP, absoluteIndex, isSafeSquare, type LudoColor } from './board.js';
import { resolveLudoRules, type LudoRules } from './rules.js';

export type LudoAction = { type: 'roll' } | { type: 'move'; token: number };

export interface LudoSeatState {
  seat: number;
  userId: string;
  displayName: string;
  color: LudoColor;
  /** Relative step per token, -1 = base, 56 = home. */
  tokens: number[];
  finishedPlacement: number | null;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export interface LudoState {
  rules: LudoRules;
  seats: LudoSeatState[];
  turnSeat: number;
  phase: 'roll' | 'move' | 'finished';
  /** Last server-authorized die value awaiting a move, null in roll phase. */
  dice: number | null;
  consecutiveSixes: number;
  /** Token indices legal for the pending die (precomputed for the client). */
  legalTokens: number[];
  /** Monotonic state version, incremented on every applied step. */
  version: number;
  placements: number[]; // seat order of finishing
  turnStartedAt: number;
  turnDeadline: number | null;
  lastEvent: string | null;
}

export function colorsForPlayerCount(n: number): LudoColor[] {
  if (n === 2) return ['red', 'yellow'];
  if (n === 3) return ['red', 'green', 'yellow'];
  return [...COLOR_ORDER];
}

const NOW = () => Date.now();

export class LudoEngine implements GameEngine<LudoState, LudoAction> {
  readonly gameId = 'ludo_royale';

  constructor(private readonly now: () => number = NOW) {}

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, _rng: Rng): LudoState {
    if (players.length < 2 || players.length > 4) throw new Error('ludo requires 2 to 4 players');
    const rules = resolveLudoRules(rulesInput);
    const colors = colorsForPlayerCount(players.length);
    const seats: LudoSeatState[] = players.map((p, i) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      color: colors[i]!,
      tokens: Array.from({ length: rules.maxTokens }, (_, t) => (t < rules.tokensStartingOut ? 0 : -1)),
      finishedPlacement: null,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const t = this.now();
    return {
      rules,
      seats,
      turnSeat: seats[0]!.seat,
      phase: 'roll',
      dice: null,
      consecutiveSixes: 0,
      legalTokens: [],
      version: 0,
      placements: [],
      turnStartedAt: t,
      turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
      lastEvent: null,
    };
  }

  currentSeat(state: LudoState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: LudoState, seat: number): LudoSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  validateAction(state: LudoState, seat: number, action: LudoAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
    const me = this.seatState(state, seat);
    if (me.forfeited || me.finishedPlacement !== null) return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
    if (action.type === 'roll') {
      if (state.phase !== 'roll') return { ok: false, code: 'wrong_phase', message: 'expected move, not roll' };
      return { ok: true };
    }
    if (action.type === 'move') {
      if (state.phase !== 'move') return { ok: false, code: 'wrong_phase', message: 'roll first' };
      if (!Number.isInteger(action.token) || action.token < 0 || action.token >= me.tokens.length) {
        return { ok: false, code: 'bad_token', message: 'token index out of range' };
      }
      if (!state.legalTokens.includes(action.token)) return { ok: false, code: 'illegal_move', message: 'token cannot move with this roll' };
      return { ok: true };
    }
    return { ok: false, code: 'bad_action', message: 'unknown action' };
  }

  getLegalActions(state: LudoState, seat: number): LudoAction[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    if (state.phase === 'roll') return [{ type: 'roll' }];
    return state.legalTokens.map((token) => ({ type: 'move', token }));
  }

  /** Compute which tokens of `seat` can legally move `dice` steps. */
  legalTokensFor(state: LudoState, seat: number, dice: number): number[] {
    const me = this.seatState(state, seat);
    const r = state.rules;
    const legal: number[] = [];
    me.tokens.forEach((step, idx) => {
      if (step === HOME_STEP) return;
      let target: number;
      if (step < 0) {
        if (dice !== r.unlockRoll) return;
        target = 0;
      } else {
        target = step + dice;
        if (target > HOME_STEP) {
          if (r.exactHomeEntry) return;
          target = HOME_STEP;
        }
      }
      if (r.stackingAllowed && this.blockedByOpponentStack(state, me, step, target)) return;
      legal.push(idx);
    });
    return legal;
  }

  /** With stacking enabled, an opponent block (2+ tokens) on the landing square cannot be captured. */
  private blockedByOpponentStack(state: LudoState, me: LudoSeatState, _from: number, target: number): boolean {
    if (target > LAST_TRACK_STEP) return false;
    const abs = absoluteIndex(me.color, target)!;
    for (const other of state.seats) {
      if (other.seat === me.seat) continue;
      const count = other.tokens.filter((t) => t >= 0 && t <= LAST_TRACK_STEP && absoluteIndex(other.color, t) === abs).length;
      if (count >= 2) return true;
    }
    return false;
  }

  applyAction(state: LudoState, seat: number, action: LudoAction, rng: Rng): EngineStep<LudoState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: LudoState = structuredClone(state);
    const events: GameEvent[] = [];
    if (action.type === 'roll') {
      this.doRoll(next, seat, rng.int(1, 6), events);
    } else {
      this.doMove(next, seat, action.token, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  private doRoll(state: LudoState, seat: number, value: number, events: GameEvent[]): void {
    const r = state.rules;
    state.dice = value;
    state.consecutiveSixes = value === 6 ? state.consecutiveSixes + 1 : 0;
    events.push({ type: 'dice_rolled', seat, payload: { value, consecutiveSixes: state.consecutiveSixes } });
    if (r.threeSixesForfeit && value === 6 && state.consecutiveSixes >= 3) {
      events.push({ type: 'three_sixes', seat, payload: {} });
      state.consecutiveSixes = 0;
      this.advanceTurn(state, events, false);
      return;
    }
    const legal = this.legalTokensFor(state, seat, value);
    state.legalTokens = legal;
    if (legal.length === 0) {
      events.push({ type: 'no_legal_move', seat, payload: { value } });
      // A six with nothing to move still grants another roll in classic rules.
      this.advanceTurn(state, events, r.extraTurnOnSix && value === 6);
      return;
    }
    const me = this.seatState(state, seat);
    const distinctTargets = new Set(legal.map((i) => me.tokens[i]));
    if (distinctTargets.size === 1 && state.rules.variant !== 'tournament') {
      // Auto-move when every legal token is in the same spot (one real choice). Tournament keeps manual.
      this.doMove(state, seat, legal[0]!, events, true);
      return;
    }
    state.phase = 'move';
    this.resetTurnClock(state);
  }

  private doMove(state: LudoState, seat: number, tokenIdx: number, events: GameEvent[], auto = false): void {
    const r = state.rules;
    const me = this.seatState(state, seat);
    const dice = state.dice!;
    const from = me.tokens[tokenIdx]!;
    let to: number;
    if (from < 0) to = 0;
    else {
      to = from + dice;
      if (to > HOME_STEP) to = HOME_STEP;
    }
    me.tokens[tokenIdx] = to;
    events.push({ type: 'token_moved', seat, payload: { token: tokenIdx, from, to, dice, auto } });

    let extraTurn = r.extraTurnOnSix && dice === 6;

    // Captures
    if (to >= 0 && to <= LAST_TRACK_STEP) {
      const abs = absoluteIndex(me.color, to)!;
      const safe = isSafeSquare(abs, r.safeSquares) && !r.captureOnSafe;
      if (!safe) {
        for (const other of state.seats) {
          if (other.seat === seat) continue;
          other.tokens.forEach((t, i) => {
            if (t >= 0 && t <= LAST_TRACK_STEP && absoluteIndex(other.color, t) === abs) {
              other.tokens[i] = -1;
              events.push({ type: 'token_captured', seat, payload: { victimSeat: other.seat, token: i, square: abs } });
              if (r.extraTurnOnCapture) extraTurn = true;
            }
          });
        }
      } else if (isSafeSquare(abs, r.safeSquares)) {
        events.push({ type: 'safe_square', seat, payload: { token: tokenIdx, square: abs } });
      }
    }

    // Home entry and player finish
    if (to === HOME_STEP) {
      events.push({ type: 'token_home', seat, payload: { token: tokenIdx } });
      if (r.extraTurnOnHome) extraTurn = true;
      if (me.tokens.every((t) => t === HOME_STEP)) {
        me.finishedPlacement = state.placements.length + 1;
        state.placements.push(seat);
        events.push({ type: 'player_finished', seat, payload: { placement: me.finishedPlacement } });
        extraTurn = false;
      }
    }

    state.dice = null;
    state.legalTokens = [];
    if (this.checkMatchEnd(state, events)) return;
    this.advanceTurn(state, events, extraTurn && me.finishedPlacement === null);
  }

  private activeSeats(state: LudoState): LudoSeatState[] {
    return state.seats.filter((s) => !s.forfeited && s.finishedPlacement === null);
  }

  private checkMatchEnd(state: LudoState, events: GameEvent[]): boolean {
    const active = this.activeSeats(state);
    const finishedCount = state.placements.length;
    const end =
      active.length <= 1 ||
      (state.rules.endOnFirstWinner && finishedCount >= 1) ||
      (state.seats.length === 2 && finishedCount >= 1);
    if (!end) return false;
    // Remaining active seats get the next placements by progress, then forfeited seats last.
    const byProgress = [...active].sort((a, b) => progress(b) - progress(a));
    for (const s of byProgress) {
      s.finishedPlacement = state.placements.length + 1;
      state.placements.push(s.seat);
    }
    for (const s of state.seats.filter((x) => x.forfeited && x.finishedPlacement === null)) {
      s.finishedPlacement = state.placements.length + 1;
      state.placements.push(s.seat);
    }
    state.phase = 'finished';
    state.turnDeadline = null;
    state.lastEvent = 'match_finished';
    events.push({ type: 'match_finished', payload: { placements: [...state.placements] } });
    return true;
  }

  private advanceTurn(state: LudoState, events: GameEvent[], extraTurn: boolean): void {
    if (state.phase === 'finished') return;
    state.dice = null;
    state.legalTokens = [];
    state.phase = 'roll';
    if (extraTurn) {
      events.push({ type: 'extra_turn', seat: state.turnSeat, payload: {} });
      this.resetTurnClock(state);
      return;
    }
    state.consecutiveSixes = 0;
    const order = state.seats.map((s) => s.seat);
    let idx = order.indexOf(state.turnSeat);
    for (let i = 0; i < order.length; i++) {
      idx = (idx + 1) % order.length;
      const cand = this.seatState(state, order[idx]!);
      if (!cand.forfeited && cand.finishedPlacement === null) {
        state.turnSeat = cand.seat;
        break;
      }
    }
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline } });
  }

  private resetTurnClock(state: LudoState): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  onTimeout(state: LudoState, rng: Rng): EngineStep<LudoState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: LudoState = structuredClone(state);
    const events: GameEvent[] = [];
    const seat = next.turnSeat;
    const me = this.seatState(next, seat);
    me.consecutiveTimeouts += 1;
    events.push({ type: 'turn_timeout', seat, payload: { count: me.consecutiveTimeouts } });
    if (me.consecutiveTimeouts >= next.rules.timeoutsToForfeit) {
      me.forfeited = true;
      events.push({ type: 'player_forfeited', seat, payload: { reason: 'timeouts' } });
      if (!this.checkMatchEnd(next, events)) this.advanceTurn(next, events, false);
      next.version += 1;
      return { state: next, events };
    }
    if (next.phase === 'roll') {
      this.doRoll(next, seat, rng.int(1, 6), events);
      // doRoll may leave us in move phase with several options: pick one for the idle player.
      if ((next.phase as string) === 'move') {
        const pick = next.legalTokens[rng.int(0, next.legalTokens.length - 1)]!;
        this.doMove(next, seat, pick, events, true);
      }
    } else if (next.phase === 'move') {
      const pick = next.legalTokens[rng.int(0, next.legalTokens.length - 1)]!;
      this.doMove(next, seat, pick, events, true);
    }
    next.version += 1;
    return { state: next, events };
  }

  onPlayerLeft(state: LudoState, seat: number, _rng: Rng): EngineStep<LudoState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: LudoState = structuredClone(state);
    const events: GameEvent[] = [];
    const me = this.seatState(next, seat);
    if (me.forfeited || me.finishedPlacement !== null) return { state, events: [] };
    me.forfeited = true;
    me.connected = false;
    events.push({ type: 'player_forfeited', seat, payload: { reason: 'left' } });
    if (!this.checkMatchEnd(next, events) && next.turnSeat === seat) this.advanceTurn(next, events, false);
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: LudoState): MatchResult {
    const finished = state.phase === 'finished';
    const placements = state.seats
      .map((s) => ({ seat: s.seat, placement: s.finishedPlacement ?? state.seats.length, score: progress(s) }))
      .sort((a, b) => a.placement - b.placement);
    return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
  }

  /** Ludo has no hidden information; the full state is the view. */
  getView(state: LudoState, _viewerSeat: number | null): LudoState {
    return state;
  }
}

/** Progress score: steps travelled across all tokens (home = 56 each). */
export function progress(s: LudoSeatState): number {
  return s.tokens.reduce((acc, t) => acc + Math.max(t, 0), 0);
}
