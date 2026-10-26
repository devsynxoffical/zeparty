import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { COURSES, courseByIndex, type Course, type Vec } from './courses.js';
import { simulateStroke, type StrokeResult } from './physics.js';
import { resolveMiniGolfRules, type MiniGolfRules } from './rules.js';

export type MiniGolfAction = { type: 'putt'; angle: number; power: number };

export interface MiniGolfSeatState {
  seat: number;
  userId: string;
  displayName: string;
  /** Strokes per played hole (index into rules.holes); 0 for holes not yet played. */
  strokes: number[];
  /** Ball position on the current hole. */
  position: Vec;
  /** Last rest position (water returns the ball here). */
  lastRest: Vec;
  /** Holed out (or picked up) on the current hole. */
  holed: boolean;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export interface MiniGolfState {
  rules: MiniGolfRules;
  seats: MiniGolfSeatState[];
  /** Index into rules.holes. */
  holeIndex: number;
  /** Full course data for the current hole so the client renders what the server simulates. */
  course: Course;
  table: { width: number; height: number };
  turnSeat: number;
  phase: 'play' | 'finished';
  /** Obstacle clock in seconds; moving obstacles are a function of it. */
  obstaclePhase: number;
  /** Seats that won each hole outright (null for ties), one per played hole. */
  holeWinners: Array<number | null>;
  placements: number[];
  version: number;
  turnStartedAt: number;
  turnDeadline: number | null;
  lastEvent: string | null;
}

const NOW = () => Date.now();

export class MiniGolfEngine implements GameEngine<MiniGolfState, MiniGolfAction> {
  readonly gameId = 'mini_golf_paradise';

