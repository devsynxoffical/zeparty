/**
 * Deterministic 2D rigid-circle simulator for Carrom Masters.
 *
 * - Fixed timestep 1/120 s, sub-stepped so the fastest body never moves more than
 *   half the smallest radius per substep (no tunnelling).
 * - Coulomb friction (constant deceleration) plus linear velocity damping.
 * - Elastic circle-circle collisions with restitution and positional correction.
 * - Cushions are the four walls of the square board, reflecting with their own restitution.
 * - Pockets are circles; a body whose centre enters one is removed.
 * - No randomness anywhere: the same inputs always produce the same frames.
 */
import { BOARD_SIZE, POCKETS, POCKET_RADIUS, type Point } from './layout.js';

export interface Body {
  id: string;
  x: number;
  y: number;
  vx: number;
  vy: number;
  r: number;
  mass: number;
}

export interface BoardPhysics {
  size: number;
  pockets: readonly Point[];
  pocketRadius: number;
  cushionRestitution: number;
  bodyRestitution: number;
  /** Constant deceleration from sliding friction (units/s^2). */
  friction: number;
  /** Exponential velocity damping (1/s). */
  damping: number;
  /** Bodies slower than this are stopped (units/s). */
  restThreshold: number;
  /** Hard cap on simulated time (s). */
  maxTime: number;
}

export const DEFAULT_BOARD: BoardPhysics = {
  size: BOARD_SIZE,
  pockets: POCKETS,
  pocketRadius: POCKET_RADIUS,
  cushionRestitution: 0.75,
  bodyRestitution: 0.92,
  friction: 18,
  damping: 0.25,
  restThreshold: 0.4,
  maxTime: 12,
};

export const FIXED_DT = 1 / 120;
export const FRAME_INTERVAL = 1 / 30;

export interface FrameBody {
  id: string;
  x: number;
  y: number;
}

export interface Frame {
  t: number;
  bodies: FrameBody[];
}

export interface PocketEvent {
  id: string;
  /** Index into POCKETS, or -1 when the body left the board without a pocket (safety net). */
  pocket: number;
  t: number;
}

export type CollisionKind = 'coin' | 'cushion' | 'pocket';

export interface CollisionEvent {
  t: number;
  kind: CollisionKind;
  /** Relative impact speed, for SFX volume. */
  speed: number;
  ids: string[];
}

export interface ShotResult {
  frames: Frame[];
  pocketed: PocketEvent[];
  collisions: CollisionEvent[];
  final: FrameBody[];
  /** Total simulated time in seconds. */
  duration: number;
  /** True when the simulation hit maxTime before every body came to rest. */
  truncated: boolean;
}

function round3(v: number): number {
  return Math.round(v * 1000) / 1000;
}

/** Kinetic energy of the system, used by tests to check dissipation. */
export function kineticEnergy(bodies: readonly Body[]): number {
  return bodies.reduce((e, b) => e + 0.5 * b.mass * (b.vx * b.vx + b.vy * b.vy), 0);
}

/**
 * Simulate a strike. `bodies` is every body on the board including the striker;
 * `strikerVelocity` is applied to the body whose id is `strikerId` before the first
 * step. The input array is not mutated.
 */
