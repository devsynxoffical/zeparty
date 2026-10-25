import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'galaxy_palette.dart';

/// Activation of the winning line: the four cells pulse and an energy beam
/// grows from the first cell to the last, then keeps breathing.
class WinLineComponent extends PositionComponent {
  WinLineComponent({required this.cells, required this.seat, required this.cell}) : super(priority: 30);

  /// World positions of the winning cells, in line order.
  final List<Vector2> cells;
  final int seat;
  final double cell;

  double _t = 0;
  static const double growTime = 0.6;

  bool get grown => _t >= growTime;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    if (cells.length < 2) return;
    final color = GalaxyPalette.seat(seat);
    final light = GalaxyPalette.seatLight(seat);
    final progress = (_t / growTime).clamp(0.0, 1.0);
    final pulse = 0.5 + 0.5 * math.sin((_t - growTime) * 5);
    final a = cells.first.toOffset();
    final b = cells.last.toOffset();
    final end = Offset.lerp(a, b, Curves.easeOutCubic.transform(progress))!;

    // Beam: wide soft glow, bright core, white filament.
    canvas.drawLine(a, end, Paint()..strokeWidth = cell * 0.5..strokeCap = StrokeCap.round..color = color.withValues(alpha: 0.35 + 0.2 * pulse)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.25));
    canvas.drawLine(a, end, Paint()..strokeWidth = cell * 0.16..strokeCap = StrokeCap.round..shader = ui.Gradient.linear(a, b, [light, Colors.white, light], [0, 0.5, 1]));
    canvas.drawLine(a, end, Paint()..strokeWidth = cell * 0.05..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.9));

    // Cell pulses, lit in sequence as the beam reaches them.
    for (var i = 0; i < cells.length; i++) {
      final reach = cells.length == 1 ? 1.0 : i / (cells.length - 1);
      if (progress < reach) continue;
      final p = cells[i].toOffset();
      final local = grown ? pulse : ((progress - reach) * 3).clamp(0.0, 1.0);
      canvas.drawCircle(p, cell * (0.42 + 0.1 * local), Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.05..color = light.withValues(alpha: 0.55 + 0.45 * local));
      canvas.drawCircle(p, cell * 0.5, Paint()..color = color.withValues(alpha: 0.18 + 0.2 * local)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.2));
    }
  }
}
