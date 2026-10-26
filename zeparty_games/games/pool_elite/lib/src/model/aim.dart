import 'dart:math' as math;

import 'pool_state.dart';

/// Client-side trajectory preview. Feel only: the server owns the outcome.
class AimPreview {
  const AimPreview({
    required this.start,
    required this.end,
    required this.targetId,
    required this.ghost,
    required this.objectDir,
    required this.cueDir,
    required this.cutAngle,
    required this.legalTarget,
  });

  /// Cue ball centre.
  final math.Point<double> start;

  /// Where the cue ball centre ends its straight travel (ghost ball or cushion point).
  final math.Point<double> end;

  /// First ball hit, or null when the line reaches a cushion.
  final int? targetId;

  /// Ghost ball centre (same as [end] when a ball is hit).
  final math.Point<double>? ghost;

  /// Unit direction of the object ball after impact.
  final math.Point<double>? objectDir;

  /// Unit direction the cue ball deflects to after a ball hit or a cushion bounce.
  final math.Point<double> cueDir;

  /// Cut angle in radians (0 = full ball).
  final double cutAngle;

  /// Whether hitting [targetId] first is legal for the shooter.
  final bool legalTarget;
}

/// Casts a ray from the cue ball along [angle] and returns the first ball hit
/// (ghost-ball geometry) or the cushion exit point.
AimPreview computeAim(PoolState state, double angle, {int? seat}) {
  final table = state.table;
  final cue = state.cueBall;
  final r = table.ballRadius;
  final dx = math.cos(angle);
  final dy = math.sin(angle);
  final start = math.Point(cue.x, cue.y);

  double bestT = double.infinity;
  PoolBall? hit;
  for (final b in state.onTable) {
    if (b.isCue) continue;
    // Ray vs circle of radius 2r centred on the ball.
    final ox = b.x - cue.x;
    final oy = b.y - cue.y;
    final proj = ox * dx + oy * dy;
    if (proj <= 0) continue;
    final perp2 = ox * ox + oy * oy - proj * proj;
    final rr = 4 * r * r;
    if (perp2 >= rr) continue;
    final t = proj - math.sqrt(rr - perp2);
    if (t < bestT) {
      bestT = t;
      hit = b;
    }
  }

  // Cushion exit: the cue centre stays inside the rect inset by r.
  double cushionT = double.infinity;
  if (dx > 0) cushionT = math.min(cushionT, (table.width - r - cue.x) / dx);
  if (dx < 0) cushionT = math.min(cushionT, (r - cue.x) / dx);
  if (dy > 0) cushionT = math.min(cushionT, (table.height - r - cue.y) / dy);
  if (dy < 0) cushionT = math.min(cushionT, (r - cue.y) / dy);
  if (cushionT.isNaN || cushionT < 0) cushionT = 0;

  if (hit != null && bestT <= cushionT) {
    final g = math.Point(cue.x + dx * bestT, cue.y + dy * bestT);
    var nx = hit.x - g.x;
    var ny = hit.y - g.y;
    final n = math.sqrt(nx * nx + ny * ny);
    if (n > 0) {
      nx /= n;
      ny /= n;
    }
    final dot = dx * nx + dy * ny;
    // Cue ball keeps the tangential component.
    var cx = dx - dot * nx;
    var cy = dy - dot * ny;
    final cl = math.sqrt(cx * cx + cy * cy);
    if (cl > 1e-6) {
      cx /= cl;
      cy /= cl;
    } else {
      cx = 0;
      cy = 0;
    }
    final cut = math.acos(dot.clamp(-1.0, 1.0));
    final legal = seat == null || state.legalFirstContacts(seat).contains(hit.id);
    return AimPreview(
      start: start,
      end: g,
      targetId: hit.id,
      ghost: g,
      objectDir: math.Point(nx, ny),
      cueDir: math.Point(cx, cy),
      cutAngle: cut,
      legalTarget: legal,
    );
  }

  final e = math.Point(cue.x + dx * cushionT, cue.y + dy * cushionT);
  // Reflect off whichever wall was reached.
  var rx = dx;
  var ry = dy;
  if ((e.x - r).abs() < 1e-6 || (e.x - (table.width - r)).abs() < 1e-6) rx = -rx;
  if ((e.y - r).abs() < 1e-6 || (e.y - (table.height - r)).abs() < 1e-6) ry = -ry;
  return AimPreview(start: start, end: e, targetId: null, ghost: null, objectDir: null, cueDir: math.Point(rx, ry), cutAngle: 0, legalTarget: true);
}
