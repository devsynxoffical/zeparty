import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { clamp, nearestFreeSpot, placementBlocked, simulateShot, type Body, type CollisionEvent, type Keyframe } from './physics.js';
import { resolvePoolRules, type PoolRules } from './rules.js';
import {
  BALL_RADIUS,
  CUE,
  EIGHT,
  FOOT_SPOT,
  HEAD_SPOT,
  HEAD_STRING_X,
  RACK_APEX_SLOT,
  RACK_BACK_CORNERS,
  RACK_EIGHT_SLOT,
  isSolid,
  isStripe,
  rackSlots,
  round3,
  tableSpec,
  type TableSpec,
} from './table.js';

export type PoolGroup = 'solids' | 'stripes';
export type PoolFoul = 'scratch' | 'no_contact' | 'wrong_first_contact' | 'no_rail';

export type PoolAction =
  | { type: 'shot'; angle: number; power: number; spin?: { x: number; y: number } }
  | { type: 'place_cue'; x: number; y: number };

export interface PoolBall {
  id: number;
  x: number;
  y: number;
  pocketed: boolean;
}

export interface PoolSeatState {
  seat: number;
  userId: string;
  displayName: string;
  group: PoolGroup | null;
  fouls: number;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export interface LastShotSummary {
  seat: number;
  pocketed: number[];
  fouls: PoolFoul[];
  firstContact: number | null;
  railContacted: boolean;
  cueScratched: boolean;
  isBreak: boolean;
}

export interface PoolState {
  rules: PoolRules;
  table: TableSpec;
  seats: PoolSeatState[];
  balls: PoolBall[];
  turnSeat: number;
  phase: 'break' | 'play' | 'finished';
  /** No groups assigned yet. */
  openTable: boolean;
  /** The shooter may place the cue ball before shooting. */
  ballInHand: boolean;
  /** When true the cue ball must stay behind the head string while in hand (break and, optionally, after a break scratch). */
  cueBehindHeadString: boolean;
  shotCount: number;
  lastShot: LastShotSummary | null;
  winnerSeat: number | null;
  finishReason: string | null;
  placements: number[];
  /** Monotonic state version, incremented on every applied step. */
  version: number;
  turnStartedAt: number;
  turnDeadline: number | null;
  lastEvent: string | null;
}

export interface ShotResolvedPayload extends Record<string, unknown> {
  frames: Keyframe[];
  collisions: CollisionEvent[];
  pocketed: Array<{ id: number; by: number; pocket: number; t: number }>;
  fouls: PoolFoul[];
  firstContact: number | null;
  railContacted: boolean;
  cueScratched: boolean;
  isBreak: boolean;
  duration: number;
  final: Body[];
  shot: { angle: number; power: number; spin: { x: number; y: number } };
}

const NOW = () => Date.now();

export function groupOf(id: number): PoolGroup | 'eight' | 'cue' {
  if (id === CUE) return 'cue';
  if (id === EIGHT) return 'eight';
  return isSolid(id) ? 'solids' : 'stripes';
}

export function otherGroup(g: PoolGroup): PoolGroup {
  return g === 'solids' ? 'stripes' : 'solids';
}

export class PoolEliteEngine implements GameEngine<PoolState, PoolAction> {
  readonly gameId = 'pool_elite';

