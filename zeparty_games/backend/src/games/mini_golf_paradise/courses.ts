/**
 * Hand-designed hole layouts for Mini Golf Paradise, expressed as plain data in course units.
 * Width is always 100, height varies (up to 180). y grows downwards (screen convention).
 *
 * The same data is written to tests/fixtures/mini_golf_courses.json and embedded in every
 * state's `course` field so the client renders exactly what the server simulates.
 */
export interface Vec {
  x: number;
  y: number;
}

export interface Segment {
  a: Vec;
  b: Vec;
}

/** A rotating bar: a rectangle length x thickness spinning around `pivot`. */
export interface BarObstacle {
  kind: 'bar';
  pivot: Vec;
  length: number;
  thickness: number;
  /** Radians per second, sign is direction. */
  angularSpeed: number;
  /** Angle at clock 0. */
  phase: number;
}

/** A block sliding back and forth along `axis` around `center`. */
export interface BlockObstacle {
  kind: 'block';
  center: Vec;
  width: number;
  height: number;
  /** Unit axis of motion. */
  axis: Vec;
  /** Peak offset along the axis, in units. */
  amplitude: number;
  /** Oscillation angular speed, radians per second. */
  speed: number;
  phase: number;
}

export type Obstacle = BarObstacle | BlockObstacle;

export interface Course {
  id: string;
  name: string;
  par: number;
  width: number;
  height: number;
  /** Outer turf outline, simple polygon, implicitly closed. */
  turf: Vec[];
  /** Holes cut out of the turf (rock islands). Their outlines are walls too. */
  islands: Vec[][];
  /** Rock wall segments the ball bounces off (restitution 0.7). */
  walls: Segment[];
  sand: Vec[][];
  water: Vec[][];
  obstacles: Obstacle[];
  tee: Vec;
  hole: Vec;
}

const v = (x: number, y: number): Vec => ({ x, y });

export function rectPoly(x: number, y: number, w: number, h: number): Vec[] {
  return [v(x, y), v(x + w, y), v(x + w, y + h), v(x, y + h)];
}

/** Closed outline of a polygon as wall segments. */
export function outlineWalls(poly: Vec[]): Segment[] {
  const out: Segment[] = [];
  for (let i = 0; i < poly.length; i++) {
    out.push({ a: poly[i]!, b: poly[(i + 1) % poly.length]! });
  }
  return out;
}

interface CourseDraft {
  id: string;
  name: string;
  par: number;
  height: number;
  turf: Vec[];
  islands?: Vec[][];
  extraWalls?: Segment[];
  sand?: Vec[][];
  water?: Vec[][];
  obstacles?: Obstacle[];
  tee: Vec;
  hole: Vec;
}

function build(d: CourseDraft): Course {
  const islands = d.islands ?? [];
  return {
    id: d.id,
    name: d.name,
    par: d.par,
    width: 100,
    height: d.height,
    turf: d.turf,
    islands,
    walls: [...outlineWalls(d.turf), ...islands.flatMap(outlineWalls), ...(d.extraWalls ?? [])],
    sand: d.sand ?? [],
    water: d.water ?? [],
    obstacles: d.obstacles ?? [],
    tee: d.tee,
    hole: d.hole,
  };
}

