import 'dart:math' as math;

/// Board geometry mirrored from backend/src/games/carrom_masters/layout.ts.
/// The playfield is the square 0..100 (board units), x right, y down. Edge 0
/// is the bottom, 1 right, 2 top, 3 left. A shooter frame is the board rotated
/// so that shooter's edge sits at the bottom.
const double boardSize = 100;
const double pocketRadius = 2.6;
const double pocketInset = 2.6;
const double coinRadius = 1.6;
const double strikerRadius = 2.1;
const double baselineY = 88;
const double baselineXMin = 18;
const double baselineXMax = 82;
const double maxShotSpeed = 140;

/// Immutable 2D point in board units.
class BPoint {
  const BPoint(this.x, this.y);
  final double x;
  final double y;

  BPoint operator +(BPoint o) => BPoint(x + o.x, y + o.y);
  BPoint operator -(BPoint o) => BPoint(x - o.x, y - o.y);
  BPoint operator *(double k) => BPoint(x * k, y * k);
  double get length => math.sqrt(x * x + y * y);
  BPoint get normalized {
    final l = length;
    return l < 1e-12 ? const BPoint(0, 0) : BPoint(x / l, y / l);
  }

  double distanceTo(BPoint o) => (this - o).length;

  @override
  bool operator ==(Object other) => other is BPoint && (other.x - x).abs() < 1e-9 && (other.y - y).abs() < 1e-9;
  @override
  int get hashCode => Object.hash((x * 1e6).round(), (y * 1e6).round());
  @override
  String toString() => 'BPoint($x, $y)';
}

const BPoint boardCenter = BPoint(boardSize / 2, boardSize / 2);

const List<BPoint> pockets = [
  BPoint(pocketInset, pocketInset),
  BPoint(boardSize - pocketInset, pocketInset),
  BPoint(boardSize - pocketInset, boardSize - pocketInset),
  BPoint(pocketInset, boardSize - pocketInset),
];

/// Shooter frame -> board coordinates.
BPoint toBoard(int edge, BPoint p) {
  switch (((edge % 4) + 4) % 4) {
    case 0:
      return p;
    case 1:
      return BPoint(p.y, boardSize - p.x);
    case 2:
      return BPoint(boardSize - p.x, boardSize - p.y);
    default:
      return BPoint(boardSize - p.y, p.x);
  }
}

/// Board coordinates -> shooter frame for [edge]. Inverse of [toBoard].
BPoint toFrame(int edge, BPoint p) {
  switch (((edge % 4) + 4) % 4) {
    case 0:
      return p;
    case 1:
      return BPoint(boardSize - p.y, p.x);
    case 2:
      return BPoint(boardSize - p.x, boardSize - p.y);
    default:
      return BPoint(p.y, boardSize - p.x);
  }
}

/// Rotate a direction vector from the shooter frame into board space.
BPoint vectorToBoard(int edge, BPoint v) => toBoard(edge, v) - toBoard(edge, const BPoint(0, 0));

/// Rotate a direction vector from board space into the shooter frame.
BPoint vectorToFrame(int edge, BPoint v) => toFrame(edge, v) - toFrame(edge, const BPoint(0, 0));

/// Shot direction in the shooter frame for a mathematical angle (pi/2 = straight at the opponent).
BPoint shotDirection(double angle) => BPoint(math.cos(angle), -math.sin(angle));

/// Inverse of [shotDirection] for a frame-space direction vector.
double angleForDirection(BPoint dir) => math.atan2(-dir.y, dir.x);

/// One segment of the aiming guide: from [from] to [to] in frame units.
class GuideSegment {
  const GuideSegment(this.from, this.to);
  final BPoint from;
  final BPoint to;
}

/// Client-side aiming guide for feel only: the striker's straight path until it
/// meets a cushion, plus one reflected segment. Ignores coins on purpose; the
/// server simulation is the only authority on what actually happens.
List<GuideSegment> aimGuide(BPoint origin, BPoint direction, {double radius = strikerRadius, double maxLength = 140, double reflectionLength = 22}) {
  final d = direction.normalized;
  if (d.length == 0) return const [];
  final first = _rayToCushion(origin, d, radius);
  final firstEnd = first.$1;
  final travelled = origin.distanceTo(firstEnd);
  if (travelled >= maxLength) return [GuideSegment(origin, origin + d * maxLength)];
  final reflected = first.$2 == _Axis.x ? BPoint(-d.x, d.y) : BPoint(d.x, -d.y);
  final second = _rayToCushion(firstEnd, reflected, radius).$1;
  final len = math.min(reflectionLength, firstEnd.distanceTo(second));
  return [GuideSegment(origin, firstEnd), GuideSegment(firstEnd, firstEnd + reflected * len)];
}

enum _Axis { x, y }

(BPoint, _Axis) _rayToCushion(BPoint o, BPoint d, double r) {
  var best = double.infinity;
  var axis = _Axis.x;
  if (d.x > 1e-9) {
    final t = (boardSize - r - o.x) / d.x;
    if (t < best) {
      best = t;
      axis = _Axis.x;
    }
  } else if (d.x < -1e-9) {
    final t = (r - o.x) / d.x;
    if (t < best) {
      best = t;
      axis = _Axis.x;
    }
  }
  if (d.y > 1e-9) {
    final t = (boardSize - r - o.y) / d.y;
    if (t < best) {
      best = t;
      axis = _Axis.y;
    }
  } else if (d.y < -1e-9) {
    final t = (r - o.y) / d.y;
    if (t < best) {
      best = t;
      axis = _Axis.y;
    }
  }
  if (!best.isFinite || best < 0) best = 0;
  return (o + d * best, axis);
}

/// True when a striker centred at [p] (frame units) would overlap any coin.
bool strikerOverlaps(BPoint p, Iterable<BPoint> coins) => coins.any((c) => c.distanceTo(p) < coinRadius + strikerRadius);

/// Nearest legal baseline x to [x] that does not overlap a coin, searched
/// outward in 0.5 unit steps. Returns null when the whole baseline is blocked.
double? nearestFreeBaselineX(double x, Iterable<BPoint> coins) {
  final start = x.clamp(baselineXMin, baselineXMax);
  for (var step = 0.0; step <= baselineXMax - baselineXMin; step += 0.5) {
    for (final cand in [start - step, start + step]) {
      if (cand < baselineXMin || cand > baselineXMax) continue;
      if (!strikerOverlaps(BPoint(cand, baselineY), coins)) return cand;
    }
  }
  return null;
}
