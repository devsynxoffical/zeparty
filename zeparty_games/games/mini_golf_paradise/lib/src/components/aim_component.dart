import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../model/course.dart';

/// Drag-to-aim input layered over the course. Drag back from the ball: the rubber
/// band shows direction and power, a dotted guide shows the predicted path up to the
/// first bounce (computed client-side for feel only; the server decides the outcome).
class AimComponent extends PositionComponent with DragCallbacks {
  AimComponent({required this.unit, required this.ballPosition, required this.course, required this.obstacleValues, required this.onPutt, required this.seatColor});

  final double unit;
  final Vec Function() ballPosition;
  final Course Function() course;
  final List<double> Function() obstacleValues;
  final void Function(double angle, double power) onPutt;
  Color seatColor;

  /// Whether the local player may aim right now.
  bool enabled = false;

  /// Drag distance (course units) that maps to full power.
  static const double fullPowerDrag = 34;
  static const double grabRadius = 14;
  static const double minPower = 0.04;

  Vector2? _dragStart;
  Vector2? _dragCurrent;
  bool get aiming => _dragStart != null && _dragCurrent != null;

  /// Current aim (angle in radians, power 0..1) or null.
  (double angle, double power)? get aim {
    final start = _dragStart;
    final cur = _dragCurrent;
    if (start == null || cur == null) return null;
    final ball = ballPosition();
    final b = Vector2(ball.x * unit, ball.y * unit);
    final pull = b - cur; // pulling back launches forward
    final dist = pull.length / unit;
    if (dist < 0.3) return null;
    final power = (dist / fullPowerDrag).clamp(0.0, 1.0);
    return (math.atan2(pull.y, pull.x), power);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!enabled) return;
    final ball = ballPosition();
    final local = event.localPosition;
    final d = (local - Vector2(ball.x * unit, ball.y * unit)).length / unit;
    if (d > grabRadius) return;
    _dragStart = local.clone();
    _dragCurrent = local.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (_dragStart == null) return;
    _dragCurrent = event.localEndPosition.clone();
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final a = aim;
    _dragStart = null;
    _dragCurrent = null;
    if (a == null || !enabled) return;
    final (angle, power) = a;
    if (power < minPower) return;
    onPutt(angle, power);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _dragStart = null;
    _dragCurrent = null;
  }

  void cancel() {
    _dragStart = null;
    _dragCurrent = null;
  }

  @override
  void render(Canvas canvas) {
    final a = aim;
    final cur = _dragCurrent;
    if (a == null || cur == null) return;
    final (angle, power) = a;
    final ball = ballPosition();
    final b = Offset(ball.x * unit, ball.y * unit);
    final handle = Offset(cur.x, cur.y);
    final color = Color.lerp(const Color(0xFF7CF59A), const Color(0xFFFF4D4D), power)!;

    // Rubber band from ball to the finger.
    canvas.drawLine(b, handle, Paint()..color = Colors.black.withValues(alpha: 0.25)..strokeWidth = unit * 1.3..strokeCap = StrokeCap.round);
    canvas.drawLine(b, handle, Paint()..color = color.withValues(alpha: 0.9)..strokeWidth = unit * 0.7..strokeCap = StrokeCap.round);
    canvas.drawCircle(handle, unit * 1.6, Paint()..color = color.withValues(alpha: 0.35));
    canvas.drawCircle(handle, unit * 1.0, Paint()..color = color);

    // Predicted path: ray from the ball until the first wall/obstacle hit, then a short reflected stub.
    final dir = Vec(math.cos(angle), math.sin(angle));
    final c = course();
    final segs = [...c.walls, ...c.obstacleSegments(obstacleValues())];
    final range = 10 + power * 110; // approximate roll distance for the guide
    final hit = raycastSegments(ball, dir, segs, maxDistance: range);
    final end = hit?.point ?? (ball + dir * range);
    _dotted(canvas, Offset(ball.x * unit, ball.y * unit), Offset(end.x * unit, end.y * unit), color);
    if (hit != null) {
      final n = hit.normal;
      final refl = (dir - n * (2 * dir.dot(n))).normalized;
      final stubLen = math.min(18.0, (range - hit.distance) * 0.7);
      if (stubLen > 2) {
        final stub = hit.point + refl * stubLen;
        _dotted(canvas, Offset(hit.point.x * unit, hit.point.y * unit), Offset(stub.x * unit, stub.y * unit), color.withValues(alpha: 0.55));
      }
      canvas.drawCircle(Offset(hit.point.x * unit, hit.point.y * unit), unit * 0.8, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }

    // Power arc around the ball.
    final arcRect = Rect.fromCircle(center: b, radius: unit * 4.2);
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * power, false, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.7..strokeCap = StrokeCap.round..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(b, unit * 4.2, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.2..color = Colors.white.withValues(alpha: 0.3));
  }

  void _dotted(Canvas canvas, Offset from, Offset to, Color color) {
    final d = to - from;
    final len = d.distance;
    if (len < 1) return;
    final step = unit * 2.2;
    final n = (len / step).floor();
    final dirO = d / len;
    final paint = Paint()..color = color.withValues(alpha: 0.85);
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.3);
    for (var i = 1; i <= n; i++) {
      final p = from + dirO * (i * step);
      final r = unit * (0.55 - 0.25 * i / math.max(n, 1));
      canvas.drawCircle(p + Offset(0, unit * 0.3), r, shadow);
      canvas.drawCircle(p, r, paint);
    }
  }
}
