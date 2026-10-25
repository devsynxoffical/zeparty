import type { EngineStep, GameEvent, MatchResult, PlayerSeat, RealtimeEngine, Rng, Validation } from '../engine.js';
import {
  FACEOFF_SPEED,
  GOAL_WIDTH,
  MOVE_BUDGET_CAP_MS,
  PADDLE_IDLE_MS,
  PADDLE_MAX_SPEED,
  PADDLE_RADIUS,
  PUCK_RADIUS,
  TABLE_HEIGHT,
  TABLE_WIDTH,
  TICK_MS,
  clampPaddleSpeed,
  clampPaddleToHalf,
  collidePaddle,
  concedingSeat,
  integratePuck,
  limitStep,
  paddleHome,
  resolveWalls,
  substepsFor,
  type Body,
  type Point,
} from './physics.js';
import { resolveAirHockeyRules, type AirHockeyRules } from './rules.js';

export type AirHockeyAction = { type: 'paddle'; x: number; y: number; seq: number };

export interface AirHockeySeatState {
  seat: number;
  userId: string;
  displayName: string;
  score: number;
  connected: boolean;
  forfeited: boolean;
}

export interface PaddleState extends Body {
  /** Highest input `seq` the server has accepted for this seat. */
  lastAckSeq: number;
  /** Simulation time (ms) of the last accepted input. */
  lastInputAt: number;
  /** Banked travel allowance in table units (refilled at PADDLE_MAX_SPEED). */
  moveBudget: number;
}

export type AirHockeyPhase = 'playing' | 'finished';
export type FinishReason = 'goals' | 'time' | 'sudden_death' | 'forfeit' | 'draw';

export interface AirHockeyState {
  rules: AirHockeyRules;
  table: { width: number; height: number; goalWidth: number; puckRadius: number; paddleRadius: number };
  seats: AirHockeySeatState[];
  puck: Body;
  /** Indexed by seat (0 = bottom, 1 = top). */
  paddles: PaddleState[];
  /** Remaining match time in ms (counts down, 0 when expired or untimed). */
  clockMs: number;
  /** Simulated time since the match started, in ms. All timestamps below use this clock. */
  elapsedMs: number;
  /** Simulation time at which the puck is released; null while play is live. */
  faceoffAt: number | null;
  /** Seat the puck drifts toward at the next faceoff. */
  faceoffToward: number;
  /** True once the clock expired on a tie: next goal wins. */
  suddenDeath: boolean;
  phase: AirHockeyPhase;
  placements: number[];
  finishReason: FinishReason | null;
  turnDeadline: null;
  version: number;
}

const INITIAL_FACEOFF_MS = 1500;

export class AirHockeyEngine implements RealtimeEngine<AirHockeyState, AirHockeyAction> {
  readonly gameId = 'air_hockey';
  readonly tickRateHz = 60;
  readonly broadcastHz = 20;

