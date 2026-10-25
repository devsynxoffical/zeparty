import type { EngineStep, GameEngine, GameEvent, MatchResult, PlayerSeat, Rng, Validation } from '../engine.js';
import {
  START_FEN,
  type Color,
  type Move,
  type PieceType,
  type Position,
  findMove,
  fromAlgebraic,
  generateLegalMoves,
  hasMatingMaterial,
  inCheck,
  insufficientMaterial,
  legalMoveMap,
  makeMove,
  parseFen,
  repetitionKey,
  toAlgebraic,
  toCoord,
  toFen,
  toSan,
} from './chess.js';
import { resolveChessRules, type ChessRules } from './rules.js';

export type ChessAction =
  | { type: 'move'; from: string; to: string; promotion?: 'q' | 'r' | 'b' | 'n' }
  | { type: 'resign' }
  | { type: 'offer_draw' }
  | { type: 'accept_draw' }
  | { type: 'decline_draw' };

export interface ChessSeatState {
  seat: number;
  userId: string;
  displayName: string;
  color: Color;
  connected: boolean;
}

export interface ChessMoveRecord {
  /** Half-move index starting at 0 (white's first move). */
  ply: number;
  color: Color;
  san: string;
  /** Coordinate form, e.g. e2e4 or e7e8q. */
  uci: string;
  from: string;
  to: string;
  piece: PieceType;
  captured?: PieceType;
  promotion?: PieceType;
  castle?: 'K' | 'Q';
  enPassant?: boolean;
  check: boolean;
  checkmate: boolean;
}

export type ChessOutcome = 'white' | 'black' | 'draw';
export type ChessEndReason =
  | 'checkmate'
  | 'stalemate'
  | 'resignation'
  | 'timeout'
  | 'agreement'
  | 'fifty_move'
  | 'threefold_repetition'
  | 'insufficient_material'
  | 'abandoned';

export interface ChessState {
  rules: ChessRules;
  seats: ChessSeatState[];
  /** Full FEN of the current position (authoritative board). */
  fen: string;
  /** Side to move. */
  turn: Color;
  turnSeat: number;
  phase: 'playing' | 'finished';
  /** Remaining time per colour in ms. Static when clocks are disabled. */
  clocks: { w: number; b: number };
  /** When the side to move started thinking (epoch ms). */
  turnStartedAt: number;
  /** Flag-fall time of the side to move; null when clocks are disabled or finished. */
  turnDeadline: number | null;
  moves: ChessMoveRecord[];
  /** SAN history, one entry per ply. */
  san: string[];
  /** Coordinate history, one entry per ply. */
  uci: string[];
  /** Pieces captured by each colour (piece types of the victims). */
  captured: { w: PieceType[]; b: PieceType[] };
  /** Is the side to move in check? */
  check: boolean;
  lastMove: { from: string; to: string } | null;
  /** Seat with a pending draw offer, or null. */
  drawOffer: number | null;
  /** Occurrence count per repetition key. */
  repetition: Record<string, number>;
  result: { outcome: ChessOutcome; reason: ChessEndReason; winnerSeat: number | null } | null;
  placements: number[];
  version: number;
}

export interface ChessView extends ChessState {
  /** Only present for the side to move while the game is running. */
  legalMoves?: Record<string, string[]>;
}

const NOW = () => Date.now();
const PROMO: ReadonlyArray<PieceType> = ['q', 'r', 'b', 'n'];

export class ChessEngine implements GameEngine<ChessState, ChessAction> {
  readonly gameId = 'chess_legends';

  constructor(private readonly now: () => number = NOW) {}

