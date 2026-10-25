import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import { resolveConnect4Rules, type Connect4Rules } from './rules.js';

export type Connect4Action = { type: 'drop'; column: number };

export interface Connect4SeatState {
  seat: number;
  userId: string;
  displayName: string;
  consecutiveTimeouts: number;
  forfeited: boolean;
  connected: boolean;
}

export interface Cell {
  row: number;
  col: number;
}

export const EMPTY = -1;

export interface Connect4State {
  rules: Connect4Rules;
  seats: Connect4SeatState[];
  /**
   * grid[row][col] holds the seat index of the disc or EMPTY (-1).
   * Row 0 is the BOTTOM row (gravity pulls towards row 0); row rows-1 is the top.
   */
  grid: number[][];
  turnSeat: number;
  phase: 'play' | 'finished';
  /** Columns that still have room, precomputed for the client. */
  legalColumns: number[];
  moveCount: number;
  lastDrop: { column: number; row: number; seat: number } | null;
  winnerSeat: number | null;
  winLine: Cell[] | null;
  draw: boolean;
  /** Seat order of finishing; winner first. */
  placements: number[];
  /** Monotonic state version, incremented on every applied step. */
  version: number;
  turnStartedAt: number;
  turnDeadline: number | null;
  lastEvent: string | null;
}

const NOW = () => Date.now();

/** Four directions covering horizontal, vertical and both diagonals. */
const DIRECTIONS: ReadonlyArray<readonly [number, number]> = [
  [0, 1], // horizontal (along columns)
  [1, 0], // vertical (along rows)
  [1, 1], // diagonal up-right
  [1, -1], // diagonal up-left
];

export function emptyGrid(rows: number, columns: number): number[][] {
  return Array.from({ length: rows }, () => Array.from({ length: columns }, () => EMPTY));
}

/** Lowest empty row in a column, or -1 when full. */
export function landingRow(grid: number[][], column: number): number {
  for (let r = 0; r < grid.length; r++) {
    if (grid[r]![column] === EMPTY) return r;
  }
  return -1;
}

export function legalColumnsOf(grid: number[][]): number[] {
  const cols = grid[0]?.length ?? 0;
  const out: number[] = [];
  for (let c = 0; c < cols; c++) if (landingRow(grid, c) >= 0) out.push(c);
  return out;
}

export function isGridFull(grid: number[][]): boolean {
  return legalColumnsOf(grid).length === 0;
}

/**
 * Checks whether the disc at (row, col) completes a line of `connect` discs of the
 * same seat. Returns the line (ordered from the lowest-left end) or null. When a
 * line is longer than `connect`, the first `connect` cells are returned.
 */
export function findWinningLine(grid: number[][], row: number, col: number, connect: number): Cell[] | null {
  const rows = grid.length;
  const cols = grid[0]?.length ?? 0;
  const seat = grid[row]?.[col];
  if (seat === undefined || seat === EMPTY) return null;
  for (const [dr, dc] of DIRECTIONS) {
    const line: Cell[] = [{ row, col }];
    // extend backwards
    let r = row - dr;
    let c = col - dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && grid[r]![c] === seat) {
      line.unshift({ row: r, col: c });
      r -= dr;
      c -= dc;
    }
    // extend forwards
    r = row + dr;
    c = col + dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && grid[r]![c] === seat) {
      line.push({ row: r, col: c });
      r += dr;
      c += dc;
    }
    if (line.length >= connect) return line.slice(0, connect);
  }
  return null;
}

/** Scans the entire grid for any winning line (used for fixtures / parity). */
export function findAnyWin(grid: number[][], connect: number): { seat: number; line: Cell[] } | null {
  for (let r = 0; r < grid.length; r++) {
    for (let c = 0; c < (grid[r]?.length ?? 0); c++) {
      const seat = grid[r]![c]!;
      if (seat === EMPTY) continue;
      for (const [dr, dc] of DIRECTIONS) {
        const line: Cell[] = [];
        let rr = r;
        let cc = c;
        while (rr >= 0 && rr < grid.length && cc >= 0 && cc < grid[rr]!.length && grid[rr]![cc] === seat && line.length < connect) {
          line.push({ row: rr, col: cc });
          rr += dr;
          cc += dc;
        }
        if (line.length >= connect) return { seat, line };
      }
    }
  }
  return null;
}

export class Connect4Engine implements GameEngine<Connect4State, Connect4Action> {
  readonly gameId = 'connect4_galaxy';

