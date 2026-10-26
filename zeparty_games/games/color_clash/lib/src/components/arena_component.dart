import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/card.dart';
import 'layout.dart';

/// The holographic arena: a slowly rotating iridescent ring, the floating card
/// table (ellipse with glass rim) and direction arrows that follow the play
/// direction. [spinBurst] gives the ring a kick when a Flip is played.
class ArenaComponent extends PositionComponent {
  ArenaComponent() : super(size: Vector2(ArenaLayout.worldW, ArenaLayout.worldH), priority: 0);

  double _ringAngle = 0;
  static const double _ringSpeed = 0.18;
  double _burst = 0;
  int direction = 1;
  CcColor currentColor = CcColor.ruby;
  Color _washColor = Colors.transparent;
  double _wash = 0;
  double _t = 0;

  /// Flip played: the ring spins hard in the new direction and settles.
  void spinBurst(int newDirection) {
    direction = newDirection;
    _burst = 1;
  }

  /// Prism played: wash the table in the chosen colour.
  void colorWash(Color color) {
    _washColor = color;
    _wash = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final ambient = GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects;
    _t += dt;
    final base = ambient ? _ringSpeed : _ringSpeed * 0.35;
    _ringAngle += dt * direction * (base + _burst * 6);
    _burst = math.max(0, _burst - dt * 1.6);
    _wash = math.max(0, _wash - dt * 0.9);
  }

  @override
  void render(Canvas canvas) {
    final c = ArenaLayout.tableCenter.toOffset();
    final accent = currentColor.color;

    // Floor glow under the table.
    final floor = Rect.fromCenter(center: c + const Offset(0, 90), width: ArenaLayout.tableRx * 2.7, height: ArenaLayout.tableRy * 2.6);
    canvas.drawOval(floor, Paint()..shader = RadialGradient(colors: [accent.withValues(alpha: 0.22), Colors.transparent]).createShader(floor));

    // Iridescent ring.
    final ringRect = Rect.fromCenter(center: c, width: ArenaLayout.tableRx * 2 + 190, height: ArenaLayout.tableRy * 2 + 190);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(_ringAngle);
    canvas.translate(-c.dx, -c.dy);
    final sweep = SweepGradient(colors: [CcColor.ruby.color, CcColor.gold.color, CcColor.emerald.color, CcColor.sapphire.color, const Color(0xFFB08CFF), CcColor.ruby.color]).createShader(ringRect);
    canvas.drawOval(ringRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 10 + _burst * 10..shader = sweep..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawOval(ringRect, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.white.withValues(alpha: 0.55));
    // Dashes orbiting on the ring.
    for (var i = 0; i < 24; i++) {
      final a = i / 24 * math.pi * 2;
      final p = Offset(c.dx + math.cos(a) * ringRect.width / 2, c.dy + math.sin(a) * ringRect.height / 2);
      canvas.drawCircle(p, i % 6 == 0 ? 6 : 3, Paint()..color = Colors.white.withValues(alpha: i % 6 == 0 ? 0.9 : 0.45));
    }
    canvas.restore();

    // Table: glass ellipse with a rim and a soft inner vignette.
    final table = Rect.fromCenter(center: c, width: ArenaLayout.tableRx * 2, height: ArenaLayout.tableRy * 2);
    canvas.drawOval(table.shift(const Offset(0, 28)), Paint()..color = Colors.black.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24));
    canvas.drawOval(table, Paint()..shader = const RadialGradient(center: Alignment(0, -0.4), radius: 1.1, colors: [Color(0xFF2A2140), Color(0xFF14101F)]).createShader(table));
    canvas.drawOval(table.deflate(8), Paint()..shader = RadialGradient(radius: 0.9, colors: [accent.withValues(alpha: 0.18 + _wash * 0.35), Colors.transparent]).createShader(table));
    if (_wash > 0) canvas.drawOval(table, Paint()..color = _washColor.withValues(alpha: 0.45 * _wash));
    canvas.drawOval(table, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..shader = LinearGradient(colors: [ZpColors.goldLight, accent, ZpColors.gold]).createShader(table));
    canvas.drawOval(table.deflate(14), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withValues(alpha: 0.18));
    // Table sheen band.
    canvas.save();
    canvas.clipPath(Path()..addOval(table));
    final band = Rect.fromCenter(center: c + Offset(math.sin(_t * 0.4) * 120, -40), width: 200, height: ArenaLayout.tableRy * 2);
    canvas.drawRect(band, Paint()..blendMode = BlendMode.plus..shader = LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: 0.06), Colors.transparent]).createShader(band));
    canvas.restore();

    // Direction arrows riding just inside the rim.
    final arrowPaint = Paint()..color = accent.withValues(alpha: 0.85)..style = PaintingStyle.fill;
    for (var i = 0; i < 6; i++) {
      final a = _ringAngle * 0.5 + i / 6 * math.pi * 2;
      final p = Offset(c.dx + math.cos(a) * (ArenaLayout.tableRx - 30), c.dy + math.sin(a) * (ArenaLayout.tableRy - 24));
      final tangent = math.atan2(math.cos(a) * (ArenaLayout.tableRy - 24), -math.sin(a) * (ArenaLayout.tableRx - 30)) + (direction > 0 ? 0 : math.pi);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(tangent);
      canvas.drawPath(Path()..moveTo(12, 0)..lineTo(-8, -8)..lineTo(-4, 0)..lineTo(-8, 8)..close(), arrowPaint);
      canvas.restore();
    }
  }
}
