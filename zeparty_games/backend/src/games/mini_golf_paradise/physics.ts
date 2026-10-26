/**
 * Deterministic 2D putting simulator. Fixed dt of 1/120 s with 4 substeps, circle vs line
 * segment collisions against static walls and time-dependent obstacle rectangles, surface
 * friction by ball position, water hazards, cup capture below a speed threshold.
 *
 * Only plain arithmetic in a fixed order: the same inputs always produce the same frames.
 */
import { pointInAny, pointInTurf, type BarObstacle, type BlockObstacle, type Course, type Obstacle, type Segment, type Vec } from './courses.js';

export const BALL_RADIUS = 1.5;
export const CUP_RADIUS = 2.2;
export const CUP_CAPTURE_SPEED = 70;
export const FRICTION_TURF = 14;
export const FRICTION_SAND = 40;
export const MAX_PUTT_SPEED = 170;
export const WALL_RESTITUTION = 0.7;
export const FIXED_DT = 1 / 120;
export const SUBSTEPS = 4;
export const MAX_SIM_TIME = 12;
export const REST_SPEED = 2;
export const KEYFRAME_DT = 1 / 30;

export interface Keyframe {
  t: number;
  x: number;
  y: number;
  /** One value per course obstacle: bar angle (rad) or block offset (units) at this time. */
  obs: number[];
}

export interface Bounce {
  t: number;
  x: number;
  y: number;
  kind: 'wall' | 'obstacle';
}

export interface StrokeResult {
  frames: Keyframe[];
  holed: boolean;
  water: boolean;
  bounces: Bounce[];
  /** Resting position after the stroke (hole centre when holed, start when in water). */
  final: Vec;
  /** Simulated seconds consumed; advances the course obstacle clock. */
  duration: number;
}

// ---------------------------------------------------------------------------
// Obstacles as a function of the simulation clock
// ---------------------------------------------------------------------------

export function barAngle(o: BarObstacle, clock: number): number {
  return o.phase + o.angularSpeed * clock;
}

export function blockOffset(o: BlockObstacle, clock: number): number {
  return o.amplitude * Math.sin(o.phase + o.speed * clock);
}

/** Scalar state per obstacle (what the keyframes carry). */
export function obstacleValues(course: Course, clock: number): number[] {
  return course.obstacles.map((o) => (o.kind === 'bar' ? barAngle(o, clock) : blockOffset(o, clock)));
}

function rectSegments(center: Vec, halfW: number, halfH: number, angle: number): Segment[] {
  const c = Math.cos(angle);
  const s = Math.sin(angle);
  const corner = (lx: number, ly: number): Vec => ({ x: center.x + lx * c - ly * s, y: center.y + lx * s + ly * c });
  const p0 = corner(-halfW, -halfH);
  const p1 = corner(halfW, -halfH);
  const p2 = corner(halfW, halfH);
  const p3 = corner(-halfW, halfH);
  return [
    { a: p0, b: p1 },
    { a: p1, b: p2 },
    { a: p2, b: p3 },
    { a: p3, b: p0 },
  ];
}

export interface MovingSegment {
  seg: Segment;
  /** Surface velocity at a contact point, for relative-velocity reflection. */
  velocityAt: (p: Vec) => Vec;
}

export function obstacleSegments(o: Obstacle, clock: number): MovingSegment[] {
  if (o.kind === 'bar') {
    const angle = barAngle(o, clock);
    const segs = rectSegments(o.pivot, o.length / 2, o.thickness / 2, angle);
    const w = o.angularSpeed;
    return segs.map((seg) => ({ seg, velocityAt: (p) => ({ x: -w * (p.y - o.pivot.y), y: w * (p.x - o.pivot.x) }) }));
  }
  const off = blockOffset(o, clock);
  const center = { x: o.center.x + o.axis.x * off, y: o.center.y + o.axis.y * off };
  const dOff = o.amplitude * o.speed * Math.cos(o.phase + o.speed * clock);
  const vel = { x: o.axis.x * dOff, y: o.axis.y * dOff };
  return rectSegments(center, o.width / 2, o.height / 2, 0).map((seg) => ({ seg, velocityAt: () => vel }));
}

// ---------------------------------------------------------------------------
// Collision primitives
// ---------------------------------------------------------------------------

interface Contact {
  nx: number;
  ny: number;
  depth: number;
  px: number;
  py: number;
}

/** Circle at p with radius r against segment; returns the push-out normal (towards the circle). */
export function circleSegmentContact(p: Vec, r: number, seg: Segment): Contact | null {
  const abx = seg.b.x - seg.a.x;
  const aby = seg.b.y - seg.a.y;
  const len2 = abx * abx + aby * aby;
  let t = len2 === 0 ? 0 : ((p.x - seg.a.x) * abx + (p.y - seg.a.y) * aby) / len2;
  if (t < 0) t = 0;
  else if (t > 1) t = 1;
  const cx = seg.a.x + abx * t;
  const cy = seg.a.y + aby * t;
  const dx = p.x - cx;
  const dy = p.y - cy;
  const d2 = dx * dx + dy * dy;
  if (d2 >= r * r) return null;
  const d = Math.sqrt(d2);
  if (d < 1e-9) {
    // Centre exactly on the segment: push along the segment's left normal.
    const l = Math.sqrt(len2) || 1;
    return { nx: -aby / l, ny: abx / l, depth: r, px: cx, py: cy };
  }
  return { nx: dx / d, ny: dy / d, depth: r - d, px: cx, py: cy };
}

export function surfaceFriction(course: Course, p: Vec): number {
  return pointInAny(p, course.sand) ? FRICTION_SAND : FRICTION_TURF;
}

