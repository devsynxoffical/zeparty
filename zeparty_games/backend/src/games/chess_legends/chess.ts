/**
 * Self-contained chess rules engine (no dependencies). 0x88 board representation,
 * pseudo-legal generation filtered by king safety, full special-move support
 * (castling, en passant, promotion), SAN, FEN, repetition keys, material checks
 * and perft for verification.
 *
 * Squares are 0x88 indices: sq = rank * 16 + file, rank 0 = first rank (white side).
 */

export type Color = 'w' | 'b';
export type PieceType = 'p' | 'n' | 'b' | 'r' | 'q' | 'k';

export interface Move {
  from: number;
  to: number;
  piece: PieceType;
  color: Color;
  captured?: PieceType;
  promotion?: PieceType;
  castle?: 'K' | 'Q';
  enPassant?: boolean;
  doublePush?: boolean;
}

export interface Position {
  /** 128 entries, FEN piece letters (uppercase white) or null. Off-board squares unused. */
  board: (string | null)[];
  turn: Color;
  /** Bit mask: 1 = K, 2 = Q, 4 = k, 8 = q. */
  castling: number;
  /** En passant target square (0x88) or -1. */
  ep: number;
  halfmove: number;
  fullmove: number;
}

export const CASTLE_WK = 1;
export const CASTLE_WQ = 2;
export const CASTLE_BK = 4;
export const CASTLE_BQ = 8;

export const START_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const FILES = 'abcdefgh';

export function sq(file: number, rank: number): number {
  return rank * 16 + file;
}
export function fileOf(s: number): number {
  return s & 7;
}
export function rankOf(s: number): number {
  return s >> 4;
}
export function onBoard(s: number): boolean {
  return (s & 0x88) === 0;
}
export function toAlgebraic(s: number): string {
  return `${FILES[fileOf(s)]}${rankOf(s) + 1}`;
}
export function fromAlgebraic(a: string): number {
  if (typeof a !== 'string' || a.length !== 2) return -1;
  const f = FILES.indexOf(a[0]!);
  const r = a.charCodeAt(1) - 49;
  if (f < 0 || r < 0 || r > 7) return -1;
  return sq(f, r);
}
export function colorOf(ch: string): Color {
  return ch === ch.toUpperCase() ? 'w' : 'b';
}
export function typeOf(ch: string): PieceType {
  return ch.toLowerCase() as PieceType;
}
export function pieceChar(type: PieceType, color: Color): string {
  return color === 'w' ? type.toUpperCase() : type;
}
export function opposite(c: Color): Color {
  return c === 'w' ? 'b' : 'w';
}

const KNIGHT_DELTAS = [-33, -31, -18, -14, 14, 18, 31, 33];
const KING_DELTAS = [-17, -16, -15, -1, 1, 15, 16, 17];
const BISHOP_DELTAS = [-17, -15, 15, 17];
const ROOK_DELTAS = [-16, -1, 1, 16];

// ---------------------------------------------------------------------------
// FEN
// ---------------------------------------------------------------------------

export function parseFen(fen: string): Position {
  const parts = fen.trim().split(/\s+/);
  if (parts.length < 4) throw new Error(`bad fen: ${fen}`);
  const [placement, turn, castling, ep, half, full] = parts;
  const board: (string | null)[] = new Array<string | null>(128).fill(null);
  const ranks = placement!.split('/');
  if (ranks.length !== 8) throw new Error(`bad fen placement: ${fen}`);
  for (let r = 0; r < 8; r++) {
    const rank = 7 - r;
    let file = 0;
    for (const ch of ranks[r]!) {
      if (ch >= '1' && ch <= '8') {
        file += Number(ch);
      } else {
        if (!'pnbrqkPNBRQK'.includes(ch) || file > 7) throw new Error(`bad fen placement: ${fen}`);
        board[sq(file, rank)] = ch;
        file++;
      }
    }
    if (file !== 8) throw new Error(`bad fen rank: ${ranks[r]}`);
  }
  let c = 0;
  if (castling && castling !== '-') {
    if (castling.includes('K')) c |= CASTLE_WK;
    if (castling.includes('Q')) c |= CASTLE_WQ;
    if (castling.includes('k')) c |= CASTLE_BK;
    if (castling.includes('q')) c |= CASTLE_BQ;
  }
  return {
    board,
    turn: turn === 'b' ? 'b' : 'w',
    castling: c,
    ep: ep && ep !== '-' ? fromAlgebraic(ep) : -1,
    halfmove: half ? Number(half) : 0,
    fullmove: full ? Number(full) : 1,
  };
}

