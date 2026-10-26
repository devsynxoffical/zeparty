import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../model/course.dart';

/// A player's ball: sprite (or procedural glossy sphere), contact shadow and a
/// seat-coloured identification ring. Position is in world space.
class BallComponent extends PositionComponent {
  BallComponent({required this.seat, required this.ringColor, required this.sprite, required this.unit}) {
    priority = 30;
    anchor = Anchor.center;
    size = Vector2.all(ballRadius * 2 * unit);
  }

  final int seat;
  final Color ringColor;
  final Sprite? sprite;
  final double unit;

  /// Course-unit position this ball currently shows.
  Vec coursePosition = const Vec(0, 0);
  bool visible = true;

  /// Pulsing ring for the ball whose turn it is.
  bool highlighted = false;
  double _pulse = 0;

  void snapTo(Vec p) {
    coursePosition = p;
    position = Vector2(p.x * unit, p.y * unit);
    scale = Vector2.all(1);
    visible = true;
  }

  /// Move during a replay (no tween: the keyframes are the animation).
  void showAt(Vec p) {
    coursePosition = p;
    position.setValues(p.x * unit, p.y * unit);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
  }

  /// Shrink into the cup.
  Future<void> dropIntoCup() {
    final c = Completer<void>();
    add(ScaleEffect.to(Vector2.all(0.15), EffectController(duration: 0.28, curve: Curves.easeIn), onComplete: () {
      visible = false;
      if (!c.isCompleted) c.complete();
    }));
    return c.future;
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final r = size.x / 2;
    final center = Offset(r, r);
    if (highlighted) {
      final glow = 0.55 + 0.45 * math.sin(_pulse * 4);
      canvas.drawCircle(center, r * 2.2, Paint()..color = ringColor.withValues(alpha: 0.2 * glow));
    }
    canvas.drawCircle(center, r * 1.55, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.28..color = ringColor.withValues(alpha: highlighted ? 0.95 : 0.7));
    canvas.drawOval(Rect.fromCenter(center: center + Offset(r * 0.25, r * 0.55), width: r * 2.1, height: r * 1.3), Paint()..color = Colors.black.withValues(alpha: 0.38)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35));
    final s = sprite;
    if (s != null) {
      s.render(canvas, size: size);
    } else {
      canvas.drawCircle(center, r, Paint()..shader = ui.Gradient.radial(center + Offset(-r * 0.35, -r * 0.4), r * 1.3, [Colors.white, const Color(0xFFE2E2DC), const Color(0xFF9A9A94)], [0, 0.55, 1]));
      canvas.drawCircle(center + Offset(-r * 0.35, -r * 0.4), r * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.9));
    }
  }
}