  createInitialState(players: PlayerSeat[], rulesInput: Record<string, unknown>, _rng: Rng): ChessState {
    if (players.length !== 2) throw new Error('chess requires exactly 2 players');
    const rules = resolveChessRules(rulesInput);
    const sorted = [...players].sort((a, b) => a.seat - b.seat);
    const seats: ChessSeatState[] = sorted.map((p, i) => ({
      seat: p.seat,
      userId: p.userId,
      displayName: p.displayName,
      color: i === 0 ? 'w' : 'b',
      connected: true,
    }));
    const t = this.now();
    const ms = rules.initialSeconds * 1000;
    const pos = parseFen(START_FEN);
    const state: ChessState = {
      rules,
      seats,
      fen: START_FEN,
      turn: 'w',
      turnSeat: seats[0]!.seat,
      phase: 'playing',
      clocks: { w: ms, b: ms },
      turnStartedAt: t,
      turnDeadline: rules.clockEnabled ? t + ms : null,
      moves: [],
      san: [],
      uci: [],
      captured: { w: [], b: [] },
      check: false,
      lastMove: null,
      drawOffer: null,
      repetition: { [repetitionKey(pos)]: 1 },
      result: null,
      placements: [],
      version: 0,
    };
    return state;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  seatFor(state: ChessState, color: Color): ChessSeatState {
    return state.seats.find((s) => s.color === color)!;
  }

  private seatState(state: ChessState, seat: number): ChessSeatState {
    const s = state.seats.find((x) => x.seat === seat);
    if (!s) throw new Error(`unknown seat ${seat}`);
    return s;
  }

  currentSeat(state: ChessState): number | null {
    return state.phase === 'finished' ? null : state.turnSeat;
  }

  position(state: ChessState): Position {
    return parseFen(state.fen);
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  validateAction(state: ChessState, seat: number, action: ChessAction): Validation {
    if (state.phase === 'finished') return { ok: false, code: 'match_finished', message: 'match is over' };
    if (!state.seats.some((s) => s.seat === seat)) return { ok: false, code: 'bad_seat', message: 'not a player' };
    if (!action || typeof action !== 'object') return { ok: false, code: 'bad_action', message: 'unknown action' };
    switch (action.type) {
      case 'move': {
        if (state.turnSeat !== seat) return { ok: false, code: 'not_your_turn', message: 'not your turn' };
        const from = fromAlgebraic(action.from);
        const to = fromAlgebraic(action.to);
        if (from < 0 || to < 0) return { ok: false, code: 'bad_square', message: 'squares must be a1..h8' };
        if (action.promotion !== undefined && !PROMO.includes(action.promotion)) {
          return { ok: false, code: 'bad_promotion', message: 'promotion must be q, r, b or n' };
        }
        const legal = generateLegalMoves(this.position(state));
        if (!findMove(legal, from, to, action.promotion)) return { ok: false, code: 'illegal_move', message: 'illegal move' };
        return { ok: true };
      }
      case 'resign':
        return { ok: true };
      case 'offer_draw':
        if (state.drawOffer !== null) return { ok: false, code: 'offer_pending', message: 'a draw offer is already pending' };
        return { ok: true };
      case 'accept_draw':
      case 'decline_draw':
        if (state.drawOffer === null) return { ok: false, code: 'no_offer', message: 'no draw offer to answer' };
        if (state.drawOffer === seat) return { ok: false, code: 'own_offer', message: 'cannot answer your own offer' };
        return { ok: true };
      default:
        return { ok: false, code: 'bad_action', message: 'unknown action' };
    }
  }

  getLegalActions(state: ChessState, seat: number): ChessAction[] {
    if (state.phase === 'finished' || !state.seats.some((s) => s.seat === seat)) return [];
    const out: ChessAction[] = [];
    if (state.turnSeat === seat) {
      for (const m of generateLegalMoves(this.position(state))) {
        const a: ChessAction = { type: 'move', from: toAlgebraic(m.from), to: toAlgebraic(m.to) };
        if (m.promotion) a.promotion = m.promotion as 'q' | 'r' | 'b' | 'n';
        out.push(a);
      }
    }
    out.push({ type: 'resign' });
    if (state.drawOffer === null) out.push({ type: 'offer_draw' });
    else if (state.drawOffer !== seat) out.push({ type: 'accept_draw' }, { type: 'decline_draw' });
    return out;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  applyAction(state: ChessState, seat: number, action: ChessAction, _rng: Rng): EngineStep<ChessState> {
    const v = this.validateAction(state, seat, action);
    if (!v.ok) throw new Error(`${v.code}: ${v.message}`);
    const next: ChessState = structuredClone(state);
    const events: GameEvent[] = [];
    switch (action.type) {
      case 'move':
        this.doMove(next, seat, action, events);
        break;
      case 'resign':
        this.finish(next, events, { outcome: this.seatState(next, seat).color === 'w' ? 'black' : 'white', reason: 'resignation' }, [{ type: 'resigned', seat, payload: { seat } }]);
        break;
      case 'offer_draw':
        next.drawOffer = seat;
        events.push({ type: 'draw_offered', seat, payload: { seat } });
        break;
      case 'accept_draw':
        this.finish(next, events, { outcome: 'draw', reason: 'agreement' }, [{ type: 'draw_accepted', seat, payload: { seat } }]);
        break;
      case 'decline_draw':
        next.drawOffer = null;
        events.push({ type: 'draw_declined', seat, payload: { seat } });
        break;
    }
    next.version += 1;
    return { state: next, events };
  }

  /** Clock bookkeeping for the side that just completed its move. Returns false if its flag fell. */
  private chargeClock(state: ChessState, color: Color, now: number): boolean {
    if (!state.rules.clockEnabled) return true;
    const spent = Math.max(0, now - state.turnStartedAt);
    const remaining = state.clocks[color] - spent;
    if (remaining <= 0) {
      state.clocks[color] = 0;
      return false;
    }
    state.clocks[color] = remaining + state.rules.incrementSeconds * 1000;
    return true;
  }

  private startTurn(state: ChessState, now: number): void {
    state.turnStartedAt = now;
    state.turnDeadline = state.rules.clockEnabled && state.phase === 'playing' ? now + state.clocks[state.turn] : null;
  }

  private doMove(state: ChessState, seat: number, action: Extract<ChessAction, { type: 'move' }>, events: GameEvent[]): void {
    const now = this.now();
    const mover = this.seatState(state, seat);
    const color = mover.color;
    if (!this.chargeClock(state, color, now)) {
      // The move arrived after the flag fell: adjudicate exactly like onTimeout.
      this.flagFall(state, events, color);
      return;
    }
    const pos = this.position(state);
    const legal = generateLegalMoves(pos);
    const m: Move = findMove(legal, fromAlgebraic(action.from), fromAlgebraic(action.to), action.promotion)!;
    const san = toSan(pos, m, legal);
    const nextPos = makeMove(pos, m);
    const check = inCheck(nextPos);
    const opponentMoves = generateLegalMoves(nextPos);
    const checkmate = check && opponentMoves.length === 0;
    const stalemate = !check && opponentMoves.length === 0;

    const record: ChessMoveRecord = {
      ply: state.moves.length,
      color,
      san,
      uci: toCoord(m),
      from: toAlgebraic(m.from),
      to: toAlgebraic(m.to),
      piece: m.piece,
      check,
      checkmate,
    };
    if (m.captured) record.captured = m.captured;
    if (m.promotion) record.promotion = m.promotion;
    if (m.castle) record.castle = m.castle;
    if (m.enPassant) record.enPassant = true;

    state.fen = toFen(nextPos);
    state.turn = nextPos.turn;
    state.turnSeat = this.seatFor(state, nextPos.turn).seat;
    state.moves.push(record);
    state.san.push(san);
    state.uci.push(record.uci);
    if (m.captured) state.captured[color].push(m.captured);
    state.check = check;
    state.lastMove = { from: record.from, to: record.to };
    // Making a move silently declines any pending offer from the opponent and withdraws your own.
    state.drawOffer = null;
    const key = repetitionKey(nextPos);
    const count = (state.repetition[key] ?? 0) + 1;
    state.repetition[key] = count;

    const payload: Record<string, unknown> = { from: record.from, to: record.to, san, piece: m.piece, check, checkmate };
    if (m.captured) payload['captured'] = m.captured;
    if (m.promotion) payload['promotion'] = m.promotion;
    if (m.castle) payload['castle'] = m.castle;
    if (m.enPassant) payload['enPassant'] = true;
    events.push({ type: 'move', seat, payload });

    const winner = color === 'w' ? 'white' : 'black';
    if (checkmate) {
      this.finish(state, events, { outcome: winner, reason: 'checkmate' }, [{ type: 'checkmate', seat, payload: { winnerSeat: seat } }]);
      return;
    }
    if (check) events.push({ type: 'check', seat: state.turnSeat, payload: { kingSeat: state.turnSeat } });
    if (stalemate) {
      this.finish(state, events, { outcome: 'draw', reason: 'stalemate' }, [{ type: 'stalemate', payload: {} }]);
      return;
    }
    if (insufficientMaterial(nextPos)) {
      this.finish(state, events, { outcome: 'draw', reason: 'insufficient_material' });
      return;
    }
    if (count >= 3) {
      this.finish(state, events, { outcome: 'draw', reason: 'threefold_repetition' });
      return;
    }
    if (nextPos.halfmove >= 100) {
      this.finish(state, events, { outcome: 'draw', reason: 'fifty_move' });
      return;
    }
    this.startTurn(state, now);
    events.push({ type: 'turn_changed', seat: state.turnSeat, payload: { deadline: state.turnDeadline, clocks: { ...state.clocks } } });
  }

  private flagFall(state: ChessState, events: GameEvent[], color: Color): void {
    const flagged = this.seatFor(state, color);
    const opp: Color = color === 'w' ? 'b' : 'w';
    state.clocks[color] = 0;
    const pos = this.position(state);
    const outcome: ChessOutcome = hasMatingMaterial(pos, opp) ? (opp === 'w' ? 'white' : 'black') : 'draw';
    this.finish(state, events, { outcome, reason: 'timeout' }, [{ type: 'flag_fell', seat: flagged.seat, payload: { seat: flagged.seat } }]);
  }

  private finish(state: ChessState, events: GameEvent[], result: { outcome: ChessOutcome; reason: ChessEndReason }, lead: GameEvent[] = []): void {
    const white = this.seatFor(state, 'w');
    const black = this.seatFor(state, 'b');
    const winnerSeat = result.outcome === 'white' ? white.seat : result.outcome === 'black' ? black.seat : null;
    state.result = { ...result, winnerSeat };
    state.phase = 'finished';
    state.turnDeadline = null;
    state.drawOffer = null;
    state.placements = winnerSeat === null ? [white.seat, black.seat] : [winnerSeat, winnerSeat === white.seat ? black.seat : white.seat];
    events.push(...lead);
    if (result.outcome === 'draw') events.push({ type: 'draw', payload: { reason: result.reason } });
    events.push({ type: 'match_finished', payload: { placements: [...state.placements], outcome: result.outcome, reason: result.reason, winnerSeat } });
  }

  // ---------------------------------------------------------------------------
  // Room hooks
  // ---------------------------------------------------------------------------

  /** The side to move ran out of time. */
  onTimeout(state: ChessState, _rng: Rng): EngineStep<ChessState> {
    if (state.phase === 'finished') return { state, events: [] };
    const next: ChessState = structuredClone(state);
    const events: GameEvent[] = [];
    this.flagFall(next, events, next.turn);
    next.version += 1;
    return { state: next, events };
  }

  onPlayerLeft(state: ChessState, seat: number, _rng: Rng): EngineStep<ChessState> {
    if (state.phase === 'finished') return { state, events: [] };
    const me = state.seats.find((s) => s.seat === seat);
    if (!me) return { state, events: [] };
    const next: ChessState = structuredClone(state);
    const events: GameEvent[] = [];
    this.seatState(next, seat).connected = false;
    this.finish(next, events, { outcome: me.color === 'w' ? 'black' : 'white', reason: 'abandoned' }, [{ type: 'resigned', seat, payload: { seat, reason: 'left' } }]);
    next.version += 1;
    return { state: next, events };
  }

  getResult(state: ChessState): MatchResult {
    const finished = state.phase === 'finished';
    const r = state.result;
    const placements = state.seats
      .map((s) => {
        const won = r?.winnerSeat === s.seat;
        const draw = r?.outcome === 'draw';
        return { seat: s.seat, placement: draw || won ? 1 : finished ? 2 : 1, score: won ? 2 : draw ? 1 : 0 };
      })
      .sort((a, b) => a.placement - b.placement || a.seat - b.seat);
    return { finished, placements, winnerSeats: finished && r?.winnerSeat !== null && r?.winnerSeat !== undefined ? [r.winnerSeat] : [] };
  }

  /** Chess has no hidden information. The side to move additionally receives its legal moves. */
  getView(state: ChessState, viewerSeat: number | null): ChessView {
    if (viewerSeat === null || state.phase === 'finished' || state.turnSeat !== viewerSeat) return state;
    return { ...state, legalMoves: legalMoveMap(this.position(state)) };
  }
}