  constructor(private readonly now: () => number = NOW) {}

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, rng: Rng): Connect4State {
    if (players.length !== 2) throw new Error('connect4 requires exactly 2 players');
    const rules = resolveConnect4Rules(rulesInput);
    const seats: Connect4SeatState[] = players.map((p) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      consecutiveTimeouts: 0,
      forfeited: false,
      connected: true,
    }));
    const first = rules.firstMove === 'seat0' ? seats[0]!.seat : seats[rng.int(0, seats.length - 1)]!.seat;
    const grid = emptyGrid(rules.rows, rules.columns);
    const t = this.now();
    return {
      rules,
      seats,
      grid,
      turnSeat: first,
      phase: 'play',
      legalColumns: legalColumnsOf(grid),
      moveCount: 0,
      lastDrop: null,
      winnerSeat: null,
      winLine: null,
      draw: false,
      placements: [],
      version: 0,
      turnStartedAt: t,
      turnDeadline: rules.turnTimeoutSeconds > 0 ? t + rules.turnTimeoutSeconds * 1000 : null,
      lastEvent: null,
    };
  }

  currentSeat(state: Connect4State): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  private seatState(state: Connect4State, seat: number): Connect4SeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  validateAction(state: Connect4State, seat: number, action: Connect4Action): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
    const me = state.seats.find((x) => x.seat === seat);
    if (!me) return { ok: false, code: 'unknown_seat', message: 'seat not in match' };
    if (me.forfeited) return { ok: false, code: 'inactive_seat', message: 'seat no longer active' };
    if (!action || action.type !== 'drop') return { ok: false, code: 'bad_action', message: 'unknown action' };
    if (!Number.isInteger(action.column) || action.column < 0 || action.column >= state.rules.columns) {
      return { ok: false, code: 'bad_column', message: 'column out of range' };
    }
    if (landingRow(state.grid, action.column) < 0) return { ok: false, code: 'column_full', message: 'column is full' };
    return { ok: true };
  }

  getLegalActions(state: Connect4State, seat: number): Connect4Action[] {
    if (state.phase === 'finished' || state.turnSeat !== seat) return [];
    return state.legalColumns.map((column) => ({ type: 'drop', column }));
  }

  applyAction(state: Connect4State, seat: number, action: Connect4Action, _rng: Rng): EngineStep<Connect4State> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: Connect4State = structuredClone(state);
    const events: GameEvent[] = [];
    this.doDrop(next, seat, action.column, events, false);
    next.version += 1;
    return { state: next, events };
  }

  private doDrop(state: Connect4State, seat: number, column: number, events: GameEvent[], auto: boolean): void {
    const row = landingRow(state.grid, column);
    if (row < 0) throw new Error('column_full');
    state.grid[row]![column] = seat;
    state.moveCount += 1;
    state.lastDrop = { column, row, seat };
    state.legalColumns = legalColumnsOf(state.grid);
    events.push({ type: 'disc_dropped', seat, payload: { column, row, seat, auto } });

    const line = findWinningLine(state.grid, row, column, state.rules.connect);
    if (line) {
      state.winnerSeat = seat;
      state.winLine = line;
      events.push({ type: 'win', seat, payload: { seat, line } });
      this.finish(state, events, [seat, ...state.seats.map((s) => s.seat).filter((s) => s !== seat)]);
      return;
    }
    if (isGridFull(state.grid)) {
      state.draw = true;
      events.push({ type: 'draw', payload: { moveCount: state.moveCount } });
      // Draw: both seats share first place; keep seat order for determinism.
      this.finish(state, events, state.seats.map((s) => s.seat));
      return;
    }
    this.advanceTurn(state, events);
  }

  private finish(state: Connect4State, events: GameEvent[], placements: number[]): void {
    state.placements = placements;
    state.phase = 'finished';
    state.turnDeadline = null;
    state.lastEvent = 'match_finished';
    events.push({ type: 'match_finished', payload: { placements: [...placements], draw: state.draw, winnerSeat: state.winnerSeat } });
  }

  private advanceTurn(state: Connect4State, events: GameEvent[]): void {
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
    this.resetTurnClock(state);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline } });
  }

  private resetTurnClock(state: Connect4State): void {
    const t = this.now();
    state.turnStartedAt = t;
    state.turnDeadline = state.rules.turnTimeoutSeconds > 0 ? t + state.rules.turnTimeoutSeconds * 1000 : null;
  }

  onTimeout(state: Connect4State, rng: Rng): EngineStep<Connect4State> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: Connect4State = structuredClone(state);
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
    const legal = legalColumnsOf(next.grid);
    const column = legal[rng.int(0, legal.length - 1)]!;
    this.doDrop(next, seat, column, events, true);
    next.version += 1;
    return { state: next, events };
  }

  private forfeit(state: Connect4State, seat: number, reason: string, events: GameEvent[]): void {
    const me = this.seatState(state, seat);
    me.forfeited = true;
    events.push({ type: 'player_forfeited', seat, payload: { reason } });
    const remaining = state.seats.filter((s) => !s.forfeited);
    if (remaining.length <= 1) {
      const winner = remaining[0]?.seat ?? null;
      state.winnerSeat = winner;
      const order = winner === null ? state.seats.map((s) => s.seat) : [winner, ...state.seats.map((s) => s.seat).filter((s) => s !== winner)];
      this.finish(state, events, order);
      return;
    }
    if (state.turnSeat === seat) this.advanceTurn(state, events);
  }

  onPlayerLeft(state: Connect4State, seat: number, _rng: Rng): EngineStep<Connect4State> {
    if (state.phase === 'finished') return { state, events: [] };
    const me = state.seats.find((s) => s.seat === seat);
    if (!me || me.forfeited) return { state, events: [] };
    const next: Connect4State = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).connected = false;
    this.forfeit(next, seat, 'left', events);
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: Connect4State): MatchResult {
    const finished = state.phase === 'finished';
    if (!finished) {
      return { finished, placements: state.seats.map((s) => ({ seat: s.seat, placement: 1, score: this.discCount(state, s.seat) })), winnerSeats: [] };
    }
    const placements = state.placements.map((seat, i) => ({
      seat,
      placement: state.draw ? 1 : i + 1,
      score: this.discCount(state, seat) + (state.winnerSeat === seat ? 100 : 0),
    }));
    const winnerSeats = state.draw ? [...state.placements] : state.winnerSeat !== null ? [state.winnerSeat] : [];
    return { finished, placements, winnerSeats };
  }

  private discCount(state: Connect4State, seat: number): number {
    let n = 0;
    for (const row of state.grid) for (const v of row) if (v === seat) n++;
    return n;
  }

  /** No hidden information: the full state is the view. */
  getView(state: Connect4State, _viewerSeat: number | null): Connect4State {
    return state;
  }
}
