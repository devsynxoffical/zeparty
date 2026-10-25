/**
 * Carrom Masters board layout. Everything is expressed in board units: the
 * playfield is the square 0..100 on both axes, x grows to the right and y grows
 * downwards (screen convention). Seat edges: 0 = bottom, 1 = right, 2 = top,
 * 3 = left. Each shooter sees the board rotated so their own edge is at the
 * bottom; `toBoard`/`toFrame` convert between that shooter frame and board space.
 *
 * The Dart client mirrors these constants (games/carrom_masters/lib/src/model/geometry.dart)
 * and the backend test writes tests/fixtures/carrom_masters_layout.json so both
 * sides are checked against each other.
 */

export const BOARD_SIZE = 100;
export const POCKET_RADIUS = 2.6;
/** Pocket centres are inset from the corner by the pocket radius so they touch both cushions. */
export const POCKET_INSET = 2.6;
export const COIN_RADIUS = 1.6;
export const STRIKER_RADIUS = 2.1;
/** Distance of the baseline from the shooter's own cushion (y = 88 for the bottom edge). */
export const BASELINE_OFFSET = 12;
export const BASELINE_Y = BOARD_SIZE - BASELINE_OFFSET;
export const BASELINE_X_MIN = 18;
export const BASELINE_X_MAX = 82;
export const MAX_SHOT_SPEED = 140;
export const CENTER = { x: BOARD_SIZE / 2, y: BOARD_SIZE / 2 };

export const COIN_MASS = 1;
export const STRIKER_MASS = 1.6;

export interface Point {
  x: number;
  y: number;
}

export const POCKETS: readonly Point[] = [
  { x: POCKET_INSET, y: POCKET_INSET },
  { x: BOARD_SIZE - POCKET_INSET, y: POCKET_INSET },
  { x: BOARD_SIZE - POCKET_INSET, y: BOARD_SIZE - POCKET_INSET },
  { x: POCKET_INSET, y: BOARD_SIZE - POCKET_INSET },
];

export type CoinKind = 'white' | 'black' | 'queen';

export interface CoinSpec {
  id: string;
  kind: CoinKind;
  x: number;
  y: number;
}

export const STRIKER_ID = 's';
export const QUEEN_ID = 'q';

/** Inner ring (6 coins) touching the queen; outer ring (12 coins) touching the inner ring. */
const INNER_RING_RADIUS = COIN_RADIUS * 2 + 0.1;
const OUTER_RING_RADIUS = INNER_RING_RADIUS * 2;

/**
 * Standard centre rack: queen in the middle, an inner ring of six alternating
 * colours and an outer ring of twelve alternating colours. With fewer than nine
 * coins per side the outer ring is trimmed symmetrically.
 */
export function initialRack(coinsPerSide = 9): CoinSpec[] {
  const coins: CoinSpec[] = [{ id: QUEEN_ID, kind: 'queen', x: CENTER.x, y: CENTER.y }];
  let w = 0;
  let b = 0;
  const push = (kind: 'white' | 'black', x: number, y: number) => {
    if (kind === 'white') {
      if (w >= coinsPerSide) return;
      coins.push({ id: `w${w++}`, kind, x: round4(x), y: round4(y) });
    } else {
      if (b >= coinsPerSide) return;
      coins.push({ id: `b${b++}`, kind, x: round4(x), y: round4(y) });
    }
  };
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i;
    push(i % 2 === 0 ? 'white' : 'black', CENTER.x + Math.cos(a) * INNER_RING_RADIUS, CENTER.y + Math.sin(a) * INNER_RING_RADIUS);
  }
  for (let i = 0; i < 12; i++) {
    const a = (Math.PI / 6) * i + Math.PI / 12;
    push(i % 2 === 0 ? 'black' : 'white', CENTER.x + Math.cos(a) * OUTER_RING_RADIUS, CENTER.y + Math.sin(a) * OUTER_RING_RADIUS);
  }
  return coins;
}

function round4(v: number): number {
  return Math.round(v * 10000) / 10000;
}

/** Shooter frame (own edge at the bottom) -> board coordinates. Pure rotation about the centre. */
export function toBoard(edge: number, p: Point): Point {
  switch (((edge % 4) + 4) % 4) {
    case 0:
      return { x: p.x, y: p.y };
    case 1:
      return { x: p.y, y: BOARD_SIZE - p.x };
    case 2:
      return { x: BOARD_SIZE - p.x, y: BOARD_SIZE - p.y };
    default:
      return { x: BOARD_SIZE - p.y, y: p.x };
  }
}

/** Board coordinates -> shooter frame for `edge`. Inverse of `toBoard`. */
export function toFrame(edge: number, p: Point): Point {
  switch (((edge % 4) + 4) % 4) {
    case 0:
      return { x: p.x, y: p.y };
    case 1:
      return { x: BOARD_SIZE - p.y, y: p.x };
    case 2:
      return { x: BOARD_SIZE - p.x, y: BOARD_SIZE - p.y };
    default:
      return { x: p.y, y: BOARD_SIZE - p.x };
  }
}

/** Rotate a direction vector from the shooter frame into board space (no translation). */
export function vectorToBoard(edge: number, v: Point): Point {
  const o = toBoard(edge, { x: 0, y: 0 });
  const p = toBoard(edge, v);
  return { x: p.x - o.x, y: p.y - o.y };
}

/** Board edge a seat shoots from: 2 players sit opposite, 4 players go round the table. */
export function edgeForSeat(seat: number, playerCount: number): number {
  if (playerCount === 2) return seat === 0 ? 0 : 2;
  return seat % 4;
}

/** Team colour: seats 0 and 2 play white, seats 1 and 3 play black. */
export function sideForSeat(seat: number): 'white' | 'black' {
  return seat % 2 === 0 ? 'white' : 'black';
}

/**
 * Direction of a shot in the shooter frame. `angle` is a mathematical angle in
 * radians with the opponent "up": pi/2 shoots straight ahead, 0 shoots to the
 * right along the baseline, pi to the left. Returned as a unit vector in the
 * shooter frame (y grows downwards, so "up" is negative y).
 */
export function shotDirection(angle: number): Point {
  return { x: Math.cos(angle), y: -Math.sin(angle) };
}

export function dist(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

/**
 * Deterministic free spot for returning a coin to the centre: the centre itself
 * when free, otherwise the first free point on a tightening spiral around it.
 */
export function freeSpotNearCenter(occupied: Array<Point & { r: number }>, radius = COIN_RADIUS): Point {
  const fits = (p: Point) => occupied.every((o) => dist(o, p) >= o.r + radius + 0.05);
  if (fits(CENTER)) return { ...CENTER };
  for (let ring = 1; ring < 40; ring++) {
    const rr = ring * (radius * 2 + 0.2);
    const n = 6 * ring;
    for (let i = 0; i < n; i++) {
      const a = (Math.PI * 2 * i) / n;
      const p = { x: round4(CENTER.x + Math.cos(a) * rr), y: round4(CENTER.y + Math.sin(a) * rr) };
      if (p.x < radius + 1 || p.x > BOARD_SIZE - radius - 1 || p.y < radius + 1 || p.y > BOARD_SIZE - radius - 1) continue;
      if (fits(p)) return p;
    }
  }
  return { ...CENTER };
}