  constructor(private readonly now: () => number = NOW) {}

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, rng: Rng): PoolState {
    if (players.length !== 2) throw new Error('pool requires exactly 2 players');
    const rules = resolvePoolRules(rulesInput);
    const seats: PoolSeatState[] = players.map((p) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      group: null,
      fouls: 0,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const t = this.now();
    return {
      rules,
      table: tableSpec(),
      seats,
      balls: rackBalls(rng),
      turnSeat: seats[0]!.seat,
      phase: 'break',
      openTable: true,
      ballInHand: true,
      cueBehindHeadString: true,
      shotCount: 0,
      lastShot: null,
      winnerSeat: null,
      finishReason: null,
      placements: [],
      version: 0,
      turnStartedAt: t,
      turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
      lastEvent: null,
    };
  }

  currentSeat(state: PoolState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: PoolState, seat: number): PoolSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  private opponentOf(state: PoolState, seat: number): PoolSeatState {
    const o = state.seats.find((x) => x.seat !== seat);
    if (!o) throw new Error('no opponent');
    return o;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  validateAction(state: PoolState, seat: number, action: PoolAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
    const me = this.seatState(state, seat);
    if (me.forfeited) return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
    if (action.type === 'shot') {
      if (!Number.isFinite(action.angle)) return { ok: false, code: 'bad_angle', message: 'angle must be a finite number' };
      if (!Number.isFinite(action.power) || action.power < 0 || action.power > 1) return { ok: false, code: 'bad_power', message: 'power must be within 0..1' };
      if (action.spin !== undefined) {
        const { x, y } = action.spin;
        if (!Number.isFinite(x) || !Number.isFinite(y) || Math.abs(x) > 1 || Math.abs(y) > 1) return { ok: false, code: 'bad_spin', message: 'spin components must be within -1..1' };
      }
      return { ok: true };
    }
    if (action.type === 'place_cue') {
      if (!state.ballInHand) return { ok: false, code: 'not_ball_in_hand', message: 'cue ball is not in hand' };
      if (!Number.isFinite(action.x) || !Number.isFinite(action.y)) return { ok: false, code: 'bad_position', message: 'position must be finite' };
      return this.validatePlacement(state, action.x, action.y);
    }
    return { ok: false, code: 'bad_action', message: 'unknown action' };
  }

  validatePlacement(state: PoolState, x: number, y: number): Validation {
    const others = state.balls.filter((b) => !b.pocketed && b.id !== CUE);
    if (state.cueBehindHeadString && x > HEAD_STRING_X) return { ok: false, code: 'behind_head_string', message: 'cue ball must be placed behind the head string' };
    if (placementBlocked(x, y, others)) return { ok: false, code: 'bad_placement', message: 'cue ball must be on the cloth and clear of other balls' };
    return { ok: true };
  }

  getLegalActions(state: PoolState, seat: number): PoolAction[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    const out: PoolAction[] = [this.autoShot(state, seat, null)];
    if (state.ballInHand) {
      const cue = this.cueBall(state);
      out.push({ type: 'place_cue', x: cue.x, y: cue.y });
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  applyAction(state: PoolState, seat: number, action: PoolAction, _rng: Rng): EngineStep<PoolState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: PoolState = structuredClone(state);
    const events: GameEvent[] = [];
    if (action.type === 'place_cue') {
      const cue = this.cueBall(next);
      cue.x = round3(action.x);
      cue.y = round3(action.y);
      cue.pocketed = false;
      events.push({ type: 'cue_placed', seat, payload: { x: cue.x, y: cue.y } });
      next.lastEvent = 'cue_placed';
    } else {
      this.resolveShot(next, seat, action, events);
    }
    next.version += 1;
    return { state: next, events };
  }

  private cueBall(state: PoolState): PoolBall {
    const c = state.balls.find((b) => b.id === CUE);
    if (!c) throw new Error('cue ball missing');
    return c;
  }

  private onTable(state: PoolState): PoolBall[] {
    return state.balls.filter((b) => !b.pocketed);
  }

  private remainingOf(state: PoolState, group: PoolGroup): number {
    return state.balls.filter((b) => !b.pocketed && groupOf(b.id) === group).length;
  }

  /** Balls the shooter may legally contact first. */
  legalFirstContacts(state: PoolState, seat: number): number[] {
    const me = this.seatState(state, seat);
    const live = this.onTable(state).filter((b) => b.id !== CUE);
    if (state.phase === 'break') return live.map((b) => b.id);
    if (state.openTable || me.group === null) return live.filter((b) => b.id !== EIGHT).map((b) => b.id);
    const own = live.filter((b) => groupOf(b.id) === me.group);
    if (own.length > 0) return own.map((b) => b.id);
    return live.filter((b) => b.id === EIGHT).map((b) => b.id);
  }

  private resolveShot(state: PoolState, seat: number, action: Extract<PoolAction, { type: 'shot' }>, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    const opp = this.opponentOf(state, seat);
    const isBreak = state.phase === 'break';
    const legalFirst = new Set(this.legalFirstContacts(state, seat));
    const ownRemainingBefore = me.group ? this.remainingOf(state, me.group) : null;
    const spin = { x: clamp(action.spin?.x ?? 0, -1, 1), y: clamp(action.spin?.y ?? 0, -1, 1) };

    const bodies: Body[] = this.onTable(state).map((b) => ({ id: b.id, x: b.x, y: b.y }));
    const sim = simulateShot(bodies, { angle: action.angle, power: action.power, spin });

    // Apply final positions.
    const pocketedIds = new Set(sim.pocketed.map((p) => p.id));
    for (const b of state.balls) {
      if (b.pocketed) continue;
      if (pocketedIds.has(b.id)) {
        b.pocketed = true;
        continue;
      }
      const f = sim.final.find((x) => x.id === b.id);
      if (f) {
        b.x = f.x;
        b.y = f.y;
      }
    }
    const objectPocketed = sim.pocketed.map((p) => p.id).filter((id) => id !== CUE);

    // Fouls
    const fouls: PoolFoul[] = [];
    if (sim.cueScratched) fouls.push('scratch');
    if (sim.firstContact === null) fouls.push('no_contact');
    else if (!legalFirst.has(sim.firstContact)) fouls.push('wrong_first_contact');
    if (sim.firstContact !== null && objectPocketed.length === 0 && !sim.railAfterContact) fouls.push('no_rail');
    if (fouls.length > 0) me.fouls += 1;

    state.shotCount += 1;
    state.ballInHand = false;
    state.cueBehindHeadString = false;
    state.lastShot = { seat, pocketed: sim.pocketed.map((p) => p.id), fouls, firstContact: sim.firstContact, railContacted: sim.railAfterContact, cueScratched: sim.cueScratched, isBreak };
    state.lastEvent = 'shot_resolved';

    const payload: ShotResolvedPayload = {
      frames: sim.frames,
      collisions: sim.collisions,
      pocketed: sim.pocketed.map((p) => ({ id: p.id, by: seat, pocket: p.pocket, t: p.t })),
      fouls,
      firstContact: sim.firstContact,
      railContacted: sim.railAfterContact,
      cueScratched: sim.cueScratched,
      isBreak,
      duration: sim.duration,
      final: sim.final,
      shot: { angle: action.angle, power: action.power, spin },
    };
    events.push({ type: 'shot_resolved', seat, payload });

    const eightPocketed = objectPocketed.includes(EIGHT);

    if (isBreak) {
      state.phase = 'play';
      if (eightPocketed) {
        if (state.rules.eightOnBreak === 'win' && fouls.length === 0) {
          this.finish(state, seat, 'eight_on_break', events);
          return;
        }
        this.respotEight(state, events);
      }
      if (fouls.length > 0) {
        this.giveBallInHand(state, opp.seat, sim.cueScratched, !state.rules.ballInHandAnywhere, events);
        this.changeTurn(state, opp.seat, events);
        return;
      }
      if (objectPocketed.some((id) => id !== EIGHT)) {
        this.continueTurn(state, seat, events);
        return;
      }
      this.changeTurn(state, opp.seat, events);
      return;
    }

    if (eightPocketed) {
      const cleared = me.group !== null && ownRemainingBefore === 0;
      if (cleared && fouls.length === 0) {
        this.finish(state, seat, 'eight_ball', events);
      } else if (!cleared) {
        this.finish(state, opp.seat, 'early_eight', events);
      } else if (sim.cueScratched) {
        this.finish(state, opp.seat, 'scratch_on_eight', events);
      } else {
        this.finish(state, opp.seat, 'foul_on_eight', events);
      }
      return;
    }

    // Group assignment on the first legal pocket after the break.
    if (state.openTable && fouls.length === 0) {
      const solids = objectPocketed.filter(isSolid).length;
      const stripes = objectPocketed.filter(isStripe).length;
      if (solids + stripes > 0) {
        let g: PoolGroup;
        if (solids !== stripes) g = solids > stripes ? 'solids' : 'stripes';
        else g = groupOf(objectPocketed.find((id) => id !== EIGHT)!) as PoolGroup;
        me.group = g;
        opp.group = otherGroup(g);
        state.openTable = false;
        const byIndex: Record<string, PoolGroup> = {};
        for (const s of state.seats) byIndex[`seat${s.seat}`] = s.group!;
        events.push({ type: 'groups_assigned', seat, payload: { ...byIndex, assignedTo: seat, group: g } });
      }
    }

    if (fouls.length > 0) {
      this.giveBallInHand(state, opp.seat, sim.cueScratched, false, events);
      this.changeTurn(state, opp.seat, events);
      return;
    }
    const keeps = objectPocketed.some((id) => id !== EIGHT && (me.group === null || groupOf(id) === me.group));
    if (keeps) this.continueTurn(state, seat, events);
    else this.changeTurn(state, opp.seat, events);
  }

  private respotEight(state: PoolState, events: GameEvent[]): void {
    const eight = state.balls.find((b) => b.id === EIGHT)!;
    const others = this.onTable(state).filter((b) => b.id !== EIGHT);
    const spot = nearestFreeSpot(FOOT_SPOT.x, FOOT_SPOT.y, others, true);
    eight.pocketed = false;
    eight.x = round3(spot.x);
    eight.y = round3(spot.y);
    events.push({ type: 'eight_respotted', payload: { x: eight.x, y: eight.y } });
  }

  private giveBallInHand(state: PoolState, seat: number, cueScratched: boolean, behindHeadString: boolean, events: GameEvent[]): void {
    state.ballInHand = true;
    state.cueBehindHeadString = behindHeadString;
    const cue = this.cueBall(state);
    if (cueScratched || cue.pocketed) {
      const others = this.onTable(state).filter((b) => b.id !== CUE);
      const spot = nearestFreeSpot(HEAD_SPOT.x, HEAD_SPOT.y, others, false);
      cue.pocketed = false;
      cue.x = round3(behindHeadString ? Math.min(spot.x, HEAD_STRING_X) : spot.x);
      cue.y = round3(spot.y);
    }
    events.push({ type: 'ball_in_hand', seat, payload: { behindHeadString, x: cue.x, y: cue.y } });
  }

  private continueTurn(state: PoolState, seat: number, events: GameEvent[]): void {
    this.resetTurnClock(state);
    events.push({ type: 'continue_turn', seat, payload: { deadline: state.turnDeadline } });
  }

  private changeTurn(state: PoolState, seat: number, events: GameEvent[]): void {
    if (state.phase === 'finished') return;
    state.turnSeat = seat;
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat, payload: { deadline: state.turnDeadline, ballInHand: state.ballInHand } });
  }

  private resetTurnClock(state: PoolState): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  private finish(state: PoolState, winnerSeat: number, reason: string, events: GameEvent[]): void {
    const loser = this.opponentOf(state, winnerSeat);
    state.phase = 'finished';
    state.winnerSeat = winnerSeat;
    state.finishReason = reason;
    state.placements = [winnerSeat, loser.seat];
    state.ballInHand = false;
    state.turnDeadline = null;
    state.lastEvent = 'match_finished';
    events.push({ type: 'match_finished', seat: winnerSeat, payload: { placements: [...state.placements], reason, winnerSeat } });
  }

  // ---------------------------------------------------------------------------
  // Timeouts and leaving
  // ---------------------------------------------------------------------------

  /** A weak, roughly aimed shot at the nearest legal target; used when the shooter idles. */
  autoShot(state: PoolState, seat: number, rng: Rng | null): Extract<PoolAction, { type: 'shot' }> {
    const cue = this.cueBall(state);
    const targets = this.legalFirstContacts(state, seat);
    const live = this.onTable(state);
    let best: PoolBall | null = null;
    let bestD = Infinity;
    for (const id of targets) {
      const b = live.find((x) => x.id === id);
      if (!b) continue;
      const d = (b.x - cue.x) ** 2 + (b.y - cue.y) ** 2;
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    let angle = best ? Math.atan2(best.y - cue.y, best.x - cue.x) : 0;
    // Enough pace to reach the target and still drive something to a rail, never a slam.
    let power = clamp(0.22 + Math.sqrt(bestD === Infinity ? 0 : bestD) / 220, 0.25, 0.7);
    if (rng) {
      angle += (rng.float() - 0.5) * 0.06;
      power = clamp(power + (rng.float() - 0.5) * 0.1, 0.2, 0.8);
    }
    return { type: 'shot', angle: round3(angle), power: round3(power) };
  }

  onTimeout(state: PoolState, rng: Rng): EngineStep<PoolState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: PoolState = structuredClone(state);
    const events: GameEvent[] = [];
    const seat = next.turnSeat;
    const me = this.seatState(next, seat);
    me.consecutiveTimeouts += 1;
    events.push({ type: 'turn_timeout', seat, payload: { count: me.consecutiveTimeouts } });
    if (me.consecutiveTimeouts >= next.rules.timeoutsToForfeit) {
      me.forfeited = true;
      events.push({ type: 'player_forfeited', seat, payload: { reason: 'timeouts' } });
      this.finish(next, this.opponentOf(next, seat).seat, 'forfeit', events);
      next.version += 1;
      return { state: next, events };
    }
    this.resolveShot(next, seat, this.autoShot(next, seat, rng), events);
    next.version += 1;
    return { state: next, events };
  }

  onPlayerLeft(state: PoolState, seat: number, _rng: Rng): EngineStep<PoolState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: PoolState = structuredClone(state);
    const events: GameEvent[] = [];
    const me = this.seatState(next, seat);
    if (me.forfeited) return { state, events: [] };
    me.forfeited = true;
    me.connected = false;
    events.push({ type: 'player_forfeited', seat, payload: { reason: 'left' } });
    this.finish(next, this.opponentOf(next, seat).seat, 'forfeit', events);
    next.version += 1;
    return { state: next, events };
  }