export function placementString(pos: Position): string {
  const rows: string[] = [];
  for (let rank = 7; rank >= 0; rank--) {
    let row = '';
    let empty = 0;
    for (let file = 0; file < 8; file++) {
      const p = pos.board[sq(file, rank)];
      if (p) {
        if (empty) {
          row += empty;
          empty = 0;
        }
        row += p;
      } else empty++;
    }
    if (empty) row += empty;
    rows.push(row);
  }
  return rows.join('/');
}

export function castlingString(c: number): string {
  let s = '';
  if (c & CASTLE_WK) s += 'K';
  if (c & CASTLE_WQ) s += 'Q';
  if (c & CASTLE_BK) s += 'k';
  if (c & CASTLE_BQ) s += 'q';
  return s || '-';
}

export function toFen(pos: Position): string {
  return `${placementString(pos)} ${pos.turn} ${castlingString(pos.castling)} ${pos.ep >= 0 ? toAlgebraic(pos.ep) : '-'} ${pos.halfmove} ${pos.fullmove}`;
}

// ---------------------------------------------------------------------------
// Attacks
// ---------------------------------------------------------------------------

export function kingSquare(pos: Position, color: Color): number {
  const k = pieceChar('k', color);
  for (let s = 0; s < 128; s++) {
    if (onBoard(s) && pos.board[s] === k) return s;
  }
  return -1;
}

/** Is `square` attacked by any piece of `by`? */
export function isAttacked(pos: Position, square: number, by: Color): boolean {
  const b = pos.board;
  // Pawns: a white pawn attacks upward, so a square is attacked by white from below.
  const pawn = pieceChar('p', by);
  const pawnDir = by === 'w' ? -16 : 16;
  for (const d of [pawnDir - 1, pawnDir + 1]) {
    const s = square + d;
    if (onBoard(s) && b[s] === pawn) return true;
  }
  const knight = pieceChar('n', by);
  for (const d of KNIGHT_DELTAS) {
    const s = square + d;
    if (onBoard(s) && b[s] === knight) return true;
  }
  const king = pieceChar('k', by);
  for (const d of KING_DELTAS) {
    const s = square + d;
    if (onBoard(s) && b[s] === king) return true;
  }
  const bishop = pieceChar('b', by);
  const rook = pieceChar('r', by);
  const queen = pieceChar('q', by);
  for (const d of BISHOP_DELTAS) {
    let s = square + d;
    while (onBoard(s)) {
      const p = b[s];
      if (p) {
        if (p === bishop || p === queen) return true;
        break;
      }
      s += d;
    }
  }
  for (const d of ROOK_DELTAS) {
    let s = square + d;
    while (onBoard(s)) {
      const p = b[s];
      if (p) {
        if (p === rook || p === queen) return true;
        break;
      }
      s += d;
    }
  }
  return false;
}

export function inCheck(pos: Position, color: Color = pos.turn): boolean {
  const k = kingSquare(pos, color);
  return k >= 0 && isAttacked(pos, k, opposite(color));
}

// ---------------------------------------------------------------------------
// Move generation
// ---------------------------------------------------------------------------

const PROMOTIONS: PieceType[] = ['q', 'r', 'b', 'n'];