export const COURSES: Course[] = [
  build({
    id: 'lagoon_straight',
    name: 'Lagoon Straight',
    par: 2,
    height: 120,
    turf: rectPoly(22, 10, 56, 100),
    sand: [rectPoly(30, 50, 40, 16)],
    tee: v(50, 96),
    hole: v(50, 26),
  }),
  build({
    id: 'coral_dogleg',
    name: 'Coral Dogleg',
    par: 3,
    height: 140,
    turf: [v(15, 20), v(85, 20), v(85, 60), v(45, 60), v(45, 130), v(15, 130)],
    water: [rectPoly(15, 20, 24, 18)],
    sand: [rectPoly(52, 46, 33, 14)],
    tee: v(30, 116),
    hole: v(70, 38),
  }),
  build({
    id: 'tiki_windmill',
    name: 'Tiki Windmill',
    par: 3,
    height: 170,
    turf: rectPoly(25, 10, 50, 150),
    sand: [rectPoly(25, 70, 8, 30), rectPoly(67, 70, 8, 30)],
    obstacles: [{ kind: 'bar', pivot: v(50, 85), length: 40, thickness: 3, angularSpeed: 1.1, phase: 0 }],
    tee: v(50, 146),
    hole: v(50, 30),
  }),
  build({
    id: 'waterfall_bridge',
    name: 'Waterfall Bridge',
    par: 4,
    height: 180,
    turf: rectPoly(15, 10, 70, 160),
    islands: [rectPoly(46, 118, 8, 8)],
    water: [rectPoly(15, 82, 26, 22), rectPoly(59, 82, 26, 22)],
    sand: [rectPoly(15, 130, 18, 18)],
    obstacles: [{ kind: 'block', center: v(50, 50), width: 18, height: 5, axis: v(1, 0), amplitude: 22, speed: 0.9, phase: 0 }],
    tee: v(50, 155),
    hole: v(50, 24),
  }),
  build({
    id: 'volcano_isle',
    name: 'Volcano Isle',
    par: 4,
    height: 180,
    turf: [v(10, 10), v(90, 10), v(90, 125), v(45, 125), v(45, 170), v(10, 170), v(10, 85), v(55, 85), v(55, 40), v(10, 40)],
    sand: [rectPoly(57, 50, 31, 16)],
    water: [rectPoly(70, 12, 18, 14)],
    obstacles: [{ kind: 'bar', pivot: v(50, 105), length: 30, thickness: 3, angularSpeed: -1.3, phase: 0.6 }],
    tee: v(27, 155),
    hole: v(30, 25),
  }),
];

export function courseByIndex(i: number): Course {
  const c = COURSES[i];
  if (!c) throw new Error(`unknown course index ${i}`);
  return c;
}

// ---------------------------------------------------------------------------
// Geometry helpers (shared by physics and validation)
// ---------------------------------------------------------------------------

/** Ray-casting point in polygon test. Points on the edge count as inside. */
export function pointInPolygon(p: Vec, poly: Vec[]): boolean {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i]!;
    const b = poly[j]!;
    const intersects = a.y > p.y !== b.y > p.y && p.x < ((b.x - a.x) * (p.y - a.y)) / (b.y - a.y) + a.x;
    if (intersects) inside = !inside;
  }
  return inside;
}

export function pointInAny(p: Vec, polys: Vec[][]): boolean {
  return polys.some((poly) => pointInPolygon(p, poly));
}

export function pointInTurf(course: Course, p: Vec): boolean {
  return pointInPolygon(p, course.turf) && !pointInAny(p, course.islands);
}

/** Returns a list of problems with a course, empty when it is valid. */
export function validateCourse(course: Course): string[] {
  const problems: string[] = [];
  if (course.width !== 100) problems.push('width must be 100');
  if (course.height <= 0 || course.height > 180) problems.push('height must be in (0, 180]');
  if (course.turf.length < 3) problems.push('turf needs at least 3 points');
  if (!pointInTurf(course, course.tee)) problems.push('tee outside turf');
  if (!pointInTurf(course, course.hole)) problems.push('hole outside turf');
  if (pointInAny(course.tee, course.water)) problems.push('tee in water');
  if (pointInAny(course.hole, course.water)) problems.push('hole in water');
  if (pointInAny(course.hole, course.sand)) problems.push('hole in sand');
  const dx = course.tee.x - course.hole.x;
  const dy = course.tee.y - course.hole.y;
  if (Math.hypot(dx, dy) < 20) problems.push('tee too close to hole');
  for (const p of [...course.turf, ...course.islands.flat(), ...course.sand.flat(), ...course.water.flat()]) {
    if (p.x < 0 || p.x > course.width || p.y < 0 || p.y > course.height) problems.push(`point ${p.x},${p.y} outside bounds`);
  }
  if (course.par < 1 || course.par > 8) problems.push('par out of range');
  return problems;
}