  // ---------------------------------------------------------------------------
  // Result and view
  // ---------------------------------------------------------------------------

  getResult(state: PoolState): MatchResult {
    const finished = state.phase === 'finished';
    const scoreOf = (s: PoolSeatState) => (s.group ? 7 - this.remainingOf(state, s.group) : 0) + (state.winnerSeat === s.seat ? 1 : 0);
    const placements = state.seats
      .map((s) => ({
        seat: s.seat,
        placement: finished ? state.placements.indexOf(s.seat) + 1 : 1,
        score: scoreOf(s),
      }))
      .sort((a, b) => a.placement - b.placement);
    return { finished, placements, winnerSeats: finished && state.winnerSeat !== null ? [state.winnerSeat] : [] };
  }

  /** Pool has no hidden information; the full state is the view. */
  getView(state: PoolState, _viewerSeat: number | null): PoolState {
    return state;
  }
}

/**
 * Rack: 1 on the apex, 8 in the middle of the third row, one solid and one stripe on the
 * back corners, the rest shuffled with the match rng. Cue ball on the head spot.
 */
export function rackBalls(rng: Rng): PoolBall[] {
  const slots = rackSlots();
  const solids = [2, 3, 4, 5, 6, 7];
  const stripes = [9, 10, 11, 12, 13, 14, 15];
  const cornerSolid = solids.splice(rng.int(0, solids.length - 1), 1)[0]!;
  const cornerStripe = stripes.splice(rng.int(0, stripes.length - 1), 1)[0]!;
  const rest = [...solids, ...stripes];
  for (let i = rest.length - 1; i > 0; i--) {
    const j = rng.int(0, i);
    const tmp = rest[i]!;
    rest[i] = rest[j]!;
    rest[j] = tmp;
  }
  const bySlot = new Map<number, number>();
  bySlot.set(RACK_APEX_SLOT, 1);
  bySlot.set(RACK_EIGHT_SLOT, EIGHT);
  bySlot.set(RACK_BACK_CORNERS[0], cornerSolid);
  bySlot.set(RACK_BACK_CORNERS[1], cornerStripe);
  let k = 0;
  for (let s = 0; s < slots.length; s++) {
    if (bySlot.has(s)) continue;
    bySlot.set(s, rest[k++]!);
  }
  const balls: PoolBall[] = [{ id: CUE, x: HEAD_SPOT.x, y: HEAD_SPOT.y, pocketed: false }];
  for (let s = 0; s < slots.length; s++) {
    balls.push({ id: bySlot.get(s)!, x: slots[s]!.x, y: slots[s]!.y, pocketed: false });
  }
  balls.sort((a, b) => a.id - b.id);
  return balls;
}

export { BALL_RADIUS };
