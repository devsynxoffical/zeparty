import 'dart:math' as math;

/// Mirror of backend/src/games/air_hockey/physics.ts: the constants and the paddle
/// clamp the client re-applies for local prediction. Checked against
/// tests/fixtures/air_hockey_clamp.json. The puck is never simulated here; it is
/// interpolated from server ticks.
class AirHockeyPhysics {
  AirHockeyPhysics._();

  static const double tableWidth = 100;
  static const double tableHeight = 180;
  static const double goalWidth = 36;
  static const double puckRadius = 3;
  static const double paddleRadius = 6;
  static const double puckMaxSpeed = 260;
  static const double paddleMaxSpeed = 220;
  static const double moveBudgetCapMs = 100;
  static const double tickMs = 1000 / 60;

  /// Travel allowance a paddle can bank (table units).
  static double get moveBudgetCap => paddleMaxSpeed * moveBudgetCapMs / 1000;

  /// Where a seat's paddle centre may be: inside the walls and on its own half.
  static PaddleBounds bounds(int seat) => seat == 0
      ? const PaddleBounds(minX: paddleRadius, maxX: tableWidth - paddleRadius, minY: tableHeight / 2 + paddleRadius, maxY: tableHeight - paddleRadius)
      : const PaddleBounds(minX: paddleRadius, maxX: tableWidth - paddleRadius, minY: paddleRadius, maxY: tableHeight / 2 - paddleRadius);

  static TablePoint clampToHalf(int seat, double x, double y) {
    final b = bounds(seat);
    return TablePoint(x.clamp(b.minX, b.maxX).toDouble(), y.clamp(b.minY, b.maxY).toDouble());
  }

  /// Move from [from] toward [to] by at most [maxDist]; same semantics as the server.
  static TablePoint limitStep(TablePoint from, TablePoint to, double maxDist) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d <= maxDist || d == 0) return to;
    final k = maxDist / d;
    return TablePoint(from.x + dx * k, from.y + dy * k);
  }

  static TablePoint paddleHome(int seat) => TablePoint(tableWidth / 2, seat == 0 ? tableHeight - 24 : 24);
}

class PaddleBounds {
  const PaddleBounds({required this.minX, required this.maxX, required this.minY, required this.maxY});
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
}

/// Immutable point in table units.
class TablePoint {
  const TablePoint(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(TablePoint o) {
    final dx = o.x - x;
    final dy = o.y - y;
    return math.sqrt(dx * dx + dy * dy);
  }

  TablePoint lerp(TablePoint o, double t) => TablePoint(x + (o.x - x) * t, y + (o.y - y) * t);

  @override
  String toString() => 'TablePoint($x, $y)';
}
