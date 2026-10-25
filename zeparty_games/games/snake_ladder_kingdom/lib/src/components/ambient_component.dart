import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'board_geometry.dart';

/// Ambient layer behind and around the board: small floating islands drifting
/// in the margins and waterfalls pouring off the main landmass. Motion only runs
/// at high quality without "reduce effects"; otherwise it renders a still frame.
class AmbientComponent extends PositionComponent {
  AmbientComponent({required this.geo}) : super(size: Vector2.all(geo.worldSize), priority: -2);

  final BoardGeometry geo;
  double _time = 0;
  late final List<_Island> _islands;
  late final List<_Waterfall> _falls;
  late final ui.Picture _stillIslands;

  bool get _animated => GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects;

  @override
  Future<void> onLoad() async {
    final rng = math.Random(11);
    final cell = geo.cell;
    final w = geo.worldSize;
    final m = geo.margin;
    _islands = [
      _Island(Vector2(m * 0.45, w * 0.22), cell * 0.7, rng.nextDouble() * 6),
      _Island(Vector2(w - m * 0.45, w * 0.55), cell * 0.55, rng.nextDouble() * 6),
      _Island(Vector2(w * 0.35, m * 0.45), cell * 0.5, rng.nextDouble() * 6),
      _Island(Vector2(w * 0.78, m * 0.4), cell * 0.62, rng.nextDouble() * 6),
      _Island(Vector2(w - m * 0.5, w - m * 0.5), cell * 0.5, rng.nextDouble() * 6),
    ];
    final right = m + geo.gridSize;
    _falls = [
      _Waterfall(Vector2(right + cell * 0.02, m + geo.gridSize * 0.28), cell * 0.22, cell * 1.6, rng.nextDouble()),
      _Waterfall(Vector2(right + cell * 0.02, m + geo.gridSize * 0.72), cell * 0.18, cell * 1.3, rng.nextDouble()),
      _Waterfall(Vector2(m - cell * 0.2, m + geo.gridSize * 0.5), cell * 0.2, cell * 1.5, rng.nextDouble()),
    ];
    _stillIslands = _recordIslands(0);
  }

  @override
  void update(double dt) {
    if (_animated) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (_animated) {
      canvas.drawPicture(_recordIslands(_time));
    } else {
      canvas.drawPicture(_stillIslands);
    }
    for (final f in _falls) {
      f.render(canvas, _time, geo.cell);
    }
  }

  ui.Picture _recordIslands(double t) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final isl in _islands) {
      isl.render(c, t);
    }
    return rec.endRecording();
  }
}

class _Island {
  _Island(this.base, this.radius, this.phase);
  final Vector2 base;
  final double radius;
  final double phase;

  void render(Canvas c, double t) {
    final dy = math.sin(t * 0.5 + phase) * radius * 0.18;
    final dx = math.cos(t * 0.3 + phase) * radius * 0.08;
    final center = Offset(base.x + dx, base.y + dy);
    final r = radius;
    // Shadow haze under the island.
    c.drawOval(Rect.fromCenter(center: center.translate(0, r * 1.1), width: r * 1.6, height: r * 0.5), Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    // Rock cone below.
    final rock = Path()
      ..moveTo(center.dx - r * 0.85, center.dy)
      ..lineTo(center.dx + r * 0.85, center.dy)
      ..lineTo(center.dx + r * 0.25, center.dy + r * 0.9)
      ..lineTo(center.dx - r * 0.15, center.dy + r * 0.75)
      ..close();
    c.drawPath(rock, Paint()..shader = ui.Gradient.linear(center, center.translate(0, r), [const Color(0xFF6B5543), const Color(0xFF3A2C22)]));
    // Grass top.
    c.drawOval(Rect.fromCenter(center: center, width: r * 1.8, height: r * 0.75), Paint()..shader = ui.Gradient.linear(center.translate(0, -r * 0.4), center.translate(0, r * 0.4), [const Color(0xFF7FC36A), const Color(0xFF3F7A3A)]));
    // A crystal or a tiny tree.
    final crystal = Path()
      ..moveTo(center.dx - r * 0.12, center.dy - r * 0.05)
      ..lineTo(center.dx, center.dy - r * 0.7)
      ..lineTo(center.dx + r * 0.12, center.dy - r * 0.05)
      ..close();
    c.drawPath(crystal, Paint()..color = const Color(0xFF9FE7FF).withValues(alpha: 0.9));
    c.drawPath(crystal, Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.25 * math.sin(t * 2 + phase)));
    // Sparkle motes around the crystal.
    for (var i = 0; i < 3; i++) {
      final a = t * 0.8 + phase + i * 2.1;
      c.drawCircle(center.translate(math.cos(a) * r * 0.5, -r * 0.4 + math.sin(a * 1.3) * r * 0.3), r * 0.04, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }
}

class _Waterfall {
  _Waterfall(this.top, this.width, this.height, this.phase);
  final Vector2 top;
  final double width;
  final double height;
  final double phase;

  void render(Canvas c, double t, double cell) {
    final rect = Rect.fromLTWH(top.x - width / 2, top.y, width, height);
    // Water body fading out at the bottom.
    c.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(width / 2)),
      Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [const Color(0xFFBFEFFF).withValues(alpha: 0.85), const Color(0xFF6FC3E8).withValues(alpha: 0.6), const Color(0xFF6FC3E8).withValues(alpha: 0.0)], [0, 0.55, 1]),
    );
    // Falling streaks.
    final streak = Paint()..color = Colors.white.withValues(alpha: 0.45)..strokeWidth = width * 0.12..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final speed = 1.4 + i * 0.3;
      final off = ((t * speed + phase + i * 0.37) % 1.0) * height;
      final x = rect.left + width * (0.2 + i * 0.2);
      final y0 = rect.top + off;
      final y1 = math.min(rect.bottom, y0 + height * 0.18);
      final alpha = (1 - off / height).clamp(0.0, 1.0);
      c.drawLine(Offset(x, y0), Offset(x, y1), streak..color = Colors.white.withValues(alpha: 0.5 * alpha));
    }
    // Mist at the bottom.
    c.drawOval(Rect.fromCenter(center: Offset(rect.center.dx, rect.bottom - height * 0.1), width: width * 2.4, height: width * 0.9), Paint()..color = Colors.white.withValues(alpha: 0.18 + 0.05 * math.sin(t * 3 + phase))..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.4));
  }
}