export function generatePseudoLegal(pos: Position): Move[] {
  const moves: Move[] = [];
  const us = pos.turn;
  const them = opposite(us);
  const b = pos.board;
  const push = (m: Move) => moves.push(m);

  for (let from = 0; from < 128; from++) {
    if (!onBoard(from)) continue;
    const p = b[from];
    if (!p || colorOf(p) !== us) continue;
    const type = typeOf(p);
    switch (type) {
      case 'p': {
        const dir = us === 'w' ? 16 : -16;
        const startRank = us === 'w' ? 1 : 6;
        const promoRank = us === 'w' ? 7 : 0;
        const one = from + dir;
        if (onBoard(one) && !b[one]) {
          if (rankOf(one) === promoRank) {
            for (const pr of PROMOTIONS) push({ from, to: one, piece: 'p', color: us, promotion: pr });
          } else {
            push({ from, to: one, piece: 'p', color: us });
            const two = from + dir * 2;
            if (rankOf(from) === startRank && !b[two]) push({ from, to: two, piece: 'p', color: us, doublePush: true });
          }
        }
        for (const d of [dir - 1, dir + 1]) {
          const to = from + d;
          if (!onBoard(to)) continue;
          const target = b[to];
          if (target && colorOf(target) === them) {
            if (rankOf(to) === promoRank) {
              for (const pr of PROMOTIONS) push({ from, to, piece: 'p', color: us, captured: typeOf(target), promotion: pr });
            } else push({ from, to, piece: 'p', color: us, captured: typeOf(target) });
          } else if (to === pos.ep && pos.ep >= 0) {
            push({ from, to, piece: 'p', color: us, captured: 'p', enPassant: true });
          }
        }
        break;
      }
      case 'n':
      case 'k': {
        const deltas = type === 'n' ? KNIGHT_DELTAS : KING_DELTAS;
        for (const d of deltas) {
          const to = from + d;
          if (!onBoard(to)) continue;
          const target = b[to];
          if (!target) push({ from, to, piece: type, color: us });
          else if (colorOf(target) === them) push({ from, to, piece: type, color: us, captured: typeOf(target) });
        }
        if (type === 'k') generateCastling(pos, from, moves);
        break;
      }
      case 'b':
      case 'r':
      case 'q': {
        const deltas = type === 'b' ? BISHOP_DELTAS : type === 'r' ? ROOK_DELTAS : [...BISHOP_DELTAS, ...ROOK_DELTAS];
        for (const d of deltas) {
          let to = from + d;
          while (onBoard(to)) {
            const target = b[to];
            if (!target) push({ from, to, piece: type, color: us });
            else {
              if (colorOf(target) === them) push({ from, to, piece: type, color: us, captured: typeOf(target) });
              break;
            }
            to += d;
          }
        }
        break;
      }
    }
  }
  return moves;
}

function generateCastling(pos: Position, kingSq: number, out: Move[]): void {
  const us = pos.turn;
  const them = opposite(us);
  const rank = us === 'w' ? 0 : 7;
  if (kingSq !== sq(4, rank)) return;
  const b = pos.board;
  const rook = pieceChar('r', us);
  const kingSide = us === 'w' ? CASTLE_WK : CASTLE_BK;
  const queenSide = us === 'w' ? CASTLE_WQ : CASTLE_BQ;
  // The king may not castle out of check.
  const inCheckNow = isAttacked(pos, kingSq, them);
  if (pos.castling & kingSide) {
    const f = sq(5, rank);
    const g = sq(6, rank);
    const h = sq(7, rank);
    if (!inCheckNow && b[h] === rook && !b[f] && !b[g] && !isAttacked(pos, f, them) && !isAttacked(pos, g, them)) {
      out.push({ from: kingSq, to: g, piece: 'k', color: us, castle: 'K' });
    }
  }
  if (pos.castling & queenSide) {
    const d = sq(3, rank);
    const c = sq(2, rank);
    const bq = sq(1, rank);
    const a = sq(0, rank);
    if (!inCheckNow && b[a] === rook && !b[d] && !b[c] && !b[bq] && !isAttacked(pos, d, them) && !isAttacked(pos, c, them)) {
      out.push({ from: kingSq, to: c, piece: 'k', color: us, castle: 'Q' });
    }
  }
}