  constructor(private readonly now: () => number = NOW) {}

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, _rng: Rng): MiniGolfState {
    if (players.length < 2 || players.length > 4) throw new Error('mini golf requires 2 to 4 players');
    const rules = resolveMiniGolfRules(rulesInput);
    const course = courseByIndex(rules.holes[0]!);
    const seats: MiniGolfSeatState[] = players.map((p) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      strokes: rules.holes.map(() => 0),
      position: { ...course.tee },
      lastRest: { ...course.tee },
      holed: false,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const t = this.now();
    return {
      rules,
      seats,
      holeIndex: 0,
      course,
      table: { width: course.width, height: course.height },
      turnSeat: seats[0]!.seat,
      phase: 'play',
      obstaclePhase: 0,
      holeWinners: [],
      placements: [],
      version: 0,
      turnStartedAt: t,
      turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
      lastEvent: null,
    };
  }

  currentSeat(state: MiniGolfState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: MiniGolfState, seat: number): MiniGolfSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  validateAction(state: MiniGolfState, seat: number, action: MiniGolfAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
    const me = this.seatState(state, seat);
    if (me.forfeited || me.holed) return { ok: false, code: 'inactive_seat', message: 'seat cannot putt now' };
    if (!action || action.type !== 'putt') return { ok: false, code: 'bad_action', message: 'unknown action' };
    if (typeof action.angle !== 'number' || !Number.isFinite(action.angle)) return { ok: false, code: 'bad_angle', message: 'angle must be a finite number' };
    if (typeof action.power !== 'number' || !Number.isFinite(action.power) || action.power <= 0 || action.power > 1) {
      return { ok: false, code: 'bad_power', message: 'power must be in (0, 1]' };
    }
    return { ok: true };
  }

  getLegalActions(state: MiniGolfState, seat: number): MiniGolfAction[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    const me = this.seatState(state, seat);
    if (me.forfeited || me.holed) return [];
    return [{ type: 'putt', angle: angleToHole(state.course, me.position), power: 0.5 }];
  }

  applyAction(state: MiniGolfState, seat: number, action: MiniGolfAction, _rng: Rng): EngineStep<MiniGolfState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: MiniGolfState = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).consecutiveTimeouts = 0;
    this.doPutt(next, seat, action.angle, action.power, events);
    next.version += 1;
    return { state: next, events };
  }

  /** Simulate the stroke, apply scoring, then move the match forward. */
  private doPutt(state: MiniGolfState, seat: number, angle: number, power: number, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    const hi = state.holeIndex;
    const result: StrokeResult = simulateStroke(state.course, me.position, angle, power, state.obstaclePhase);
    state.obstaclePhase = round3(state.obstaclePhase + result.duration);
    me.strokes[hi] = (me.strokes[hi] ?? 0) + 1;

    if (result.water) {
      me.strokes[hi] += 1;
      me.position = { ...me.lastRest };
    } else {
      me.position = { ...result.final };
      me.lastRest = { ...result.final };
    }
    events.push({
      type: 'stroke_resolved',
      seat,
      payload: {
        seat,
        frames: result.frames,
        holed: result.holed,
        water: result.water,
        bounces: result.bounces,
        final: { ...me.position },
        strokes: me.strokes[hi],
      },
    });
    if (result.water) events.push({ type: 'penalty', seat, payload: { reason: 'water', strokes: me.strokes[hi] } });

    if (result.holed) {
      me.holed = true;
      if (me.strokes[hi] === 1) events.push({ type: 'hole_in_one', seat, payload: { hole: hi } });
    } else if (me.strokes[hi]! >= state.rules.maxStrokes) {
      me.strokes[hi] = state.rules.maxStrokes;
      me.holed = true;
      events.push({ type: 'penalty', seat, payload: { reason: 'max_strokes', strokes: me.strokes[hi] } });
    }
    state.lastEvent = 'stroke_resolved';
    this.afterStroke(state, events);
  }

  private activeSeats(state: MiniGolfState): MiniGolfSeatState[] {
    return state.seats.filter((s) => !s.forfeited);
  }

  /** Called after any stroke or forfeit: completes the hole, advances or finishes the match. */
  private afterStroke(state: MiniGolfState, events: GameEvent[]): void {
    if (state.phase === 'finished') return;
    const active = this.activeSeats(state);
    if (active.length <= 1) {
      this.finishMatch(state, events);
      return;
    }
    if (active.every((s) => s.holed)) {
      this.completeHole(state, events);
      return;
    }
    this.advanceTurn(state, events);
  }

  private completeHole(state: MiniGolfState, events: GameEvent[]): void {
    const hi = state.holeIndex;
    const active = this.activeSeats(state);
    const scores: Record<string, number> = {};
    for (const s of state.seats) scores[String(s.seat)] = s.strokes[hi] ?? state.rules.maxStrokes;
    const best = Math.min(...active.map((s) => s.strokes[hi]!));
    const winners = active.filter((s) => s.strokes[hi] === best);
    state.holeWinners[hi] = winners.length === 1 ? winners[0]!.seat : null;
    events.push({ type: 'hole_completed', payload: { hole: hi, scores, winnerSeat: state.holeWinners[hi] } });

    if (hi + 1 >= state.rules.holes.length) {
      this.finishMatch(state, events);
      return;
    }
    state.holeIndex = hi + 1;
    state.course = courseByIndex(state.rules.holes[state.holeIndex]!);
    state.table = { width: state.course.width, height: state.course.height };
    for (const s of state.seats) {
      s.position = { ...state.course.tee };
      s.lastRest = { ...state.course.tee };
      s.holed = false;
    }
    events.push({ type: 'next_hole', payload: { hole: state.holeIndex, courseId: state.course.id, par: state.course.par } });
    // Rotate the honour: a different seat tees off each hole.
    const order = active.map((s) => s.seat);
    state.turnSeat = order[state.holeIndex % order.length]!;
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, hole: state.holeIndex } });
  }

  private advanceTurn(state: MiniGolfState, events: GameEvent[]): void {
    const candidates = state.seats.filter((s) => !s.forfeited && !s.holed);
    if (candidates.length === 0) return;
    let pick: MiniGolfSeatState;
    if (state.rules.strokeOrder === 'farthest') {
      pick = candidates.reduce((best, s) => (dist(s.position, state.course.hole) > dist(best.position, state.course.hole) + 1e-9 ? s : best), candidates[0]!);
    } else {
      const order = state.seats.map((s) => s.seat);
      let idx = order.indexOf(state.turnSeat);
      pick = candidates[0]!;
      for (let i = 0; i < order.length; i++) {
        idx = (idx + 1) % order.length;
        const cand = this.seatState(state, order[idx]!);
        if (!cand.forfeited && !cand.holed) {
          pick = cand;
          break;
        }
      }
    }
    state.turnSeat = pick.seat;
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, hole: state.holeIndex } });
  }

  private finishMatch(state: MiniGolfState, events: GameEvent[]): void {
    // Unplayed or unfinished holes count max strokes for everyone still in the match.
    for (const s of state.seats) {
      for (let h = 0; h < state.rules.holes.length; h++) {
        const completed = h < state.holeIndex || (h === state.holeIndex && s.holed && !s.forfeited);
        if (!completed) s.strokes[h] = state.rules.maxStrokes;
      }
    }
    state.placements = rankSeats(state).map((s) => s.seat);
    state.phase = 'finished';
    state.turnDeadline = null;
    state.lastEvent = 'match_finished';
    events.push({
      type: 'match_finished',
      payload: {
        placements: state.placements.map((seat, i) => ({ seat, placement: i + 1, total: totalStrokes(this.seatState(state, seat)) })),
      },
    });
  }

  private resetTurnClock(state: MiniGolfState): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  onTimeout(state: MiniGolfState, _rng: Rng): EngineStep<MiniGolfState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: MiniGolfState = structuredClone(state);
    const events: GameEvent[] = [];
    const seat = next.turnSeat;
    const me = this.seatState(next, seat);
    me.consecutiveTimeouts += 1;
    events.push({ type: 'turn_timeout', seat, payload: { count: me.consecutiveTimeouts } });
    if (me.consecutiveTimeouts >= next.rules.timeoutsToForfeit) {
      me.forfeited = true;
      me.holed = true;
      events.push({ type: 'player_forfeited', seat, payload: { reason: 'timeouts' } });
      this.afterStroke(next, events);
    } else {
      // Idle player: the server putts a weak straight shot toward the cup.
      this.doPutt(next, seat, angleToHole(next.course, me.position), 0.3, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  onPlayerLeft(state: MiniGolfState, seat: number, _rng: Rng): EngineStep<MiniGolfState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: MiniGolfState = structuredClone(state);
    const me = this.seatState(next, seat);
    if (me.forfeited) return { state, events: [] };
    const events: GameEvent[] = [];
    me.forfeited = true;
    me.connected = false;
    me.holed = true;
    events.push({ type: 'player_forfeited', seat, payload: { reason: 'left' } });
    if (next.turnSeat === seat || this.activeSeats(next).length <= 1 || this.activeSeats(next).every((s) => s.holed)) {
      this.afterStroke(next, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: MiniGolfState): MatchResult {
    const finished = state.phase === 'finished';
    const ranked = finished ? state.placements.map((seat) => this.seatState(state, seat)) : rankSeats(state);
    const placements = ranked.map((s, i) => ({ seat: s.seat, placement: i + 1, score: totalStrokes(s) }));
    return { finished, placements, winnerSeats: finished && placements[0] ? [placements[0].seat] : [] };
  }

  /** No hidden information: the full state is the view. */
  getView(state: MiniGolfState, _viewerSeat: number | null): MiniGolfState {
    return state;
  }
}

export function totalStrokes(s: MiniGolfSeatState): number {
  return s.strokes.reduce((a, b) => a + b, 0);
}

export function holesWon(state: MiniGolfState, seat: number): number {
  return state.holeWinners.filter((w) => w === seat).length;
}

/** Lowest total wins; ties broken by holes won outright, then seat order. Forfeited seats rank last. */
export function rankSeats(state: MiniGolfState): MiniGolfSeatState[] {
  return [...state.seats].sort((a, b) => {
    if (a.forfeited !== b.forfeited) return a.forfeited ? 1 : -1;
    const d = totalStrokes(a) - totalStrokes(b);
    if (d !== 0) return d;
    const w = holesWon(state, b.seat) - holesWon(state, a.seat);
    if (w !== 0) return w;
    return a.seat - b.seat;
  });
}

export function angleToHole(course: Course, from: Vec): number {
  return Math.atan2(course.hole.y - from.y, course.hole.x - from.x);
}

function dist(a: Vec, b: Vec): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}

export { COURSES };