export function simulateShot(
  board: BoardPhysics,
  bodies: readonly Body[],
  strikerVelocity: Point,
  strikerId = 's',
  /** Optional probe called after every fixed step with the live bodies (tests, debugging). */
  onStep?: (t: number, live: readonly Body[]) => void,
): ShotResult {
  const live: Body[] = bodies.map((b) => ({ ...b }));
  const striker = live.find((b) => b.id === strikerId);
  if (striker) {
    striker.vx = strikerVelocity.x;
    striker.vy = strikerVelocity.y;
  }
  const minRadius = live.reduce((m, b) => Math.min(m, b.r), Infinity);
  const frames: Frame[] = [];
  const pocketed: PocketEvent[] = [];
  const collisions: CollisionEvent[] = [];
  const lastFramePos = new Map<string, { x: number; y: number }>();

  const emitFrame = (t: number, full: boolean) => {
    const fb: FrameBody[] = [];
    for (const b of live) {
      const prev = lastFramePos.get(b.id);
      const moved = !prev || Math.abs(prev.x - b.x) > 1e-4 || Math.abs(prev.y - b.y) > 1e-4;
      if (full || moved) {
        fb.push({ id: b.id, x: round3(b.x), y: round3(b.y) });
        lastFramePos.set(b.id, { x: b.x, y: b.y });
      }
    }
    frames.push({ t: round3(t), bodies: fb });
  };

  emitFrame(0, true);
  let t = 0;
  let nextFrameAt = FRAME_INTERVAL;
  let truncated = false;
  const lastCushionAt = new Map<string, number>();
  const lastCoinHitAt = new Map<string, number>();

  while (true) {
    const allRest = live.every((b) => b.vx === 0 && b.vy === 0);
    if (allRest) break;
    if (t >= board.maxTime - 1e-9) {
      truncated = true;
      for (const b of live) {
        b.vx = 0;
        b.vy = 0;
      }
      break;
    }
    const maxSpeed = live.reduce((m, b) => Math.max(m, Math.hypot(b.vx, b.vy)), 0);
    const substeps = Math.max(1, Math.ceil((maxSpeed * FIXED_DT) / (0.5 * minRadius)));
    const h = FIXED_DT / substeps;
    for (let s = 0; s < substeps; s++) {
      const now = t + h * (s + 1);
      // Integrate with friction and damping.
      for (const b of live) {
        const sp = Math.hypot(b.vx, b.vy);
        if (sp === 0) continue;
        let ns = sp - board.friction * h;
        ns *= Math.exp(-board.damping * h);
        if (ns <= board.restThreshold) {
          b.vx = 0;
          b.vy = 0;
          continue;
        }
        const k = ns / sp;
        b.vx *= k;
        b.vy *= k;
        b.x += b.vx * h;
        b.y += b.vy * h;
      }
      // Body-body collisions (two relaxation passes keep stacks stable).
      for (let pass = 0; pass < 2; pass++) {
        for (let i = 0; i < live.length; i++) {
          const a = live[i]!;
          for (let j = i + 1; j < live.length; j++) {
            const c = live[j]!;
            let dx = c.x - a.x;
            let dy = c.y - a.y;
            const minD = a.r + c.r;
            let d2 = dx * dx + dy * dy;
            if (d2 >= minD * minD) continue;
            let d = Math.sqrt(d2);
            if (d < 1e-9) {
              // Perfect overlap: separate deterministically along x.
              dx = 1;
              dy = 0;
              d = 1e-9;
              d2 = d * d;
            }
            const nx = dx / d;
            const ny = dy / d;
            const invA = 1 / a.mass;
            const invC = 1 / c.mass;
            const invSum = invA + invC;
            // Positional correction so bodies never rest overlapping.
            const pen = minD - d;
            a.x -= nx * pen * (invA / invSum);
            a.y -= ny * pen * (invA / invSum);
            c.x += nx * pen * (invC / invSum);
            c.y += ny * pen * (invC / invSum);
            const rvx = c.vx - a.vx;
            const rvy = c.vy - a.vy;
            const vn = rvx * nx + rvy * ny;
            if (vn >= 0) continue; // separating
            const jImp = (-(1 + board.bodyRestitution) * vn) / invSum;
            a.vx -= jImp * nx * invA;
            a.vy -= jImp * ny * invA;
            c.vx += jImp * nx * invC;
            c.vy += jImp * ny * invC;
            const key = a.id < c.id ? `${a.id}|${c.id}` : `${c.id}|${a.id}`;
            const last = lastCoinHitAt.get(key);
            if (last === undefined || now - last > 0.05) {
              collisions.push({ t: round3(now), kind: 'coin', speed: round3(-vn), ids: [a.id, c.id] });
              lastCoinHitAt.set(key, now);
            }
          }
        }
      }
      // Cushions.
      for (const b of live) {
        let hit = 0;
        if (b.x - b.r < 0) {
          b.x = b.r;
          if (b.vx < 0) {
            hit = Math.max(hit, -b.vx);
            b.vx = -b.vx * board.cushionRestitution;
          }
        } else if (b.x + b.r > board.size) {
          b.x = board.size - b.r;
          if (b.vx > 0) {
            hit = Math.max(hit, b.vx);
            b.vx = -b.vx * board.cushionRestitution;
          }
        }
        if (b.y - b.r < 0) {
          b.y = b.r;
          if (b.vy < 0) {
            hit = Math.max(hit, -b.vy);
            b.vy = -b.vy * board.cushionRestitution;
          }
        } else if (b.y + b.r > board.size) {
          b.y = board.size - b.r;
          if (b.vy > 0) {
            hit = Math.max(hit, b.vy);
            b.vy = -b.vy * board.cushionRestitution;
          }
        }
        if (hit > 0) {
          const last = lastCushionAt.get(b.id);
          if (last === undefined || now - last > 0.05) {
            collisions.push({ t: round3(now), kind: 'cushion', speed: round3(hit), ids: [b.id] });
            lastCushionAt.set(b.id, now);
          }
        }
      }
      // Pockets.
      for (let i = live.length - 1; i >= 0; i--) {
        const b = live[i]!;
        let captured = -1;
        for (let p = 0; p < board.pockets.length; p++) {
          const pk = board.pockets[p]!;
          if (Math.hypot(b.x - pk.x, b.y - pk.y) <= board.pocketRadius) {
            captured = p;
            break;
          }
        }
        const outside = b.x < -b.r || b.x > board.size + b.r || b.y < -b.r || b.y > board.size + b.r;
        if (captured >= 0 || outside) {
          pocketed.push({ id: b.id, pocket: captured, t: round3(now) });
          collisions.push({ t: round3(now), kind: 'pocket', speed: round3(Math.hypot(b.vx, b.vy)), ids: [b.id] });
          live.splice(i, 1);
          lastFramePos.delete(b.id);
        }
      }
    }
    t += FIXED_DT;
    onStep?.(t, live);
    if (t + 1e-9 >= nextFrameAt) {
      emitFrame(t, false);
      nextFrameAt += FRAME_INTERVAL;
    }
  }
  // Always close with a final frame so the client lands exactly on the rest positions.
  if (frames.length === 0 || frames[frames.length - 1]!.t < round3(t) - 1e-9) emitFrame(t, false);
  const final = live.map((b) => ({ id: b.id, x: round3(b.x), y: round3(b.y) }));
  return { frames, pocketed, collisions, final, duration: round3(t), truncated };
}

/** True when two circles overlap (used by placement validation). */
export function circlesOverlap(a: Point & { r: number }, b: Point & { r: number }): boolean {
  return Math.hypot(a.x - b.x, a.y - b.y) < a.r + b.r;
}
