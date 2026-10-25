import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../model/physics.dart';

/// Neon palette shared by every component. Colours are relative to the viewer:
/// the bottom half is always "you" (cyan), the top half the opponent (magenta).
class NeonPalette {
  NeonPalette._();
  static const Color cyan = Color(0xFF19E6FF);
  static const Color magenta = Color(0xFFFF3DAE);
  static const Color white = Color(0xFFF2FBFF);
  static const Color floorDeep = Color(0xFF060914);
  static const Color floorMid = Color(0xFF0E1630);
  static const Color floorEdge = Color(0xFF17123A);
}

/// The playfield: glass surface, neon boundaries, centre markings and goal slots.
/// Geometry is drawn by code in view space (bottom half = viewer); the optional
/// glass texture is a decorative tile fill with a procedural fallback.
class ArenaComponent extends PositionComponent {
  ArenaComponent({required this.unit, this.glass, required this.bottomColor, required this.topColor})
      : super(position: Vector2.zero(), size: Vector2(AirHockeyPhysics.tableWidth * unit, AirHockeyPhysics.tableHeight * unit), priority: 0);

  final double unit;
  final ui.Image? glass;
  final Color bottomColor;
  final Color topColor;

  /// Light reaction after a goal: 1 right after the goal, decays to 0.
  double pulse = 0;
  Color pulseColor = NeonPalette.white;
  double _ambient = 0;
  late final bool _ambientOn = GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects;
  late final bool _blur = GraphicsSettings.instance.current != GraphicsQuality.low;

  late final Paint _fill = Paint();
  late final Paint _glassPaint = Paint();
  final Paint _line = Paint()..style = PaintingStyle.stroke;
  final Paint _glow = Paint()..style = PaintingStyle.stroke;
  final Paint _soft = Paint();

  double get goalHalf => AirHockeyPhysics.goalWidth * unit / 2;

  void flashGoal(Color color) {
    pulse = 1;
    pulseColor = color;
  }

