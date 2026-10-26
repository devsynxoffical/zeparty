import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/geometry.dart' as g;

/// Aiming overlay: a dotted guide in the shot direction with one reflection
/// off the first cushion, and a power arc around the striker. Everything here
/// is feel only; the server simulates the real shot.
class AimComponent extends PositionComponent {
  AimComponent({required this.unit, required this.toWorld}) : super(priority: 40);

  final double unit;
  final Offset Function(g.BPoint) toWorld;

  /// Striker centre in frame units.
  g.BPoint? origin;
  /// Unit direction of the shot in frame units.
  g.BPoint? direction;
  double power = 0;
  /// Drag handle position in frame units (where the finger is).
  g.BPoint? handle;
  bool visible = false;
  double _phase = 0;

  @override
  void update(double dt) {
    _phase = (_phase + dt * 1.6) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    final o = origin;
    final d = direction;
    if (!visible || o == null || d == null || d.length == 0) return;
    final ow = toWorld(o);
    final strength = power.clamp(0.0, 1.0);

    // Guide segments (direct path and reflection preview).
    final segs = g.aimGuide(o, d, maxLength: 40 + 100 * strength);
    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final a = toWorld(s.from);
      final b = toWorld(s.to);
      final alpha = i == 0 ? 0.9 : 0.45;
      _dotted(canvas, a, b, Paint()..color = ZpColors.goldLight.withValues(alpha: alpha), unit * 0.5, unit * 2.2, offset: i == 0 ? _phase * unit * 2.2 : 0);
    }
    if (segs.isNotEmpty) {
      final hit = toWorld(segs.first.to);
      canvas.drawCircle(hit, unit * g.strikerRadius, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.25..color = ZpColors.goldLight.withValues(alpha: 0.5));
    }

    // Power arc around the striker, growing with pull strength; colour shifts to ruby at full power.
    final r = unit * (g.strikerRadius + 2.2);
    final color = Color.lerp(ZpColors.goldLight, ZpColors.ruby, math.pow(strength, 2).toDouble())!;
    canvas.drawCircle(ow, r, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.35..color = Colors.white.withValues(alpha: 0.12));
    final start = math.atan2(d.y, d.x) + math.pi; // arc opens on the pull side
    final sweep = math.pi * 1.6 * strength;
    canvas.drawArc(Rect.fromCircle(center: ow, radius: r), start - sweep / 2, sweep, false, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.6..strokeCap = StrokeCap.round..color = color.withValues(alpha: 0.9));
    canvas.drawArc(Rect.fromCircle(center: ow, radius: r), start - sweep / 2, sweep, false, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 1.4..color = color.withValues(alpha: 0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.6));

    // Pull line from the striker back to the finger, like an elastic.
    final h = handle;
    if (h != null) {
      final hw = toWorld(h);
      canvas.drawLine(ow, hw, Paint()..color = Colors.white.withValues(alpha: 0.18)..strokeWidth = unit * 0.3);
      canvas.drawCircle(hw, unit * 1.1, Paint()..color = color.withValues(alpha: 0.7));
    }
  }

  void _dotted(Canvas canvas, Offset a, Offset b, Paint paint, double dotRadius, double gap, {double offset = 0}) {
    final len = (b - a).distance;
    if (len <= 0) return;
    final dir = (b - a) / len;
    for (var t = offset % gap; t <= len; t += gap) {
      final fade = 1 - (t / len) * 0.5;
      canvas.drawCircle(a + dir * t, dotRadius * fade, paint);
    }
  }
}
