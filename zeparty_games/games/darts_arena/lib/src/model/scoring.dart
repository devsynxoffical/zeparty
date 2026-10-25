import 'dart:math' as math;

/// Exact dartboard scoring geometry in board units (board radius 1.0 = outer edge
/// of the double ring). Screen convention: x right, y down, 20 centred on (0, -1).
///
/// Mirror of backend/src/games/darts_arena/scoring.ts, checked against
/// tests/fixtures/darts_arena_scoring.json. Used only for the aim preview; the
/// server decides every real score.
class BoardGeometry {
  BoardGeometry._();
  static const double innerBull = 0.0373;
  static const double outerBull = 0.0935;
  static const double trebleInner = 0.582;
  static const double trebleOuter = 0.629;
  static const double doubleInner = 0.953;
  static const double doubleOuter = 1.0;
  static const double clampRadius = 1.08;
  static const double maxAimRadius = 1.1;
  static const double segmentDegrees = 18;
}

/// Segment numbers clockwise from the top (20 at 12 o'clock).
const List<int> kSegments = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
const int kBull = 25;

class DartScore {
  const DartScore({required this.segment, required this.multiplier, required this.points, required this.label});
  final int segment;
  final int multiplier;
  final int points;
  final String label;

  bool get isMiss => multiplier == 0;
  bool get isBull => segment == kBull;

  @override
  bool operator ==(Object other) => other is DartScore && other.segment == segment && other.multiplier == multiplier && other.points == points && other.label == label;
  @override
  int get hashCode => Object.hash(segment, multiplier, points, label);
  @override
  String toString() => 'DartScore($label, $points)';
}

const DartScore kMiss = DartScore(segment: 0, multiplier: 0, points: 0, label: 'MISS');

/// Segment index (0..19, clockwise from the top) for a point off centre.
int segmentIndexAt(double x, double y) {
  var deg = math.atan2(x, -y) * 180 / math.pi;
  if (deg < 0) deg += 360;
  return (deg / BoardGeometry.segmentDegrees).round() % kSegments.length;
}

DartScore scoreAt(double x, double y) {
  final r = math.sqrt(x * x + y * y);
  if (!r.isFinite || r > BoardGeometry.doubleOuter) return kMiss;
  if (r <= BoardGeometry.innerBull) return const DartScore(segment: kBull, multiplier: 2, points: 50, label: 'BULL');
  if (r <= BoardGeometry.outerBull) return const DartScore(segment: kBull, multiplier: 1, points: 25, label: '25');
  final segment = kSegments[segmentIndexAt(x, y)];
  if (r >= BoardGeometry.trebleInner && r <= BoardGeometry.trebleOuter) return DartScore(segment: segment, multiplier: 3, points: segment * 3, label: 'T$segment');
  if (r >= BoardGeometry.doubleInner) return DartScore(segment: segment, multiplier: 2, points: segment * 2, label: 'D$segment');
  return DartScore(segment: segment, multiplier: 1, points: segment, label: '$segment');
}

/// Sigma the server applies for a release quality (mirror of `sigmaFor`).
double sigmaFor(double baseSigma, double release) => baseSigma * (1.6 - release.clamp(0.0, 1.0));

/// Board-unit centre of a segment ring (for aim presets and tests).
math.Point<double> pointFor(int segment, int multiplier) {
  if (segment == kBull) return const math.Point(0, 0);
  final idx = kSegments.indexOf(segment);
  final r = switch (multiplier) {
    3 => (BoardGeometry.trebleInner + BoardGeometry.trebleOuter) / 2,
    2 => (BoardGeometry.doubleInner + BoardGeometry.doubleOuter) / 2,
    _ => (BoardGeometry.outerBull + BoardGeometry.trebleInner) / 2,
  };
  final rad = idx * BoardGeometry.segmentDegrees * math.pi / 180;
  return math.Point(math.sin(rad) * r, -math.cos(rad) * r);
}
