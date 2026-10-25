/**
 * Deterministic 2D air hockey physics in table units. Portrait table: x in [0, width],
 * y in [0, height]. Seat 0 defends the bottom goal (y = height), seat 1 the top (y = 0).
 *
 * Every function here mutates the objects passed in and allocates nothing, so the 60 Hz
 * tick stays cheap. The same constants and clamps are mirrored in the Flutter client for
 * local paddle prediction (games/air_hockey/lib/src/model/physics.dart) and checked against
 * tests/fixtures/air_hockey_clamp.json.
 */
export const TABLE_WIDTH = 100;
export const TABLE_HEIGHT = 180;
export const GOAL_WIDTH = 36;
export const PUCK_RADIUS = 3;
export const PADDLE_RADIUS = 6;
export const PUCK_MAX_SPEED = 260; // units per second
export const PADDLE_MAX_SPEED = 220; // units per second
export const WALL_RESTITUTION = 0.9;
export const PADDLE_RESTITUTION = 0.95;
/** Fraction of puck speed lost per second (linear drag). */
export const PUCK_FRICTION = 0.2;
/** Speed of the puck when it is released at a faceoff. */
export const FACEOFF_SPEED = 45;
export const TICK_MS = 1000 / 60;
/** How much paddle travel a seat may bank while idle (prevents input bursts teleporting). */
export const MOVE_BUDGET_CAP_MS = 100;
/** Paddle velocity is treated as zero once no input has arrived for this long. */
export const PADDLE_IDLE_MS = 80;
/** Minimum puck speed on a hit so a resting paddle still nudges the puck. */
export const MIN_HIT_SPEED = 20;

export interface Body {
  x: number;
  y: number;
  vx: number;
  vy: number;
}

export interface Point {
  x: number;
  y: number;
}

export interface PaddleBounds {
  minX: number;
  maxX: number;
  minY: number;
  maxY: number;
}

const HALF = TABLE_HEIGHT / 2;
const SEAT0_BOUNDS: PaddleBounds = { minX: PADDLE_RADIUS, maxX: TABLE_WIDTH - PADDLE_RADIUS, minY: HALF + PADDLE_RADIUS, maxY: TABLE_HEIGHT - PADDLE_RADIUS };
const SEAT1_BOUNDS: PaddleBounds = { minX: PADDLE_RADIUS, maxX: TABLE_WIDTH - PADDLE_RADIUS, minY: PADDLE_RADIUS, maxY: HALF - PADDLE_RADIUS };

/** Where a seat's paddle centre may be: inside the walls and strictly on its own half. */
export function paddleBounds(seat: number): PaddleBounds {
  return seat === 0 ? SEAT0_BOUNDS : SEAT1_BOUNDS;
}

/** Default paddle rest position for a seat (in front of its own goal). */
export function paddleHome(seat: number, out: Point): Point {
  out.x = TABLE_WIDTH / 2;
  out.y = seat === 0 ? TABLE_HEIGHT - 24 : 24;
  return out;
}

export function clampPaddleToHalf(seat: number, x: number, y: number, out: Point): Point {
  const b = paddleBounds(seat);
  out.x = x < b.minX ? b.minX : x > b.maxX ? b.maxX : x;
  out.y = y < b.minY ? b.minY : y > b.maxY ? b.maxY : y;
  return out;
}

/**
 * Move from (fromX, fromY) toward (toX, toY) by at most `maxDist`. Writes the reached
 * point into `out` and returns the distance actually travelled.
 */
export function limitStep(fromX: number, fromY: number, toX: number, toY: number, maxDist: number, out: Point): number {
  const dx = toX - fromX;
  const dy = toY - fromY;
  const d = Math.sqrt(dx * dx + dy * dy);
  if (d <= maxDist || d === 0) {
    out.x = toX;
    out.y = toY;
    return d;
  }
  const k = maxDist / d;
  out.x = fromX + dx * k;
  out.y = fromY + dy * k;
  return maxDist;
}

/** Speed clamp applied to the puck after every impulse. */
export function clampPuckSpeed(p: Body): void {
  const s2 = p.vx * p.vx + p.vy * p.vy;
  if (s2 > PUCK_MAX_SPEED * PUCK_MAX_SPEED) {
    const k = PUCK_MAX_SPEED / Math.sqrt(s2);
    p.vx *= k;
    p.vy *= k;
  }
}

/** Position integration plus linear drag. */
export function integratePuck(p: Body, dtS: number): void {
  p.x += p.vx * dtS;
  p.y += p.vy * dtS;
  const drag = 1 - PUCK_FRICTION * dtS;
  const k = drag < 0 ? 0 : drag;
  p.vx *= k;
  p.vy *= k;
  if (Math.abs(p.vx) < 0.01) p.vx = 0;
  if (Math.abs(p.vy) < 0.01) p.vy = 0;
}

/** True when the whole puck fits between the goal posts at this x. */
export function inGoalMouth(x: number): boolean {
  return Math.abs(x - TABLE_WIDTH / 2) + PUCK_RADIUS <= GOAL_WIDTH / 2;
}

/**
 * Wall bounces. Returns true when the puck bounced this call; `at` then holds the contact
 * point (for the `wall_bounce` event). Short edges are open inside the goal mouth.
 */
