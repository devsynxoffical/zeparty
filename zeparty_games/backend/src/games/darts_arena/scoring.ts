import type { Rng } from '../engine.js';

/**
 * Exact dartboard scoring geometry in board units: the board radius 1.0 is the
 * outer edge of the double ring. Coordinates follow the screen convention,
 * x to the right and y downwards, so the 20 segment is centred on (0, -1).
 *
 * Mirrored in Dart (games/darts_arena/lib/src/model/scoring.dart) and checked
 * against tests/fixtures/darts_arena_scoring.json.
 */
export const BOARD_GEOMETRY = {
  innerBull: 0.0373,
  outerBull: 0.0935,
  trebleInner: 0.582,
  trebleOuter: 0.629,
  doubleInner: 0.953,
  doubleOuter: 1.0,
  /** Landing points are clamped to this radius; anything beyond 1.0 is a miss. */
  clampRadius: 1.08,
  /** Largest aim radius the server accepts. */
  maxAimRadius: 1.1,
  segmentDegrees: 18,
} as const;

/** Segment numbers in clockwise order starting from the top (20 at 12 o'clock). */
export const SEGMENTS: readonly number[] = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

export const BULL = 25;

export interface DartScore {
  /** 1..20 for a segment, 25 for the bull, 0 for a miss. */
  segment: number;
  /** 1, 2 or 3; 0 for a miss. The inner bull is a double (2 x 25). */
  multiplier: number;
  points: number;
  /** Human label: '20', 'D16', 'T20', '25', 'BULL', 'MISS'. */
  label: string;
}

const MISS: DartScore = { segment: 0, multiplier: 0, points: 0, label: 'MISS' };

/** Segment index (0..19, clockwise from the top) for a point off centre. */
export function segmentIndexAt(x: number, y: number): number {
  // atan2(x, -y) is 0 at the top and grows clockwise on a y-down screen.
  let deg = (Math.atan2(x, -y) * 180) / Math.PI;
  if (deg < 0) deg += 360;
  const idx = Math.round(deg / BOARD_GEOMETRY.segmentDegrees) % SEGMENTS.length;
  return idx;
}

export function scoreAt(x: number, y: number): DartScore {
  const g = BOARD_GEOMETRY;
  const r = Math.hypot(x, y);
  if (!Number.isFinite(r) || r > g.doubleOuter) return MISS;
  if (r <= g.innerBull) return { segment: BULL, multiplier: 2, points: 50, label: 'BULL' };
  if (r <= g.outerBull) return { segment: BULL, multiplier: 1, points: 25, label: '25' };
  const segment = SEGMENTS[segmentIndexAt(x, y)]!;
  if (r >= g.trebleInner && r <= g.trebleOuter) return { segment, multiplier: 3, points: segment * 3, label: `T${segment}` };
  if (r >= g.doubleInner) return { segment, multiplier: 2, points: segment * 2, label: `D${segment}` };
  return { segment, multiplier: 1, points: segment, label: `${segment}` };
}

/** Sigma applied to the aim for a given release quality (0..1, 1 = perfect). */
export function sigmaFor(baseSigma: number, release: number): number {
  const rel = Math.min(1, Math.max(0, release));
  return baseSigma * (1.6 - rel);
}

/** One standard normal sample via Box Muller from two rng floats. */
export function gaussian(rng: Rng): number {
  let u1 = rng.float();
  const u2 = rng.float();
  if (u1 <= 1e-12) u1 = 1e-12; // avoid log(0)
  return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
}

export interface Landing {
  x: number;
  y: number;
  sigma: number;
}

/**
 * Deterministic-in-rng landing point: aim plus an isotropic gaussian scatter, clamped
 * to [BOARD_GEOMETRY.clampRadius] so a wild throw still lands near the board.
 */
export function computeLanding(aimX: number, aimY: number, release: number, baseSigma: number, rng: Rng): Landing {
  const sigma = sigmaFor(baseSigma, release);
  const dx = gaussian(rng) * sigma;
  const dy = gaussian(rng) * sigma;
  let x = aimX + dx;
  let y = aimY + dy;
  const r = Math.hypot(x, y);
  if (r > BOARD_GEOMETRY.clampRadius) {
    const k = BOARD_GEOMETRY.clampRadius / r;
    x *= k;
    y *= k;
  }
  // Round to keep state payloads compact and the Dart mirror bit-exact.
  return { x: round6(x), y: round6(y), sigma: round6(sigma) };
}

export function round6(v: number): number {
  return Math.round(v * 1e6) / 1e6;
}

/** Centre point of a segment ring, useful for tests and the server's timeout throws. */
export function pointFor(segment: number, multiplier: 1 | 2 | 3): { x: number; y: number } {
  const g = BOARD_GEOMETRY;
  if (segment === BULL) return { x: 0, y: 0 };
  const idx = SEGMENTS.indexOf(segment);
  if (idx < 0) throw new Error(`unknown segment ${segment}`);
  const r = multiplier === 3 ? (g.trebleInner + g.trebleOuter) / 2 : multiplier === 2 ? (g.doubleInner + g.doubleOuter) / 2 : (g.outerBull + g.trebleInner) / 2;
  const rad = (idx * g.segmentDegrees * Math.PI) / 180;
  return { x: round6(Math.sin(rad) * r), y: round6(-Math.cos(rad) * r) };
}
