import 'dart:math' as math;

/// Physics constants mirrored from backend/src/games/mini_golf_paradise/physics.ts.
/// The client never simulates outcomes; these only drive rendering and the aim guide.
const double ballRadius = 1.5;
const double cupRadius = 2.2;
const double maxPuttSpeed = 170;

/// A point or vector in course units (width 100, y grows downwards).
class Vec {
  const Vec(this.x, this.y);
  final double x;
  final double y;

  factory Vec.fromJson(Map<String, dynamic> j) => Vec((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  Vec operator +(Vec o) => Vec(x + o.x, y + o.y);
  Vec operator -(Vec o) => Vec(x - o.x, y - o.y);
  Vec operator *(double k) => Vec(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  double dot(Vec o) => x * o.x + y * o.y;
  Vec get normalized {
    final l = length;
    return l == 0 ? const Vec(0, 0) : Vec(x / l, y / l);
  }

  double distanceTo(Vec o) => (this - o).length;

  @override
  bool operator ==(Object other) => other is Vec && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'Vec($x, $y)';
}

class Seg {
  const Seg(this.a, this.b);
  final Vec a;
  final Vec b;
  factory Seg.fromJson(Map<String, dynamic> j) => Seg(Vec.fromJson(j['a'] as Map<String, dynamic>), Vec.fromJson(j['b'] as Map<String, dynamic>));
}

List<Vec> _poly(dynamic raw) => (raw as List<dynamic>).map((p) => Vec.fromJson(p as Map<String, dynamic>)).toList();
List<List<Vec>> _polys(dynamic raw) => (raw as List<dynamic>? ?? const []).map(_poly).toList();

/// Moving obstacle. Its scalar state (angle or offset) is a function of the course clock
/// and is carried per keyframe during a replay so the client stays in sync with the server.
sealed class Obstacle {
  const Obstacle();

  factory Obstacle.fromJson(Map<String, dynamic> j) => switch (j['kind']) {
        'bar' => BarObstacle.fromJson(j),
        'block' => BlockObstacle.fromJson(j),
        _ => throw FormatException('unknown obstacle kind ${j['kind']}'),
      };

  /// Scalar state at a given clock (seconds).
  double valueAt(double clock);

  /// The four edge segments of the obstacle rectangle for a given scalar state.
  List<Seg> segmentsFor(double value);

  /// Centre and rotation for rendering given the scalar state.
  (Vec center, double angle, double halfW, double halfH) poseFor(double value);
}

class BarObstacle extends Obstacle {
  const BarObstacle({required this.pivot, required this.length, required this.thickness, required this.angularSpeed, required this.phase});
  final Vec pivot;
  final double length;
  final double thickness;
  final double angularSpeed;
  final double phase;

  factory BarObstacle.fromJson(Map<String, dynamic> j) => BarObstacle(
        pivot: Vec.fromJson(j['pivot'] as Map<String, dynamic>),
        length: (j['length'] as num).toDouble(),
        thickness: (j['thickness'] as num).toDouble(),
        angularSpeed: (j['angularSpeed'] as num).toDouble(),
        phase: (j['phase'] as num?)?.toDouble() ?? 0,
      );

  @override
  double valueAt(double clock) => phase + angularSpeed * clock;
  @override
  List<Seg> segmentsFor(double value) => rectSegments(pivot, length / 2, thickness / 2, value);
  @override
  (Vec, double, double, double) poseFor(double value) => (pivot, value, length / 2, thickness / 2);
}

class BlockObstacle extends Obstacle {
  const BlockObstacle({required this.center, required this.width, required this.height, required this.axis, required this.amplitude, required this.speed, required this.phase});
  final Vec center;
  final double width;
  final double height;
  final Vec axis;
  final double amplitude;
  final double speed;
  final double phase;

  factory BlockObstacle.fromJson(Map<String, dynamic> j) => BlockObstacle(
        center: Vec.fromJson(j['center'] as Map<String, dynamic>),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        axis: Vec.fromJson(j['axis'] as Map<String, dynamic>),
        amplitude: (j['amplitude'] as num).toDouble(),
        speed: (j['speed'] as num).toDouble(),
        phase: (j['phase'] as num?)?.toDouble() ?? 0,
      );

  @override
  double valueAt(double clock) => amplitude * math.sin(phase + speed * clock);
  Vec centerFor(double value) => center + axis * value;
  @override
  List<Seg> segmentsFor(double value) => rectSegments(centerFor(value), width / 2, height / 2, 0);
  @override
  (Vec, double, double, double) poseFor(double value) => (centerFor(value), 0, width / 2, height / 2);
}

List<Seg> rectSegments(Vec center, double halfW, double halfH, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  Vec corner(double lx, double ly) => Vec(center.x + lx * c - ly * s, center.y + lx * s + ly * c);
  final p0 = corner(-halfW, -halfH);
  final p1 = corner(halfW, -halfH);
  final p2 = corner(halfW, halfH);
  final p3 = corner(-halfW, halfH);
  return [Seg(p0, p1), Seg(p1, p2), Seg(p2, p3), Seg(p3, p0)];
}

/// A hole layout exactly as the server defines it (see courses.ts).
class Course {
  const Course({
    required this.id,
    required this.name,
    required this.par,
    required this.width,
    required this.height,
    required this.turf,
    required this.islands,
    required this.walls,
    required this.sand,
    required this.water,
    required this.obstacles,
    required this.tee,
    required this.hole,
  });

  final String id;
  final String name;
  final int par;
  final double width;
  final double height;
  final List<Vec> turf;
  final List<List<Vec>> islands;
  final List<Seg> walls;
  final List<List<Vec>> sand;
  final List<List<Vec>> water;
  final List<Obstacle> obstacles;
  final Vec tee;
  final Vec hole;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String,
        name: j['name'] as String,
        par: (j['par'] as num).toInt(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        turf: _poly(j['turf']),
        islands: _polys(j['islands']),
        walls: (j['walls'] as List<dynamic>).map((w) => Seg.fromJson(w as Map<String, dynamic>)).toList(),
        sand: _polys(j['sand']),
        water: _polys(j['water']),
        obstacles: (j['obstacles'] as List<dynamic>? ?? const []).map((o) => Obstacle.fromJson(o as Map<String, dynamic>)).toList(),
        tee: Vec.fromJson(j['tee'] as Map<String, dynamic>),
        hole: Vec.fromJson(j['hole'] as Map<String, dynamic>),
      );

  bool containsTurf(Vec p) => pointInPolygon(p, turf) && !islands.any((i) => pointInPolygon(p, i));
  bool inSand(Vec p) => sand.any((s) => pointInPolygon(p, s));
  bool inWater(Vec p) => water.any((w) => pointInPolygon(p, w));

  List<double> obstacleValuesAt(double clock) => [for (final o in obstacles) o.valueAt(clock)];

  /// Every obstacle edge for the given scalar states (one per obstacle).
  List<Seg> obstacleSegments(List<double> values) {
    final out = <Seg>[];
    for (var i = 0; i < obstacles.length; i++) {
      out.addAll(obstacles[i].segmentsFor(i < values.length ? values[i] : obstacles[i].valueAt(0)));
    }
    return out;
  }
}

/// Ray-casting point in polygon test (same algorithm as the server).
bool pointInPolygon(Vec p, List<Vec> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i];
    final b = poly[j];
    final intersects = (a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
    if (intersects) inside = !inside;
  }
  return inside;
}

/// First hit of a ray (origin, unit direction) against a set of segments, treating the ball
/// as a circle of [radius]. Returns the travel distance and the surface normal, or null.
({double distance, Vec normal, Vec point})? raycastSegments(Vec origin, Vec dir, List<Seg> segs, {double radius = ballRadius, double maxDistance = 400}) {
  double best = maxDistance;
  Vec? bestNormal;
  for (final s in segs) {
    final e = s.b - s.a;
    final len = e.length;
    if (len == 0) continue;
    final n0 = Vec(-e.y / len, e.x / len);
    // Normal facing the ray origin.
    final side = (origin - s.a).dot(n0);
    final n = side >= 0 ? n0 : Vec(-n0.x, -n0.y);
    final denom = dir.dot(n);
    if (denom >= -1e-9) continue; // moving away or parallel
    // Offset the segment by the ball radius along n and intersect.
    final t = (radius - (origin - s.a).dot(n)) / denom;
    if (t <= 0 || t >= best) continue;
    final hit = origin + dir * t;
    final along = (hit - s.a).dot(e) / (len * len);
    if (along < -radius / len || along > 1 + radius / len) continue;
    best = t;
    bestNormal = n;
  }
  if (bestNormal == null) return null;
  return (distance: best, normal: bestNormal, point: origin + dir * best);
}

/// Name and par of every server course by index (mirror of courses.ts metadata; the
/// full geometry always arrives in the state). Checked against the shared fixture.
class CourseInfo {
  const CourseInfo(this.id, this.name, this.par);
  final String id;
  final String name;
  final int par;
}

const List<CourseInfo> kCourseCatalog = [
  CourseInfo('lagoon_straight', 'Lagoon Straight', 2),
  CourseInfo('coral_dogleg', 'Coral Dogleg', 3),
  CourseInfo('tiki_windmill', 'Tiki Windmill', 3),
  CourseInfo('waterfall_bridge', 'Waterfall Bridge', 4),
  CourseInfo('volcano_isle', 'Volcano Isle', 4),
];

/// Par of the hole at [holeIndex] given the rules' course indices; falls back to [fallback].
int parForHole(List<int> holes, int holeIndex, {int fallback = 3}) {
  if (holeIndex < 0 || holeIndex >= holes.length) return fallback;
  final ci = holes[holeIndex];
  if (ci < 0 || ci >= kCourseCatalog.length) return fallback;
  return kCourseCatalog[ci].par;
}