  // Scratch objects reused across ticks so the hot loop allocates nothing but the state copy.
  private readonly scratchPoint: Point = { x: 0, y: 0 };
  private readonly scratchContact: Point = { x: 0, y: 0 };

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, rng: Rng): AirHockeyState {
    if (players.length !== 2) throw new Error('air hockey requires exactly 2 players');
    const rules = resolveAirHockeyRules(rulesInput);
    const sorted = [...players].sort((a, b) => a.seat - b.seat);
    const seats: AirHockeySeatState[] = sorted.map((p) => ({ seat: p.seat, userId: p.userId, displayName: p.displayName, score: 0, connected: true, forfeited: false }));
    const paddles: PaddleState[] = [0, 1].map((seat) => {
      const home = paddleHome(seat, { x: 0, y: 0 });
      return { x: home.x, y: home.y, vx: 0, vy: 0, lastAckSeq: 0, lastInputAt: 0, moveBudget: (PADDLE_MAX_SPEED * MOVE_BUDGET_CAP_MS) / 1000 };
    });
    const toward = rng.int(0, 1);
    return {
      rules,
      table: { width: TABLE_WIDTH, height: TABLE_HEIGHT, goalWidth: GOAL_WIDTH, puckRadius: PUCK_RADIUS, paddleRadius: PADDLE_RADIUS },
      seats,
      puck: { x: TABLE_WIDTH / 2, y: TABLE_HEIGHT / 2, vx: 0, vy: toward === 0 ? FACEOFF_SPEED : -FACEOFF_SPEED },
      paddles,
      clockMs: rules.matchSeconds * 1000,
      elapsedMs: 0,
      faceoffAt: INITIAL_FACEOFF_MS,
      faceoffToward: toward,
      suddenDeath: false,
      phase: 'playing',
      placements: [],
      finishReason: null,
      turnDeadline: null,
      version: 0,
    };
  }

  currentSeat(_state: AirHockeyState): number | null {
    return null;
  }

  validateAction(state: AirHockeyState, seat: number, action: AirHockeyAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (seat !== 0 && seat !== 1) return { ok: false, code: 'bad_seat', message: 'unknown seat' };
    if (state.seats[seat]?.forfeited) return { ok: false, code: 'inactive_seat', message: 'seat has forfeited' };
    if (!action || typeof action !== 'object' || action.type !== 'paddle') return { ok: false, code: 'bad_action', message: 'expected a paddle action' };
    if (!Number.isFinite(action.x) || !Number.isFinite(action.y)) return { ok: false, code: 'bad_action', message: 'x and y must be finite numbers' };
    if (!Number.isInteger(action.seq) || action.seq < 0) return { ok: false, code: 'bad_action', message: 'seq must be a non-negative integer' };
    return { ok: true };
  }

  getLegalActions(_state: AirHockeyState, _seat: number): AirHockeyAction[] {
    return [];
  }

  /**
   * Paddle input. The requested position is clamped to the seat's half and to the travel
   * budget accrued since the last accepted input, so a client can never teleport. Inputs
   * with a seq at or below the last accepted one are dropped without changing state.
   */
  applyAction(state: AirHockeyState, seat: number, action: AirHockeyAction, _rng: Rng): EngineStep<AirHockeyState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const prev = state.paddles[seat]!;
    if (action.seq <= prev.lastAckSeq) return { state, events: [] };
    const next = this.copy(state);
    const p = next.paddles[seat]!;
    clampPaddleToHalf(seat, action.x, action.y, this.scratchPoint);
    const moved = limitStep(p.x, p.y, this.scratchPoint.x, this.scratchPoint.y, p.moveBudget, this.scratchPoint);
    const dtMs = Math.max(TICK_MS, next.elapsedMs - p.lastInputAt);
    const dtS = dtMs / 1000;
    const prevX = p.x;
    const prevY = p.y;
    p.vx = (this.scratchPoint.x - p.x) / dtS;
    p.vy = (this.scratchPoint.y - p.y) / dtS;
    clampPaddleSpeed(p);
    p.x = this.scratchPoint.x;
    p.y = this.scratchPoint.y;
    p.moveBudget -= moved;
    p.lastAckSeq = action.seq;
    p.lastInputAt = next.elapsedMs;
    next.version += 1;
    const events: GameEvent[] = [];
    // A paddle that moves onto the puck hits it immediately (swept contact).
    if (next.faceoffAt === null) {
      const speed = collidePaddle(next.puck, p, prevX, prevY);
      if (speed >= 0) events.push({ type: 'puck_hit', seat, payload: { speed: Math.round(speed), x: round1(next.puck.x), y: round1(next.puck.y) } });
      // Separation may have pushed the puck into a wall; keep it inside the table.
      if (resolveWalls(next.puck, this.scratchContact)) events.push({ type: 'wall_bounce', payload: { x: round1(this.scratchContact.x), y: round1(this.scratchContact.y) } });
    }
    return { state: next, events };
  }

  /** Fixed-rate server step. Integrates the puck, resolves hits, walls, goals and the clock. */
  tick(state: AirHockeyState, dtMs: number, rng: Rng): EngineStep<AirHockeyState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next = this.copy(state);
    const events: GameEvent[] = [];
    next.elapsedMs += dtMs;
    next.version += 1;

    // Paddle bookkeeping: refill travel budget, drop stale velocity.
    for (let s = 0; s < 2; s++) {
      const p = next.paddles[s]!;
      const cap = (PADDLE_MAX_SPEED * MOVE_BUDGET_CAP_MS) / 1000;
      p.moveBudget = Math.min(cap, p.moveBudget + (PADDLE_MAX_SPEED * dtMs) / 1000);
      if (next.elapsedMs - p.lastInputAt > PADDLE_IDLE_MS) {
        p.vx = 0;
        p.vy = 0;
      }
    }

    // Clock.
    if (next.rules.matchSeconds > 0 && next.clockMs > 0) {
      next.clockMs = Math.max(0, next.clockMs - dtMs);
      if (next.clockMs === 0 && !next.suddenDeath) {
        const [a, b] = [next.seats[0]!.score, next.seats[1]!.score];
        if (a !== b) {
          this.finish(next, events, 'time');
          return { state: next, events };
        }
        if (next.rules.suddenDeath) {
          next.suddenDeath = true;
          events.push({ type: 'sudden_death', payload: {} });
        } else {
          this.finish(next, events, 'draw');
          return { state: next, events };
        }
      }
    }

    // Faceoff pause: puck frozen at centre.
    if (next.faceoffAt !== null) {
      if (next.elapsedMs < next.faceoffAt) return { state: next, events };
      next.faceoffAt = null;
      const jitter = (rng.float() - 0.5) * 30;
      next.puck.vx = jitter;
      next.puck.vy = next.faceoffToward === 0 ? FACEOFF_SPEED : -FACEOFF_SPEED;
      events.push({ type: 'faceoff', payload: { toward: next.faceoffToward } });
    }

    const steps = substepsFor(dtMs);
    const subDt = dtMs / steps / 1000;
    const puck = next.puck;
    for (let i = 0; i < steps; i++) {
      integratePuck(puck, subDt);
      for (let s = 0; s < 2; s++) {
        const speed = collidePaddle(puck, next.paddles[s]!);
        if (speed >= 0) events.push({ type: 'puck_hit', seat: s, payload: { speed: Math.round(speed), x: round1(puck.x), y: round1(puck.y) } });
      }
      if (resolveWalls(puck, this.scratchContact)) {
        events.push({ type: 'wall_bounce', payload: { x: round1(this.scratchContact.x), y: round1(this.scratchContact.y) } });
      }
      const conceded = concedingSeat(puck);
      if (conceded >= 0) {
        const scorer = conceded === 0 ? 1 : 0;
        this.scoreGoal(next, scorer, events);
        break;
      }
    }
    return { state: next, events };
  }

  private scoreGoal(next: AirHockeyState, scorer: number, events: GameEvent[]): void {
    next.seats = next.seats.map((s) => (s.seat === scorer ? { ...s, score: s.score + 1 } : s));
    const score = [next.seats[0]!.score, next.seats[1]!.score];
    events.push({ type: 'goal', seat: scorer, payload: { score } });
    const conceder = scorer === 0 ? 1 : 0;
    if (next.seats[scorer]!.score >= next.rules.goalsToWin) {
      this.finish(next, events, 'goals');
      return;
    }
    if (next.suddenDeath) {
      this.finish(next, events, 'sudden_death');
      return;
    }
    next.puck = { x: TABLE_WIDTH / 2, y: TABLE_HEIGHT / 2, vx: 0, vy: 0 };
    next.faceoffToward = conceder;
    next.faceoffAt = next.elapsedMs + next.rules.faceoffPauseMs;
  }

  private finish(next: AirHockeyState, events: GameEvent[], reason: FinishReason): void {
    next.phase = 'finished';
    next.finishReason = reason;
    next.faceoffAt = null;
    next.puck = { ...next.puck, vx: 0, vy: 0 };
    const [a, b] = next.seats;
    let order: number[];
    if (reason === 'forfeit') {
      order = a!.forfeited ? [1, 0] : [0, 1];
    } else if (a!.score === b!.score) {
      order = [0, 1];
    } else {
      order = a!.score > b!.score ? [0, 1] : [1, 0];
    }
    next.placements = order;
    events.push({ type: 'match_finished', payload: { placements: [...order], reason, score: [a!.score, b!.score] } });
  }

  /** Timeouts do not apply to a clocked real-time game; the room never arms one. */
  onTimeout(state: AirHockeyState, _rng: Rng): EngineStep<AirHockeyState> {
    return { state, events: [] };
  }

  onPlayerLeft(state: AirHockeyState, seat: number, _rng: Rng): EngineStep<AirHockeyState> {
    if (state.phase === 'finished') return { state, events: [] };
    if (seat !== 0 && seat !== 1) return { state, events: [] };
    const next = this.copy(state);
    next.seats = next.seats.map((s) => (s.seat === seat ? { ...s, forfeited: true, connected: false } : s));
    const events: GameEvent[] = [{ type: 'player_forfeited', seat, payload: { reason: 'left' } }];
    this.finish(next, events, 'forfeit');
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: AirHockeyState): MatchResult {
    const finished = state.phase === 'finished';
    const order = finished ? state.placements : [0, 1];
    const draw = finished && state.finishReason === 'draw';
    const placements = order.map((seat, i) => ({ seat, placement: draw ? 1 : i + 1, score: state.seats[seat]!.score }));
    const winnerSeats = !finished ? [] : draw ? [0, 1] : [order[0]!];
    return { finished, placements, winnerSeats };
  }

  /** No hidden information: the full state is the view. */
  getView(state: AirHockeyState, _viewerSeat: number | null): AirHockeyState {
    return state;
  }

  /** Shallow copy with fresh puck and paddle objects (the parts a step mutates). */
  private copy(state: AirHockeyState): AirHockeyState {
    return {
      ...state,
      puck: { x: state.puck.x, y: state.puck.y, vx: state.puck.vx, vy: state.puck.vy },
      paddles: [{ ...state.paddles[0]! }, { ...state.paddles[1]! }],
    };
  }
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