  @override
  Future<void> onLoad() async {
    _fill.shader = ui.Gradient.radial(Offset(size.x / 2, size.y / 2), size.y * 0.75, [NeonPalette.floorMid, NeonPalette.floorDeep, NeonPalette.floorEdge], [0, 0.65, 1]);
    final g = glass;
    if (g != null) {
      final scale = (size.x / 2) / g.width; // two tiles across
      final m = Float64List.fromList([scale, 0, 0, 0, 0, scale, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
      _glassPaint
        ..shader = ui.ImageShader(g, TileMode.repeated, TileMode.repeated, m)
        ..blendMode = BlendMode.screen
        ..color = const Color(0x66FFFFFF);
    }
  }

  @override
  void update(double dt) {
    if (pulse > 0) pulse = math.max(0, pulse - dt * 1.4);
    if (_ambientOn) _ambient = (_ambient + dt) % (math.pi * 2000);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(unit * 4));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
    if (glass != null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _glassPaint);
    } else {
      _drawProceduralGlass(canvas, w, h);
    }
    // Half tints so each side reads as "owned".
    _soft
      ..shader = null
      ..blendMode = BlendMode.srcOver;
    _soft.shader = ui.Gradient.linear(Offset(0, h), Offset(0, h / 2), [bottomColor.withValues(alpha: 0.16), bottomColor.withValues(alpha: 0)]);
    canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), _soft);
    _soft.shader = ui.Gradient.linear(const Offset(0, 0), Offset(0, h / 2), [topColor.withValues(alpha: 0.16), topColor.withValues(alpha: 0)]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2), _soft);
    _soft.shader = null;

    final ambient = _ambientOn ? 0.85 + 0.15 * math.sin(_ambient * 1.3) : 1.0;

    // Centre markings.
    _line
      ..color = NeonPalette.white.withValues(alpha: 0.35)
      ..strokeWidth = unit * 0.35;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), _line);
    canvas.drawCircle(Offset(w / 2, h / 2), unit * 12, _line);
    _line.color = NeonPalette.white.withValues(alpha: 0.18);
    canvas.drawCircle(Offset(w / 2, h / 2), unit * 1.6, _line);
    // Goal creases.
    _line.color = topColor.withValues(alpha: 0.28);
    canvas.drawArc(Rect.fromCircle(center: Offset(w / 2, 0), radius: unit * 22), 0, math.pi, false, _line);
    _line.color = bottomColor.withValues(alpha: 0.28);
    canvas.drawArc(Rect.fromCircle(center: Offset(w / 2, h), radius: unit * 22), math.pi, math.pi, false, _line);

    // Boundary: glow pass then crisp pass, each half in its colour.
    _drawBoundaryHalf(canvas, w, h, top: true, color: _mix(topColor, ambient), glowWidth: unit * 2.6);
    _drawBoundaryHalf(canvas, w, h, top: false, color: _mix(bottomColor, ambient), glowWidth: unit * 2.6);

    // Goal mouths as glowing slots.
    _drawGoal(canvas, Offset(w / 2, 0), _mix(topColor, ambient));
    _drawGoal(canvas, Offset(w / 2, h), _mix(bottomColor, ambient));
    canvas.restore();
  }

  Color _mix(Color base, double ambient) {
    if (pulse <= 0) return base.withValues(alpha: (base.a * ambient).clamp(0.0, 1.0));
    return Color.lerp(base, pulseColor, pulse * 0.85)!;
  }

  void _drawBoundaryHalf(Canvas canvas, double w, double h, {required bool top, required Color color, required double glowWidth}) {
    final path = Path();
    final inset = unit * 0.6;
    final r = unit * 4;
    if (top) {
      path.moveTo(inset, h / 2);
      path.lineTo(inset, r);
      path.quadraticBezierTo(inset, inset, r, inset);
      path.lineTo(w / 2 - goalHalf, inset);
      path.moveTo(w / 2 + goalHalf, inset);
      path.lineTo(w - r, inset);
      path.quadraticBezierTo(w - inset, inset, w - inset, r);
      path.lineTo(w - inset, h / 2);
    } else {
      path.moveTo(inset, h / 2);
      path.lineTo(inset, h - r);
      path.quadraticBezierTo(inset, h - inset, r, h - inset);
      path.lineTo(w / 2 - goalHalf, h - inset);
      path.moveTo(w / 2 + goalHalf, h - inset);
      path.lineTo(w - r, h - inset);
      path.quadraticBezierTo(w - inset, h - inset, w - inset, h - r);
      path.lineTo(w - inset, h / 2);
    }
    final glowAlpha = (0.35 + pulse * 0.5).clamp(0.0, 1.0);
    _glow
      ..color = color.withValues(alpha: glowAlpha)
      ..strokeWidth = glowWidth * (1 + pulse * 0.8)
      ..maskFilter = _blur ? ui.MaskFilter.blur(ui.BlurStyle.normal, unit * 1.4) : null;
    canvas.drawPath(path, _glow);
    _line
      ..color = color
      ..strokeWidth = unit * 0.7;
    canvas.drawPath(path, _line);
    _line
      ..color = NeonPalette.white.withValues(alpha: 0.75)
      ..strokeWidth = unit * 0.22;
    canvas.drawPath(path, _line);
  }

  void _drawGoal(Canvas canvas, Offset centre, Color color) {
    final depth = unit * 3.2;
    final isTop = centre.dy == 0;
    final rect = Rect.fromLTWH(centre.dx - goalHalf, isTop ? 0 : centre.dy - depth, goalHalf * 2, depth);
    _soft
      ..color = color.withValues(alpha: 0.45 + pulse * 0.4)
      ..maskFilter = _blur ? ui.MaskFilter.blur(ui.BlurStyle.normal, unit * 1.2) : null;
    canvas.drawRect(rect.inflate(unit * 0.4), _soft);
    _soft.maskFilter = null;
    _soft.shader = ui.Gradient.linear(
      rect.topCenter,
      rect.bottomCenter,
      isTop ? [color.withValues(alpha: 0.9), color.withValues(alpha: 0.15)] : [color.withValues(alpha: 0.15), color.withValues(alpha: 0.9)],
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(unit * 0.6)), _soft);
    _soft.shader = null;
    // Goal posts.
    _soft.color = NeonPalette.white;
    canvas.drawCircle(Offset(rect.left, isTop ? unit * 0.6 : centre.dy - unit * 0.6), unit * 0.9, _soft);
    canvas.drawCircle(Offset(rect.right, isTop ? unit * 0.6 : centre.dy - unit * 0.6), unit * 0.9, _soft);
  }

  /// Fallback when the glass texture is missing: faint hex lattice with bands.
  void _drawProceduralGlass(Canvas canvas, double w, double h) {
    _line
      ..color = NeonPalette.white.withValues(alpha: 0.05)
      ..strokeWidth = unit * 0.12;
    final r = unit * 7;
    final dx = r * math.sqrt(3);
    final dy = r * 1.5;
    var row = 0;
    for (var y = -r; y < h + r; y += dy, row++) {
      final offset = row.isOdd ? dx / 2 : 0.0;
      for (var x = -dx + offset; x < w + dx; x += dx) {
        final p = Path();
        for (var i = 0; i < 6; i++) {
          final a = math.pi / 6 + i * math.pi / 3;
          final px = x + r * math.cos(a);
          final py = y + r * math.sin(a);
          if (i == 0) {
            p.moveTo(px, py);
          } else {
            p.lineTo(px, py);
          }
        }
        p.close();
        canvas.drawPath(p, _line);
      }
    }
    _soft.shader = ui.Gradient.linear(const Offset(0, 0), Offset(w, h), [Colors.white.withValues(alpha: 0.07), Colors.transparent, Colors.white.withValues(alpha: 0.05)], [0, 0.5, 1]);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _soft);
    _soft.shader = null;
  }
}
