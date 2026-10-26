import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Traditional ball colours, used for the procedural fallback and HUD chips.
Color ballColor(int id) => switch (id % 8) {
      1 => const Color(0xFFF2C21D),
      2 => const Color(0xFF1E55C8),
      3 => const Color(0xFFD9262B),
      4 => const Color(0xFF5B2D8E),
      5 => const Color(0xFFF07E1A),
      6 => const Color(0xFF1E8C5A),
      7 => const Color(0xFF7A1F1F),
      _ => id == 8 ? const Color(0xFF111111) : const Color(0xFFF6F1E6),
    };

/// A single ball: sprite (or procedural) with a soft contact shadow and a fake
/// rolling rotation driven by distance travelled. Positions are world pixels.
class BallComponent extends PositionComponent {
  BallComponent({required this.id, required this.radius, required this.image}) : super(size: Vector2.all(radius * 2), anchor: Anchor.center, priority: 20);

  final int id;
  final double radius;
  final ui.Image? image;

  double _roll = 0;
  double _rollAxis = 0;
  bool hidden = false;

  /// Pulsing ring when the cue ball may be placed by hand.
  bool highlight = false;

  /// Drop animation progress (0 = none, 1 = fully gone), used when pocketed during a replay.
  double drop = 0;
  double _pulse = 0;
  ui.Picture? _procedural;

  bool get isCue => id == 0;

  @override
  Future<void> onLoad() async {
    if (image == null) _procedural = _recordProcedural();
  }

  /// Moves to a new centre, accumulating the rolling angle from the distance travelled.
  void moveTo(Vector2 target) {
    final dx = target.x - position.x;
    final dy = target.y - position.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 0.001) {
      _roll += d / radius;
      _rollAxis = math.atan2(dy, dx);
    }
    position.setFrom(target);
  }

  @override
  void update(double dt) {
    _pulse = (_pulse + dt * 2.2) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    if (hidden) return;
    final r = radius;
    final centre = Offset(r, r);
    final k = 1 - drop * 0.75;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(k, k);
    canvas.translate(-centre.dx, -centre.dy);

    if (highlight) {
      final a = 0.45 + 0.35 * math.sin(_pulse);
      canvas.drawCircle(centre, r * (1.45 + 0.1 * math.sin(_pulse)), Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.14..color = const Color(0xFFE8C96A).withValues(alpha: a));
    }
    // Contact shadow: offset, soft, slightly larger than the ball.
    canvas.drawOval(
      Rect.fromCenter(center: centre.translate(r * 0.22, r * 0.34), width: r * 2.1, height: r * 1.7),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42 * (1 - drop))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
    // Rolling: rotate the sprite about the travel axis a little (fake but convincing),
    // combined with a spin about the view axis. Pure 2D, no 3D maths needed.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    final wobble = math.sin(_roll) * 0.08;
    canvas.rotate(_rollAxis);
    canvas.scale(1 - wobble.abs(), 1);
    canvas.rotate(-_rollAxis + _roll * 0.35);
    canvas.translate(-centre.dx, -centre.dy);
    final img = image;
    if (img != null) {
      final paint = Paint()..filterQuality = FilterQuality.medium;
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(0, 0, r * 2, r * 2), paint);
    } else if (_procedural != null) {
      canvas.drawPicture(_procedural!);
    }
    canvas.restore();
    // Fixed specular highlight (does not roll with the ball).
    canvas.drawCircle(centre.translate(-r * 0.32, -r * 0.36), r * 0.26, Paint()..shader = ui.Gradient.radial(centre.translate(-r * 0.32, -r * 0.36), r * 0.3, [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0)]));
    // Rim darkening to sit the ball into the cloth.
    canvas.drawCircle(centre, r, Paint()..shader = ui.Gradient.radial(centre.translate(-r * 0.2, -r * 0.25), r * 1.1, [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.45)], const [0, 0.72, 1]));
    canvas.restore();
  }

  ui.Picture _recordProcedural() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final r = radius;
    final centre = Offset(r, r);
    final base = ballColor(id);
    final isStripe = id >= 9;
    final isCueBall = id == 0;
    c.drawCircle(centre, r, Paint()..color = isStripe || isCueBall ? const Color(0xFFF6F1E6) : base);
    if (isStripe) {
      c.save();
      c.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: r)));
      c.drawRect(Rect.fromLTWH(0, r * 0.45, r * 2, r * 1.1), Paint()..color = base);
      c.restore();
    }
    if (!isCueBall) {
      c.drawCircle(centre, r * 0.46, Paint()..color = const Color(0xFFF6F1E6));
      final tp = TextPainter(
        text: TextSpan(text: '$id', style: TextStyle(color: const Color(0xFF111111), fontSize: r * (id >= 10 ? 0.58 : 0.7), fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
    } else {
      c.drawCircle(centre.translate(r * 0.35, r * 0.2), r * 0.12, Paint()..color = const Color(0xFFD9262B));
    }
    return rec.endRecording();
  }
}
