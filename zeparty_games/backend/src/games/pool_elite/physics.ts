/**
 * Deterministic 2D rigid-circle simulator for 8 Ball Pool Elite.
 *
 * Fixed timestep 1/120 s with 4 substeps, circle-circle elastic collisions with positional
 * correction, cushion segments (with pocket openings and jaws), pockets as capture circles,
 * rolling friction plus linear damping. No randomness anywhere: the same input always yields
 * the same keyframes, which is what lets the server be the only authority while clients replay.
 */
import { BALL_RADIUS, CUE, CUSHIONS, OFF_TABLE_MARGIN, POCKETS, TABLE_HEIGHT, TABLE_WIDTH, round3, type Segment } from './table.js';

export const DT = 1 / 120;
export const SUBSTEPS = 4;
/** Sequential-impulse iterations per substep for simultaneous ball contacts. */
export const SOLVER_ITERATIONS = 8;
export const KEYFRAME_INTERVAL = 4; // steps of DT -> 1/30 s
export const MAX_SIM_SECONDS = 12;
export const REST_SPEED = 0.5;
export const MAX_CUE_SPEED = 180;
export const MIN_POWER = 0.04;
export const BALL_RESTITUTION = 0.95;
export const CUSHION_RESTITUTION = 0.8;
/** Tangential velocity retained on a cushion bounce (cloth drag on the rail). */
export const CUSHION_TANGENT_KEEP = 0.94;
/** Rolling friction deceleration in units/s^2. */
export const ROLLING_DECEL = 9;
/** Linear damping per second (exponential), models cloth drag at speed. */
export const LINEAR_DAMPING = 0.15;
/** Follow/draw effect: fraction of pre-impact cue speed added along the pre-impact direction. */
export const SPIN_Y_GAIN = 0.32;
/** English: radians of lateral deflection applied to the cue ball after a cushion bounce. */
export const SPIN_X_GAIN = 0.28;

export interface Body {
  id: number;
  x: number;
  y: number;
}

export interface Shot {
  angle: number;
  power: number;
  spin?: { x: number; y: number };
}

export interface Keyframe {
  t: number;
  bodies: Array<{ id: number; x: number; y: number }>;
}

export type CollisionEvent =
  | { t: number; type: 'ball'; a: number; b: number; speed: number }
  | { t: number; type: 'cushion'; ball: number; speed: number }
  | { t: number; type: 'pocket'; ball: number; pocket: number };

export interface ShotResult {
  frames: Keyframe[];
  collisions: CollisionEvent[];
  /** Balls that fell, in order, with the pocket id. */
  pocketed: Array<{ id: number; pocket: number; t: number }>;
  /** First object ball the cue ball touched, or null. */
  firstContact: number | null;
  /** Any ball touched a cushion after the cue ball's first contact. */
  railAfterContact: boolean;
  /** The cue ball touched a cushion before any ball contact. */
  cueRailBeforeContact: boolean;
  cueScratched: boolean;
  /** Seconds of simulated time. */
  duration: number;
  final: Body[];
}

interface Contact {
  i: number;
  j: number;
  nx: number;
  ny: number;
  overlap: number;
  target: number;
  rel0: number;
  acc: number;
}

interface Sim {
  id: number[];
  x: Float64Array;
  y: Float64Array;
  vx: Float64Array;
  vy: Float64Array;
  active: Uint8Array;
}

const R = BALL_RADIUS;
const R2 = (2 * R) * (2 * R);