// ---------------------------------------------------------------------------
// Stroke simulation
// ---------------------------------------------------------------------------

/**
 * Simulate one putt from `start` with direction `angle` (radians, y down) and `power` in 0..1.
 * `clock` is the obstacle clock at the start of the stroke (state.obstaclePhase).
 */
export function simulateStroke(course: Course, start: Vec, angle: number, power: number, clock: number): StrokeResult {
  const pw = Math.min(1, Math.max(0, power));
  const speed = pw * MAX_PUTT_SPEED;
  let x = start.x;
  let y = start.y;
  let vx = Math.cos(angle) * speed;
  let vy = Math.sin(angle) * speed;
  let t = 0;
  const frames: Keyframe[] = [{ t: 0, x, y, obs: obstacleValues(course, clock) }];
  const bounces: Bounce[] = [];
  let holed = false;
  let water = false;
  let nextKey = KEYFRAME_DT;
  const subDt = FIXED_DT / SUBSTEPS;
  let lastSafeX = x;
  let lastSafeY = y;
  const lastBounceAt = new Map<string, number>();

  const recordBounce = (key: string, kind: Bounce['kind']) => {
    const prev = lastBounceAt.get(key);
    if (prev !== undefined && t - prev < 0.05) return;
    lastBounceAt.set(key, t);
    bounces.push({ t: round3(t), x: round2(x), y: round2(y), kind });
  };

  outer: while (t < MAX_SIM_TIME) {
    for (let s = 0; s < SUBSTEPS; s++) {
      // Friction
      const sp = Math.hypot(vx, vy);
      if (sp > 0) {
        const f = surfaceFriction(course, { x, y }) * subDt;
        if (f >= sp) {
          vx = 0;
          vy = 0;
        } else {
          const k = (sp - f) / sp;
          vx *= k;
          vy *= k;
        }
      }
      // Integrate
      x += vx * subDt;
      y += vy * subDt;
      t += subDt;

      // Static walls
      for (let i = 0; i < course.walls.length; i++) {
        const c = circleSegmentContact({ x, y }, BALL_RADIUS, course.walls[i]!);
        if (!c) continue;
        x += c.nx * c.depth;
        y += c.ny * c.depth;
        const vn = vx * c.nx + vy * c.ny;
        if (vn < 0) {
          vx -= (1 + WALL_RESTITUTION) * vn * c.nx;
          vy -= (1 + WALL_RESTITUTION) * vn * c.ny;
          recordBounce(`w${i}`, 'wall');
        }
      }
      // Moving obstacles evaluated at the current clock
      const now = clock + t;
      for (let oi = 0; oi < course.obstacles.length; oi++) {
        const segs = obstacleSegments(course.obstacles[oi]!, now);
        for (let si = 0; si < segs.length; si++) {
          const ms = segs[si]!;
          const c = circleSegmentContact({ x, y }, BALL_RADIUS, ms.seg);
          if (!c) continue;
          x += c.nx * c.depth;
          y += c.ny * c.depth;
          const ov = ms.velocityAt({ x: c.px, y: c.py });
          const rvx = vx - ov.x;
          const rvy = vy - ov.y;
          const vn = rvx * c.nx + rvy * c.ny;
          if (vn < 0) {
            const nrx = rvx - (1 + WALL_RESTITUTION) * vn * c.nx;
            const nry = rvy - (1 + WALL_RESTITUTION) * vn * c.ny;
            vx = nrx + ov.x;
            vy = nry + ov.y;
            recordBounce(`o${oi}`, 'obstacle');
          }
        }
      }

      // Tunnelling guard: a ball that ends up off the turf is put back on its last safe spot.
      if (!pointInTurf(course, { x, y })) {
        x = lastSafeX;
        y = lastSafeY;
        vx *= -0.5;
        vy *= -0.5;
      } else {
        lastSafeX = x;
        lastSafeY = y;
      }

      // Water hazard
      if (pointInAny({ x, y }, course.water)) {
        water = true;
        vx = 0;
        vy = 0;
        break outer;
      }

      // Cup capture
      const hdx = x - course.hole.x;
      const hdy = y - course.hole.y;
      if (hdx * hdx + hdy * hdy < CUP_RADIUS * CUP_RADIUS) {
        const v = Math.hypot(vx, vy);
        if (v < CUP_CAPTURE_SPEED) {
          holed = true;
          x = course.hole.x;
          y = course.hole.y;
          vx = 0;
          vy = 0;
          break outer;
        }
        // Lip out: the rim steals some pace and nudges the ball sideways.
        const d = Math.hypot(hdx, hdy) || 1;
        const damp = 1 - 4 * subDt;
        vx = vx * damp + (hdx / d) * 400 * subDt;
        vy = vy * damp + (hdy / d) * 400 * subDt;
      }

      if (vx * vx + vy * vy < REST_SPEED * REST_SPEED) {
        vx = 0;
        vy = 0;
        break outer;
      }
      if (t >= nextKey) {
        frames.push({ t: round3(t), x: round2(x), y: round2(y), obs: obstacleValues(course, clock + t).map(round3) });
        nextKey += KEYFRAME_DT;
      }
    }
  }

  const finalPos: Vec = water ? { x: start.x, y: start.y } : holed ? { ...course.hole } : { x: round2(x), y: round2(y) };
  const last = frames[frames.length - 1]!;
  if (last.t !== round3(t) || last.x !== round2(x) || last.y !== round2(y)) {
    frames.push({ t: round3(t), x: round2(x), y: round2(y), obs: obstacleValues(course, clock + t).map(round3) });
  }
  return { frames, holed, water, bounces, final: finalPos, duration: round3(t) };
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}
function round3(n: number): number {
  return Math.round(n * 1000) / 1000;
}