export function resolveWalls(p: Body, at: Point): boolean {
  let hit = false;
  if (p.x - PUCK_RADIUS < 0) {
    p.x = PUCK_RADIUS;
    if (p.vx < 0) p.vx = -p.vx * WALL_RESTITUTION;
    at.x = 0;
    at.y = p.y;
    hit = true;
  } else if (p.x + PUCK_RADIUS > TABLE_WIDTH) {
    p.x = TABLE_WIDTH - PUCK_RADIUS;
    if (p.vx > 0) p.vx = -p.vx * WALL_RESTITUTION;
    at.x = TABLE_WIDTH;
    at.y = p.y;
    hit = true;
  }
  if (p.y - PUCK_RADIUS < 0 && !inGoalMouth(p.x) && p.y > -PUCK_RADIUS) {
    p.y = PUCK_RADIUS;
    if (p.vy < 0) p.vy = -p.vy * WALL_RESTITUTION;
    at.x = p.x;
    at.y = 0;
    hit = true;
  } else if (p.y + PUCK_RADIUS > TABLE_HEIGHT && !inGoalMouth(p.x) && p.y < TABLE_HEIGHT + PUCK_RADIUS) {
    p.y = TABLE_HEIGHT - PUCK_RADIUS;
    if (p.vy > 0) p.vy = -p.vy * WALL_RESTITUTION;
    at.x = p.x;
    at.y = TABLE_HEIGHT;
    hit = true;
  }
  return hit;
}

/**
 * Goal test: the puck is fully past a goal line inside the mouth. Returns the seat that
 * conceded (0 = bottom goal, 1 = top goal) or -1.
 */
export function concedingSeat(p: Body): number {
  if (Math.abs(p.x - TABLE_WIDTH / 2) > GOAL_WIDTH / 2) return -1;
  if (p.y + PUCK_RADIUS < 0) return 1;
  if (p.y - PUCK_RADIUS > TABLE_HEIGHT) return 0;
  return -1;
}

/**
 * Circle-circle collision between puck and paddle. The puck is pushed out along the
 * contact normal and the relative velocity is reflected, so the paddle's own velocity is
 * imparted. When the paddle just moved from (prevX, prevY) and swept over the puck, the
 * contact normal follows the paddle's direction of travel so the puck is pushed ahead of
 * the paddle instead of popping out behind it. Returns the resulting puck speed when a hit
 * happened, otherwise -1.
 */
export function collidePaddle(p: Body, paddle: Body, prevX: number = paddle.x, prevY: number = paddle.y): number {
  const dx = p.x - paddle.x;
  const dy = p.y - paddle.y;
  const minDist = PUCK_RADIUS + PADDLE_RADIUS;
  const d2 = dx * dx + dy * dy;
  if (d2 >= minDist * minDist) return -1;
  let nx: number;
  let ny: number;
  const mx = paddle.x - prevX;
  const my = paddle.y - prevY;
  const moved2 = mx * mx + my * my;
  const d = Math.sqrt(d2);
  if (moved2 > 1e-9 && dx * mx + dy * my < 0) {
    // Swept into the puck from behind: push along the travel direction.
    const m = Math.sqrt(moved2);
    nx = mx / m;
    ny = my / m;
  } else if (d < 1e-6) {
    nx = 0;
    ny = paddle.y > TABLE_HEIGHT / 2 ? -1 : 1; // push toward the centre line
  } else {
    nx = dx / d;
    ny = dy / d;
  }
  // Separate.
  p.x = paddle.x + nx * minDist;
  p.y = paddle.y + ny * minDist;
  // Relative velocity along the normal.
  const rvx = p.vx - paddle.vx;
  const rvy = p.vy - paddle.vy;
  const vn = rvx * nx + rvy * ny;
  if (vn >= 0) {
    // Already separating along the normal: contact without an impulse.
    return -1;
  }
  const j = -(1 + PADDLE_RESTITUTION) * vn;
  p.vx = rvx + j * nx + paddle.vx;
  p.vy = rvy + j * ny + paddle.vy;
  let speed = Math.sqrt(p.vx * p.vx + p.vy * p.vy);
  if (speed < MIN_HIT_SPEED) {
    if (speed < 1e-6) {
      p.vx = nx * MIN_HIT_SPEED;
      p.vy = ny * MIN_HIT_SPEED;
    } else {
      const k = MIN_HIT_SPEED / speed;
      p.vx *= k;
      p.vy *= k;
    }
    speed = MIN_HIT_SPEED;
  }
  clampPuckSpeed(p);
  return Math.min(speed, PUCK_MAX_SPEED);
}

/** Clamp a paddle's reported velocity to the advertised maximum. */
export function clampPaddleSpeed(p: Body): void {
  const s2 = p.vx * p.vx + p.vy * p.vy;
  if (s2 > PADDLE_MAX_SPEED * PADDLE_MAX_SPEED) {
    const k = PADDLE_MAX_SPEED / Math.sqrt(s2);
    p.vx *= k;
    p.vy *= k;
  }
}

/** Number of physics substeps for a tick so a fast puck never tunnels through a paddle. */
export function substepsFor(dtMs: number): number {
  const n = Math.ceil(dtMs / (TICK_MS / 2));
  return n < 1 ? 1 : n > 24 ? 24 : n;
}