/** Simulate one shot. `bodies` are the balls on the table (cue ball id 0 must be present). */
export function simulateShot(bodies: Body[], shot: Shot, opts: { maxSeconds?: number } = {}): ShotResult {
  const n = bodies.length;
  const sim: Sim = {
    id: bodies.map((b) => b.id),
    x: Float64Array.from(bodies.map((b) => b.x)),
    y: Float64Array.from(bodies.map((b) => b.y)),
    vx: new Float64Array(n),
    vy: new Float64Array(n),
    active: new Uint8Array(n).fill(1),
  };
  const cueIdx = sim.id.indexOf(CUE);
  if (cueIdx === -1) throw new Error('cue ball missing');

  const power = Math.min(1, Math.max(MIN_POWER, shot.power));
  const speed = power * MAX_CUE_SPEED;
  sim.vx[cueIdx] = Math.cos(shot.angle) * speed;
  sim.vy[cueIdx] = Math.sin(shot.angle) * speed;
  const spinX = clamp(shot.spin?.x ?? 0, -1, 1);
  const spinY = clamp(shot.spin?.y ?? 0, -1, 1);
  let spinYPending = spinY !== 0;
  let spinXCharges = spinX !== 0 ? 2 : 0;

  const frames: Keyframe[] = [];
  const collisions: CollisionEvent[] = [];
  const pocketed: Array<{ id: number; pocket: number; t: number }> = [];
  let firstContact: number | null = null;
  let railAfterContact = false;
  let cueRailBeforeContact = false;
  const maxSteps = Math.round((opts.maxSeconds ?? MAX_SIM_SECONDS) / DT);
  const h = DT / SUBSTEPS;

  const lastFrameX = Float64Array.from(sim.x);
  const lastFrameY = Float64Array.from(sim.y);
  frames.push({ t: 0, bodies: bodies.map((b, i) => ({ id: b.id, x: round3(sim.x[i]!), y: round3(sim.y[i]!) })) });

  // Cushion-contact debounce so a ball resting against a rail does not spam events.
  const lastCushionHit = new Float64Array(n).fill(-1);
  const lastBallHit = new Map<number, number>();
  const contacts: Contact[] = [];

  let step = 0;
  let t = 0;
  for (step = 1; step <= maxSteps; step++) {
    for (let s = 0; s < SUBSTEPS; s++) {
      integrate(sim, h);
      // Ball-ball: gather every overlapping pair, then solve all of them together with a
      // sequential-impulse solver (accumulated impulses clamped at zero, restitution target
      // taken from the pre-solve approach speed). Simultaneous contacts inside a tight rack
      // therefore split energy symmetrically instead of channelling it down one edge.
      contacts.length = 0;
      for (let i = 0; i < n; i++) {
        if (!sim.active[i]) continue;
        for (let j = i + 1; j < n; j++) {
          if (!sim.active[j]) continue;
          const dx = sim.x[j]! - sim.x[i]!;
          const dy = sim.y[j]! - sim.y[i]!;
          const d2 = dx * dx + dy * dy;
          if (d2 >= R2 || d2 === 0) continue;
          const d = Math.sqrt(d2);
          const nx = dx / d;
          const ny = dy / d;
          const rel0 = (sim.vx[i]! - sim.vx[j]!) * nx + (sim.vy[i]! - sim.vy[j]!) * ny; // > 0 approaching
          contacts.push({ i, j, nx, ny, overlap: 2 * R - d, target: rel0 > REST_SPEED * 0.2 ? -BALL_RESTITUTION * rel0 : 0, rel0, acc: 0 });
        }
      }
      if (contacts.length > 0) {
        const preVx = sim.vx[cueIdx]!;
        const preVy = sim.vy[cueIdx]!;
        for (let it = 0; it < SOLVER_ITERATIONS; it++) {
          for (const c of contacts) {
            const rel = (sim.vx[c.i]! - sim.vx[c.j]!) * c.nx + (sim.vy[c.i]! - sim.vy[c.j]!) * c.ny;
            const dJ = (rel - c.target) / 2;
            const acc = Math.max(0, c.acc + dJ);
            const applied = acc - c.acc;
            c.acc = acc;
            if (applied === 0) continue;
            sim.vx[c.i]! -= applied * c.nx;
            sim.vy[c.i]! -= applied * c.ny;
            sim.vx[c.j]! += applied * c.nx;
            sim.vy[c.j]! += applied * c.ny;
          }
        }
        for (const c of contacts) {
          // Positional correction: split the overlap.
          const half = c.overlap * 0.5;
          sim.x[c.i]! -= c.nx * half;
          sim.y[c.i]! -= c.ny * half;
          sim.x[c.j]! += c.nx * half;
          sim.y[c.j]! += c.ny * half;
          if (c.rel0 <= 0) continue;
          const key = c.i * 64 + c.j;
          const last = lastBallHit.get(key) ?? -1;
          if (t - last > 0.03) {
            collisions.push({ t: round3(t), type: 'ball', a: sim.id[c.i]!, b: sim.id[c.j]!, speed: round3(c.rel0) });
          }
          lastBallHit.set(key, t);
          if (firstContact === null && (c.i === cueIdx || c.j === cueIdx)) {
            firstContact = c.i === cueIdx ? sim.id[c.j]! : sim.id[c.i]!;
            if (spinYPending) {
              // Follow (y > 0) keeps some roll along the pre-impact line, draw (y < 0) pulls back.
              spinYPending = false;
              const preSpeed = Math.hypot(preVx, preVy);
              if (preSpeed > 0) {
                sim.vx[cueIdx]! += (preVx / preSpeed) * spinY * SPIN_Y_GAIN * preSpeed;
                sim.vy[cueIdx]! += (preVy / preSpeed) * spinY * SPIN_Y_GAIN * preSpeed;
              }
            }
          }
        }
      }
      // Cushions
      for (let i = 0; i < n; i++) {
        if (!sim.active[i]) continue;
        let hit = false;
        for (const seg of CUSHIONS) {
          if (collideSegment(sim, i, seg)) hit = true;
        }
        if (hit) {
          if (i === cueIdx && spinXCharges > 0) {
            spinXCharges--;
            // English: a small, deterministic lateral deflection off the first two cushions.
            rotateVelocity(sim, i, spinX * SPIN_X_GAIN);
          }
          if (t - lastCushionHit[i]! > 0.05) {
            collisions.push({ t: round3(t), type: 'cushion', ball: sim.id[i]!, speed: round3(Math.hypot(sim.vx[i]!, sim.vy[i]!)) });
          }
          lastCushionHit[i] = t;
          if (firstContact !== null) railAfterContact = true;
          else if (i === cueIdx) cueRailBeforeContact = true;
        }
      }
      // Pockets and off-table
      for (let i = 0; i < n; i++) {
        if (!sim.active[i]) continue;
        const px = sim.x[i]!;
        const py = sim.y[i]!;
        let fell: number | null = null;
        for (const p of POCKETS) {
          const dx = px - p.x;
          const dy = py - p.y;
          if (dx * dx + dy * dy < p.r * p.r) {
            fell = p.id;
            break;
          }
        }
        if (fell === null && (px < -OFF_TABLE_MARGIN || px > TABLE_WIDTH + OFF_TABLE_MARGIN || py < -OFF_TABLE_MARGIN || py > TABLE_HEIGHT + OFF_TABLE_MARGIN)) {
          fell = nearestPocket(px, py);
        }
        if (fell !== null) {
          sim.active[i] = 0;
          sim.vx[i] = 0;
          sim.vy[i] = 0;
          collisions.push({ t: round3(t), type: 'pocket', ball: sim.id[i]!, pocket: fell });
          pocketed.push({ id: sim.id[i]!, pocket: fell, t: round3(t) });
        }
      }
      t += h;
    }
    // Keyframe
    if (step % KEYFRAME_INTERVAL === 0) {
      const changed: Keyframe['bodies'] = [];
      for (let i = 0; i < n; i++) {
        if (!sim.active[i]) continue;
        if (Math.abs(sim.x[i]! - lastFrameX[i]!) > 1e-3 || Math.abs(sim.y[i]! - lastFrameY[i]!) > 1e-3) {
          changed.push({ id: sim.id[i]!, x: round3(sim.x[i]!), y: round3(sim.y[i]!) });
          lastFrameX[i] = sim.x[i]!;
          lastFrameY[i] = sim.y[i]!;
        }
      }
      if (changed.length > 0) frames.push({ t: round3(step * DT), bodies: changed });
    }
    if (allAtRest(sim)) break;
  }
  // Snap everything below threshold to rest and emit a closing frame with every live ball.
  for (let i = 0; i < n; i++) {
    sim.vx[i] = 0;
    sim.vy[i] = 0;
  }
  const duration = round3(Math.min(step, maxSteps) * DT);
  const final: Body[] = [];
  const closing: Keyframe['bodies'] = [];
  for (let i = 0; i < n; i++) {
    if (!sim.active[i]) continue;
    final.push({ id: sim.id[i]!, x: round3(sim.x[i]!), y: round3(sim.y[i]!) });
    closing.push({ id: sim.id[i]!, x: round3(sim.x[i]!), y: round3(sim.y[i]!) });
  }
  const last = frames[frames.length - 1]!;
  if (last.t < duration || frames.length === 1) frames.push({ t: duration, bodies: closing });
  else frames[frames.length - 1] = { t: duration, bodies: closing };

  return {
    frames,
    collisions,
    pocketed,
    firstContact,
    railAfterContact,
    cueRailBeforeContact,
    cueScratched: pocketed.some((p) => p.id === CUE),
    duration,
    final,
  };
}

