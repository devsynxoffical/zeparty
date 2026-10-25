import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Vertical release meter. After the aim is locked a cursor sweeps up and down;
/// the player taps to stop it. Release quality is 1 at the centre band and
/// falls off linearly to 0 at either end.
class SkillMeterComponent extends PositionComponent {
  SkillMeterComponent({required Vector2 position, required Vector2 size}) : super(position: position, size: size, anchor: Anchor.topLeft, priority: 60);

  /// Full up-and-down sweep period in seconds.
  static const double period = 0.9;

  /// Half-width of the perfect band, in cursor units (0..1).
  static const double perfectBand = 0.06;

  bool running = false;
  bool visible = false;
  double _phase = 0;
  double value = 0.5;
  double _flash = 0;
  double? stoppedRelease;

  void start() {
    running = true;
    visible = true;
    _phase = 0;
    value = 0;
    stoppedRelease = null;
    _flash = 0;
  }

  /// Stops the sweep and returns the release quality (0..1).
  double stop() {
    running = false;
    final r = releaseFor(value);
    stoppedRelease = r;
    _flash = 0.7;
    return r;
  }

  void hide() {
    running = false;
    visible = false;
    stoppedRelease = null;
  }

  static double releaseFor(double cursor) {
    final d = (cursor - 0.5).abs() * 2; // 0 at centre, 1 at the ends
    final adj = ((d - perfectBand) / (1 - perfectBand)).clamp(0.0, 1.0);
    return (1 - adj).clamp(0.0, 1.0);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (running) {
      _phase += dt / period;
      // Triangle wave 0 -> 1 -> 0.
      final t = _phase % 1;
      value = t < 0.5 ? t * 2 : 2 - t * 2;
    } else if (_flash > 0) {
      _flash = math.max(0, _flash - dt);
      if (_flash == 0 && stoppedRelease != null) visible = false;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final rect = size.toRect();
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(size.x / 2));
    canvas.drawRRect(rr.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawRRect(rr, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFB83A3A), Color(0xFFE2A93A), Color(0xFF3DBE7A), Color(0xFFE2A93A), Color(0xFFB83A3A)], stops: [0, 0.3, 0.5, 0.7, 1]).createShader(rect));
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = ZpColors.goldDeep);
    // Perfect band.
    final bandH = size.y * perfectBand * 2;
    final band = Rect.fromCenter(center: Offset(size.x / 2, size.y / 2), width: size.x, height: bandH);
    canvas.drawRect(band, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawLine(Offset(-6, size.y / 2), Offset(size.x + 6, size.y / 2), Paint()..color = ZpColors.goldLight..strokeWidth = 1.5);
    // Cursor.
    final y = size.y * (1 - value);
    final flash = running ? 0.0 : _flash / 0.7;
    final cursorColor = running ? Colors.white : Color.lerp(ZpColors.danger, ZpColors.success, stoppedRelease ?? 0)!;
    canvas.drawRect(Rect.fromCenter(center: Offset(size.x / 2, y), width: size.x + 12, height: 5), Paint()..color = cursorColor.withValues(alpha: 0.9)..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + flash * 6));
    canvas.drawRect(Rect.fromCenter(center: Offset(size.x / 2, y), width: size.x + 12, height: 3), Paint()..color = Colors.white);
    final tri = Path()
      ..moveTo(-10, y - 7)
      ..lineTo(-2, y)
      ..lineTo(-10, y + 7)
      ..close();
    canvas.drawPath(tri, Paint()..color = ZpColors.goldLight);
    if (!running && stoppedRelease != null) {
      final tp = TextPainter(text: TextSpan(text: '${(stoppedRelease! * 100).round()}%', style: TextStyle(color: cursorColor, fontSize: 18, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, -tp.height - 6));
    }
  }
}
