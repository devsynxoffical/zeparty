import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'arena_component.dart';

/// A paddle (mallet): sprite or procedural neon ring, with a contact flash and
/// an expanding ring pulse on puck hits.
class PaddleComponent extends PositionComponent {
  PaddleComponent({required this.unit, required double radiusUnits, required this.color, this.sprite, required this.isLocal})
      : super(anchor: Anchor.center, size: Vector2.all(radiusUnits * unit * 2), priority: 30);

  final double unit;
  final Color color;
  final Sprite? sprite;
  final bool isLocal;

  double _flash = 0;
  double _ring = 0; // 0 = idle, grows to 1
  final Paint _p = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  void hit() {
    _flash = 1;
    _ring = 0.001;
  }

  @override
  void update(double dt) {
    if (_flash > 0) _flash = math.max(0, _flash - dt * 3.5);
    if (_ring > 0) {
      _ring += dt * 2.2;
      if (_ring >= 1) _ring = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final c = Offset(r, r);
    // Ground glow.
    _p
      ..color = color.withValues(alpha: 0.35 + _flash * 0.4)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, r * 0.5);
    canvas.drawCircle(c, r * 1.05, _p);
    _p.maskFilter = null;
    final s = sprite;
    if (s != null) {
      s.render(canvas, size: size);
    } else {
      _p.shader = ui.Gradient.radial(Offset(r * 0.85, r * 0.8), r * 1.15, [const Color(0xFF1B2140), const Color(0xFF0A0D1C)], [0.2, 1]);
      canvas.drawCircle(c, r, _p);
      _p.shader = null;
      _stroke
        ..color = color
        ..strokeWidth = r * 0.16;
      canvas.drawCircle(c, r * 0.9, _stroke);
      _stroke
        ..color = NeonPalette.white.withValues(alpha: 0.6)
        ..strokeWidth = r * 0.05;
      canvas.drawCircle(c, r * 0.72, _stroke);
      _p.shader = ui.Gradient.radial(c, r * 0.5, [color.withValues(alpha: 0.95), color.withValues(alpha: 0.2)]);
      canvas.drawCircle(c, r * 0.5, _p);
      _p.shader = null;
      _p.color = NeonPalette.white.withValues(alpha: 0.9);
      canvas.drawCircle(c, r * 0.16, _p);
    }
    if (_flash > 0) {
      _p
        ..color = Colors.white.withValues(alpha: _flash * 0.55)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(c, r * 0.95, _p);
      _p.blendMode = BlendMode.srcOver;
    }
    if (_ring > 0) {
      _stroke
        ..color = color.withValues(alpha: (1 - _ring) * 0.9)
        ..strokeWidth = r * 0.18 * (1 - _ring) + 1;
      canvas.drawCircle(c, r * (1 + _ring * 1.6), _stroke);
    }
  }
}