/** Applies a move and returns the resulting position (input untouched). */
export function makeMove(pos: Position, m: Move): Position {
  const board = pos.board.slice();
  const us = m.color;
  const them = opposite(us);
  const moving = board[m.from]!;
  board[m.from] = null;
  board[m.to] = m.promotion ? pieceChar(m.promotion, us) : moving;
  if (m.enPassant) {
    const capSq = m.to + (us === 'w' ? -16 : 16);
    board[capSq] = null;
  }
  if (m.castle) {
    const rank = us === 'w' ? 0 : 7;
    const rookFrom = m.castle === 'K' ? sq(7, rank) : sq(0, rank);
    const rookTo = m.castle === 'K' ? sq(5, rank) : sq(3, rank);
    board[rookTo] = board[rookFrom]!;
    board[rookFrom] = null;
  }
  let castling = pos.castling;
  if (m.piece === 'k') castling &= us === 'w' ? ~(CASTLE_WK | CASTLE_WQ) : ~(CASTLE_BK | CASTLE_BQ);
  const clearRook = (s: number) => {
    if (s === sq(7, 0)) castling &= ~CASTLE_WK;
    else if (s === sq(0, 0)) castling &= ~CASTLE_WQ;
    else if (s === sq(7, 7)) castling &= ~CASTLE_BK;
    else if (s === sq(0, 7)) castling &= ~CASTLE_BQ;
  };
  if (m.piece === 'r') clearRook(m.from);
  if (m.captured === 'r' && !m.enPassant) clearRook(m.to);
  const ep = m.doublePush ? m.from + (us === 'w' ? 16 : -16) : -1;
  const halfmove = m.piece === 'p' || m.captured ? 0 : pos.halfmove + 1;
  return { board, turn: them, castling, ep, halfmove, fullmove: us === 'b' ? pos.fullmove + 1 : pos.fullmove };
}

export function generateLegalMoves(pos: Position): Move[] {
  const out: Move[] = [];
  for (const m of generatePseudoLegal(pos)) {
    const next = makeMove(pos, m);
    if (!inCheck(next, pos.turn)) out.push(m);
  }
  return out;
}

export function isCheckmate(pos: Position): boolean {
  return inCheck(pos) && generateLegalMoves(pos).length === 0;
}

export function isStalemate(pos: Position): boolean {
  return !inCheck(pos) && generateLegalMoves(pos).length === 0;
}

export function perft(pos: Position, depth: number): number {
  if (depth === 0) return 1;
  const moves = generateLegalMoves(pos);
  if (depth === 1) return moves.length;
  let n = 0;
  for (const m of moves) n += perft(makeMove(pos, m), depth - 1);
  return n;
}

// ---------------------------------------------------------------------------
// Material
// ---------------------------------------------------------------------------

interface MaterialCount {
  pawns: number;
  rooks: number;
  queens: number;
  knights: number;
  bishopsLight: number;
  bishopsDark: number;
}

export function countMaterial(pos: Position, color: Color): MaterialCount {
  const c: MaterialCount = { pawns: 0, rooks: 0, queens: 0, knights: 0, bishopsLight: 0, bishopsDark: 0 };
  for (let s = 0; s < 128; s++) {
    if (!onBoard(s)) continue;
    const p = pos.board[s];
    if (!p || colorOf(p) !== color) continue;
    switch (typeOf(p)) {
      case 'p':
        c.pawns++;
        break;
      case 'r':
        c.rooks++;
        break;
      case 'q':
        c.queens++;
        break;
      case 'n':
        c.knights++;
        break;
      case 'b':
        if ((fileOf(s) + rankOf(s)) % 2 === 0) c.bishopsDark++;
        else c.bishopsLight++;
        break;
      default:
        break;
    }
  }
  return c;
}

/**
 * Can `color` ever deliver mate on its own? False for a lone king, K+B and K+N.
 * Used for flag-fall adjudication: a flagged player only loses if the opponent could mate.
 */
