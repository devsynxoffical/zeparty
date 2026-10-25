import 'dart:math' as math;

import 'package:flame/components.dart';

import '../model/layouts.dart';

/// World-space geometry of the kingdom board. Squares are laid out on the
/// boustrophedon grid from model/layouts.dart; this class only adds pixels.
///
/// The world is a square of [worldSize] with a margin around the grid used by
/// the start dock, floating islands and waterfalls.
class BoardGeometry {
  BoardGeometry({required this.layout, this.cell = 100})
      : cols = columnsFor(layout.boardSize),
        margin = cell * 1.15;

  final BoardLayout layout;
  final double cell;
  final int cols;
  final double margin;

  int get boardSize => layout.boardSize;
  int get rows => cols;
  double get gridSize => cols * cell;
  double get worldSize => gridSize + margin * 2;
  Vector2 get worldCenter => Vector2.all(worldSize / 2);

  /// Centre of a square in world coordinates (square 1 bottom-left).
  Vector2 squareCenter(int square) {
    final c = cellForSquare(square.clamp(1, boardSize), boardSize);
    return Vector2(margin + c.col * cell + cell / 2, margin + (rows - 1 - c.row) * cell + cell / 2);
  }

  /// Top-left corner of a square tile.
  Vector2 squareTopLeft(int square) => squareCenter(square) - Vector2.all(cell / 2);

  /// Where a character waits before entering the board (square 0). Seats fan
  /// out along the bottom margin, left of square 1.
  Vector2 dockPosition(int seatIndex) {
    final y = margin + gridSize + margin * 0.5;
    final x = margin + cell * 0.55 + seatIndex * cell * 0.85;
    return Vector2(x, y);
  }

  /// Position for a square, 0 meaning the dock.
  Vector2 positionFor(int square, int seatIndex) => square <= 0 ? dockPosition(seatIndex) : squareCenter(square);

  /// Cubic Bezier for a snake, head at t = 0 and tail at t = 1. Control points
  /// are pushed sideways so every dragon curves differently but deterministically.
  CubicBezier snakeCurve(Link snake) {
    final p0 = squareCenter(snake.from);
    final p3 = squareCenter(snake.to);
    final d = p3 - p0;
    final len = d.length;
    final n = Vector2(-d.y, d.x).normalized();
    final idx = layout.snakes.indexOf(snake);
    final sign = idx.isEven ? 1.0 : -1.0;
    final k = (len * 0.22 + cell * 0.3) * sign;
    final p1 = p0 + d * 0.3 + n * k;
    final p2 = p0 + d * 0.7 - n * k * 0.8;
    return CubicBezier(p0, p1, p2, p3);
  }

  /// Straight line of a ladder from bottom to top.
  (Vector2, Vector2) ladderLine(Link ladder) => (squareCenter(ladder.from), squareCenter(ladder.to));

  /// Clamp a camera focus point so a zoomed viewport stays inside the world.
  Vector2 clampFocus(Vector2 target, double zoom) {
    final half = worldSize / (2 * zoom);
    final lo = half;
    final hi = worldSize - half;
    if (hi <= lo) return worldCenter;
    return Vector2(target.x.clamp(lo, hi), target.y.clamp(lo, hi));
  }
}

/// Cubic Bezier with arc-length aware sampling helpers.
class CubicBezier {
  CubicBezier(this.p0, this.p1, this.p2, this.p3);
  final Vector2 p0;
  final Vector2 p1;
  final Vector2 p2;
  final Vector2 p3;

  Vector2 pointAt(double t) {
    final u = 1 - t;
    return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
  }

  Vector2 tangentAt(double t) {
    final u = 1 - t;
    final v = (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t);
    return v.length < 1e-6 ? (p3 - p0).normalized() : v.normalized();
  }

  double angleAt(double t) {
    final v = tangentAt(t);
    return math.atan2(v.y, v.x);
  }

  /// Approximate length by sampling.
  double length([int samples = 32]) {
    var len = 0.0;
    var prev = p0;
    for (var i = 1; i <= samples; i++) {
      final p = pointAt(i / samples);
      len += (p - prev).length;
      prev = p;
    }
    return len;
  }

  /// Evenly spaced points along the curve (approximately by arc length).
  List<Vector2> sample(int count) => [for (var i = 0; i < count; i++) pointAt(i / (count - 1))];
}