function integrate(sim: Sim, h: number): void {
  const n = sim.id.length;
  const damp = Math.exp(-LINEAR_DAMPING * h);
  for (let i = 0; i < n; i++) {
    if (!sim.active[i]) continue;
    let vx = sim.vx[i]!;
    let vy = sim.vy[i]!;
    const sp = Math.hypot(vx, vy);
    if (sp > 0) {
      const ns = Math.max(0, sp - ROLLING_DECEL * h) * damp;
      const k = ns / sp;
      vx *= k;
      vy *= k;
    }
    sim.vx[i] = vx;
    sim.vy[i] = vy;
    sim.x[i]! += vx * h;
    sim.y[i]! += vy * h;
  }
}

/** Reflects ball i off a segment when overlapping and approaching. Returns true on a bounce. */
function collideSegment(sim: Sim, i: number, seg: Segment): boolean {
  const px = sim.x[i]!;
  const py = sim.y[i]!;
  const ex = seg.x2 - seg.x1;
  const ey = seg.y2 - seg.y1;
  const len2 = ex * ex + ey * ey;
  let u = ((px - seg.x1) * ex + (py - seg.y1) * ey) / len2;
  u = u < 0 ? 0 : u > 1 ? 1 : u;
  const cx = seg.x1 + ex * u;
  const cy = seg.y1 + ey * u;
  const dx = px - cx;
  const dy = py - cy;
  const d2 = dx * dx + dy * dy;
  if (d2 >= R * R || d2 === 0) return false;
  const d = Math.sqrt(d2);
  const nx = dx / d;
  const ny = dy / d;
  // push out
  const pen = R - d;
  sim.x[i]! += nx * pen;
  sim.y[i]! += ny * pen;
  const vn = sim.vx[i]! * nx + sim.vy[i]! * ny;
  if (vn >= 0) return false;
  const tx = -ny;
  const ty = nx;
  const vt = (sim.vx[i]! * tx + sim.vy[i]! * ty) * CUSHION_TANGENT_KEEP;
  const vn2 = -vn * CUSHION_RESTITUTION;
  sim.vx[i] = nx * vn2 + tx * vt;
  sim.vy[i] = ny * vn2 + ty * vt;
  return true;
}