export function hasMatingMaterial(pos: Position, color: Color): boolean {
  const c = countMaterial(pos, color);
  if (c.pawns || c.rooks || c.queens) return true;
  const minors = c.knights + c.bishopsLight + c.bishopsDark;
  if (minors >= 2) return true;
  return false;
}

/**
 * Dead positions that are an automatic draw: K v K, K+B v K, K+N v K and
 * bishops only where every bishop stands on the same square colour.
 */
export function insufficientMaterial(pos: Position): boolean {
  const w = countMaterial(pos, 'w');
  const b = countMaterial(pos, 'b');
  if (w.pawns || b.pawns || w.rooks || b.rooks || w.queens || b.queens) return false;
  const knights = w.knights + b.knights;
  const light = w.bishopsLight + b.bishopsLight;
  const dark = w.bishopsDark + b.bishopsDark;
  const minors = knights + light + dark;
  if (minors <= 1) return true;
  if (knights === 0 && (light === 0 || dark === 0)) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Repetition
// ---------------------------------------------------------------------------

/**
 * Key for threefold repetition: placement, side to move, castling rights and the
 * en passant square (only when an en passant capture is actually legal).
 */
export function repetitionKey(pos: Position): string {
  let ep = '-';
  if (pos.ep >= 0 && generateLegalMoves(pos).some((m) => m.enPassant)) ep = toAlgebraic(pos.ep);
  return `${placementString(pos)} ${pos.turn} ${castlingString(pos.castling)} ${ep}`;
}

// ---------------------------------------------------------------------------
// SAN
// ---------------------------------------------------------------------------

/** Standard algebraic notation for `m` in `pos`. `legal` may be passed to avoid regenerating. */
export function toSan(pos: Position, m: Move, legal: Move[] = generateLegalMoves(pos)): string {
  let san: string;
  if (m.castle) san = m.castle === 'K' ? 'O-O' : 'O-O-O';
  else if (m.piece === 'p') {
    san = m.captured ? `${FILES[fileOf(m.from)]}x${toAlgebraic(m.to)}` : toAlgebraic(m.to);
    if (m.promotion) san += `=${m.promotion.toUpperCase()}`;
  } else {
    let dis = '';
    const others = legal.filter((o) => o.piece === m.piece && o.to === m.to && o.from !== m.from);
    if (others.length) {
      const sameFile = others.some((o) => fileOf(o.from) === fileOf(m.from));
      const sameRank = others.some((o) => rankOf(o.from) === rankOf(m.from));
      if (!sameFile) dis = FILES[fileOf(m.from)]!;
      else if (!sameRank) dis = String(rankOf(m.from) + 1);
      else dis = toAlgebraic(m.from);
    }
    san = `${m.piece.toUpperCase()}${dis}${m.captured ? 'x' : ''}${toAlgebraic(m.to)}`;
  }
  const next = makeMove(pos, m);
  if (inCheck(next)) san += generateLegalMoves(next).length === 0 ? '#' : '+';
  return san;
}

/** Coordinate (UCI style) notation, e.g. e7e8q. */
export function toCoord(m: Move): string {
  return `${toAlgebraic(m.from)}${toAlgebraic(m.to)}${m.promotion ?? ''}`;
}

/** Find the legal move matching from/to (+promotion, default queen when required). */
export function findMove(legal: Move[], from: number, to: number, promotion?: PieceType): Move | null {
  const candidates = legal.filter((m) => m.from === from && m.to === to);
  if (candidates.length === 0) return null;
  if (candidates[0]!.promotion) {
    const want = promotion ?? 'q';
    return candidates.find((m) => m.promotion === want) ?? null;
  }
  return candidates[0]!;
}

/** Legal destinations grouped by origin square, in algebraic notation (for the client). */
export function legalMoveMap(pos: Position): Record<string, string[]> {
  const map: Record<string, string[]> = {};
  for (const m of generateLegalMoves(pos)) {
    const from = toAlgebraic(m.from);
    const to = toAlgebraic(m.to);
    const list = (map[from] ??= []);
    if (!list.includes(to)) list.push(to);
  }
  return map;
}
