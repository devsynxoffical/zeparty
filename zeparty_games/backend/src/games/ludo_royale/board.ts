/**
 * Ludo board geometry on the standard 15x15 grid. Shared with the Flutter client (mirrored
 * in games/ludo_royale/lib/src/board.dart) and verified by tests/fixtures/ludo_board.json.
 *
 * Positions are stored per token as a relative step count from that colour's start square:
 *   -1          in base
 *   0 .. 50     on the 52-square main track (51 squares travelled)
 *   51 .. 55    the colour's 5-square home column
 *   56          home (finished)
 */
export const TRACK_LENGTH = 52;
export const LAST_TRACK_STEP = 50;
export const HOME_COLUMN_START = 51;
export const HOME_STEP = 56;

export const COLOR_ORDER = ['red', 'green', 'yellow', 'blue'] as const;
export type LudoColor = (typeof COLOR_ORDER)[number];

/** Absolute track index where each colour starts (clockwise). */
export const START_INDEX: Record<LudoColor, number> = { red: 0, green: 13, yellow: 26, blue: 39 };

/** Star squares (absolute). Standard board: 8 squares after each start. */
export const STAR_INDEX = [8, 21, 34, 47] as const;

export type Cell = { row: number; col: number };

/** Absolute track cells, index 0 = red start, clockwise. */
export const TRACK_CELLS: Cell[] = (() => {
  const cells: Cell[] = [];
  const push = (row: number, col: number) => cells.push({ row, col });
  for (let c = 1; c <= 5; c++) push(6, c);        // 0-4
  for (let r = 5; r >= 0; r--) push(r, 6);        // 5-10
  push(0, 7);                                     // 11
  for (let r = 0; r <= 5; r++) push(r, 8);        // 12-17
  for (let c = 9; c <= 14; c++) push(6, c);       // 18-23
  push(7, 14);                                    // 24
  for (let c = 14; c >= 9; c--) push(8, c);       // 25-30
  for (let r = 9; r <= 14; r++) push(r, 8);       // 31-36
  push(14, 7);                                    // 37
  for (let r = 14; r >= 9; r--) push(r, 6);       // 38-43
  for (let c = 5; c >= 0; c--) push(8, c);        // 44-49
  push(7, 0);                                     // 50
  push(6, 0);                                     // 51
  return cells;
})();

/** Home column cells per colour, from the first column square to the last before the centre. */
export const HOME_COLUMN_CELLS: Record<LudoColor, Cell[]> = {
  red: [1, 2, 3, 4, 5].map((col) => ({ row: 7, col })),
  green: [1, 2, 3, 4, 5].map((row) => ({ row, col: 7 })),
  yellow: [13, 12, 11, 10, 9].map((col) => ({ row: 7, col })),
  blue: [13, 12, 11, 10, 9].map((row) => ({ row, col: 7 })),
};

/** Final home cell (inside the centre) per colour, used for animation targets. */
export const HOME_CELL: Record<LudoColor, Cell> = {
  red: { row: 7, col: 6 },
  green: { row: 6, col: 7 },
  yellow: { row: 7, col: 8 },
  blue: { row: 8, col: 7 },
};

/** Base slots (4 per colour) where tokens rest before entering play. */
export const BASE_CELLS: Record<LudoColor, Cell[]> = {
  red: [{ row: 1.5, col: 1.5 }, { row: 1.5, col: 3.5 }, { row: 3.5, col: 1.5 }, { row: 3.5, col: 3.5 }],
  green: [{ row: 1.5, col: 10.5 }, { row: 1.5, col: 12.5 }, { row: 3.5, col: 10.5 }, { row: 3.5, col: 12.5 }],
  yellow: [{ row: 10.5, col: 10.5 }, { row: 10.5, col: 12.5 }, { row: 12.5, col: 10.5 }, { row: 12.5, col: 12.5 }],
  blue: [{ row: 10.5, col: 1.5 }, { row: 10.5, col: 3.5 }, { row: 12.5, col: 1.5 }, { row: 12.5, col: 3.5 }],
};

export function absoluteIndex(color: LudoColor, step: number): number | null {
  if (step < 0 || step > LAST_TRACK_STEP) return null;
  return (START_INDEX[color] + step) % TRACK_LENGTH;
}

export function isStartSquare(abs: number): boolean {
  return Object.values(START_INDEX).includes(abs);
}

export function isStarSquare(abs: number): boolean {
  return (STAR_INDEX as readonly number[]).includes(abs);
}

export function isSafeSquare(abs: number, mode: 'none' | 'starts' | 'stars_and_starts'): boolean {
  if (mode === 'none') return false;
  if (isStartSquare(abs)) return true;
  return mode === 'stars_and_starts' && isStarSquare(abs);
}

/** Grid cell for a token given its colour, step and base slot index. */
export function cellForStep(color: LudoColor, step: number, tokenIndex: number): Cell {
  if (step < 0) return BASE_CELLS[color][tokenIndex] ?? BASE_CELLS[color][0]!;
  if (step <= LAST_TRACK_STEP) return TRACK_CELLS[absoluteIndex(color, step)!]!;
  if (step < HOME_STEP) return HOME_COLUMN_CELLS[color][step - HOME_COLUMN_START]!;
  return HOME_CELL[color];
}

/** Every cell a token passes through moving from `from` to `to` (exclusive of from). */
export function pathCells(color: LudoColor, from: number, to: number, tokenIndex: number): Cell[] {
  const out: Cell[] = [];
  const start = from < 0 ? -1 : from;
  for (let s = start + 1; s <= to; s++) out.push(cellForStep(color, s, tokenIndex));
  return out;
}