function rotateVelocity(sim: Sim, i: number, angle: number): void {
  const vx = sim.vx[i]!;
  const vy = sim.vy[i]!;
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  sim.vx[i] = vx * c - vy * s;
  sim.vy[i] = vx * s + vy * c;
}

function allAtRest(sim: Sim): boolean {
  for (let i = 0; i < sim.id.length; i++) {
    if (!sim.active[i]) continue;
    if (Math.hypot(sim.vx[i]!, sim.vy[i]!) >= REST_SPEED) return false;
  }
  return true;
}

export function nearestPocket(x: number, y: number): number {
  let best = 0;
  let bestD = Infinity;
  for (const p of POCKETS) {
    const d = (x - p.x) ** 2 + (y - p.y) ** 2;
    if (d < bestD) {
      bestD = d;
      best = p.id;
    }
  }
  return best;
}

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

/** True when a ball centred at (x, y) would overlap any of `others` or leave the cloth. */
export function placementBlocked(x: number, y: number, others: Body[]): boolean {
  if (x < R || x > TABLE_WIDTH - R || y < R || y > TABLE_HEIGHT - R) return true;
  for (const o of others) {
    const dx = o.x - x;
    const dy = o.y - y;
    if (dx * dx + dy * dy < R2 - 1e-6) return true;
  }
  return false;
}

/** Nearest free spot to (x, y) searching outward on a small grid; used for respots and defaults. */
export function nearestFreeSpot(x: number, y: number, others: Body[], preferAxisX = true): { x: number; y: number } {
  if (!placementBlocked(x, y, others)) return { x, y };
  const stepLen = R * 0.5;
  // First try sliding along the long axis (standard respot behaviour), then spiral.
  if (preferAxisX) {
    for (let k = 1; k < 200; k++) {
      for (const dir of [-1, 1]) {
        const nx = x + dir * k * stepLen;
        if (!placementBlocked(nx, y, others)) return { x: round3(nx), y };
      }
    }
  }
  for (let ring = 1; ring < 80; ring++) {
    const rad = ring * stepLen;
    const count = 8 * ring;
    for (let k = 0; k < count; k++) {
      const a = (k / count) * Math.PI * 2;
      const nx = x + Math.cos(a) * rad;
      const ny = y + Math.sin(a) * rad;
      if (!placementBlocked(nx, ny, others)) return { x: round3(nx), y: round3(ny) };
    }
  }
  return { x, y };
}
