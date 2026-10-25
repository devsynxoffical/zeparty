import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'arena_component.dart';

/// The puck: sprite (or procedural neon disc) plus a fading additive light trail
/// built from the last N rendered positions.
class PuckComponent extends PositionComponent {
  PuckComponent({required this.unit, required double radiusUnits, this.sprite, Color? trailColor})
      : trailColor = trailColor ?? NeonPalette.white,
        super(anchor: Anchor.center, size: Vector2.all(radiusUnits * unit * 2), priority: 20);

  final double unit;
  final Sprite? sprite;
  Color trailColor;

  static const int trailLength = 16;
  final List<Vector2> _trail = [];
  double _spin = 0;
  double _hitFlash = 0;
  /// True while the server has the puck frozen for a faceoff.
  bool frozen = false;

  final Paint _glow = Paint();
  final Paint _body = Paint();

  late final bool _effects = !GraphicsSettings.instance.reduceEffects;

  void flash() => _hitFlash = 1;

  void clearTrail() => _trail.clear();

  @override
  void update(double dt) {
    if (_hitFlash > 0) _hitFlash = math.max(0, _hitFlash - dt * 4);
    _spin += dt * 2.5;
    if (_effects && !frozen) {
      if (_trail.isEmpty || _trail.last.distanceTo(position) > unit * 0.6) {
        _trail.add(position.clone());
        if (_trail.length > trailLength) _trail.removeAt(0);
      }
    } else if (_trail.isNotEmpty) {
      _trail.removeAt(0);
    }
  }

  /// Trail is drawn in world coordinates by [PuckTrailComponent]; exposed here.
  List<Vector2> get trail => _trail;
  double get hitFlash => _hitFlash;

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final c = Offset(r, r);
    // Outer glow (brighter right after a hit).
    _glow
      ..color = trailColor.withValues(alpha: 0.35 + _hitFlash * 0.5)
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, r * (0.6 + _hitFlash * 0.6));
    canvas.drawCircle(c, r * (1.05 + _hitFlash * 0.4), _glow);
    final s = sprite;
    if (s != null) {
      canvas.save();
      canvas.translate(r, r);
      canvas.rotate(_spin);
      s.render(canvas, position: Vector2(-r, -r), size: size);
      canvas.restore();
    } else {
      _body.shader = ui.Gradient.radial(Offset(r * 0.8, r * 0.75), r * 1.1, [NeonPalette.white, const Color(0xFFBFD8E6), const Color(0xFF3A4A66)], [0, 0.45, 1]);
      canvas.drawCircle(c, r, _body);
      _body.shader = null;
      _body.color = trailColor.withValues(alpha: 0.9);
      canvas.drawCircle(c, r * 0.35, _body);
      _body.color = NeonPalette.white.withValues(alpha: 0.5);
      canvas.drawCircle(c, r * 0.14, _body);
    }
    if (_hitFlash > 0) {
      _body.color = Colors.white.withValues(alpha: _hitFlash * 0.7);
      canvas.drawCircle(c, r * 0.9, _body);
    }
  }
}

/// Draws the puck's light trail in world space beneath the puck.
class PuckTrailComponent extends Component {
  PuckTrailComponent({required this.puck, required this.unit}) : super(priority: 15);
  final PuckComponent puck;
  final double unit;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..blendMode = BlendMode.plus;

  @override
  void render(Canvas canvas) {
    final pts = puck.trail;
    if (pts.length < 2) return;
    final n = pts.length;
    for (var i = 1; i < n; i++) {
      final f = i / n;
      _paint
        ..color = puck.trailColor.withValues(alpha: 0.05 + f * 0.35)
        ..strokeWidth = unit * (0.6 + f * 3.4);
      canvas.drawLine(Offset(pts[i - 1].x, pts[i - 1].y), Offset(pts[i].x, pts[i].y), _paint);
    }
    // Connect the newest point to the puck itself.
    final last = pts.last;
    _paint
      ..color = puck.trailColor.withValues(alpha: 0.4)
      ..strokeWidth = unit * 4;
    canvas.drawLine(Offset(last.x, last.y), Offset(puck.position.x, puck.position.y), _paint);
  }
}
