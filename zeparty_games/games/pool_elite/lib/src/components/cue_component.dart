import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The cue stick. Positioned at the cue ball centre and rotated to the aim
/// angle; drawn behind the ball along -x in local space. [pullback] follows the
/// loaded power, and [strike] plays a pull-back-then-forward animation on shot.
class CueComponent extends PositionComponent {
  CueComponent({required this.image, required this.ballRadius, required this.skin}) : super(anchor: Anchor.topLeft, priority: 30);

  final ui.Image? image;
  final double ballRadius;
  final String skin;

  bool visible = false;

  /// Loaded power 0..1, moves the cue back before the strike.
  double power = 0;

  double _strikeT = -1;
  double _strikeOffset = 0;
  void Function()? onStrikeImpact;
  bool _impactFired = false;

  double get length => ballRadius * 2 * 10.5;
  double get gap => ballRadius * 0.55;

  /// Starts the strike animation: 160 ms pull back, 70 ms forward with overshoot.
  void strike(double power) {
    this.power = power;
    _strikeT = 0;
    _impactFired = false;
  }

  bool get striking => _strikeT >= 0;

  @override
  void update(double dt) {
    if (_strikeT < 0) return;
    _strikeT += dt;
    const back = 0.16;
    const fwd = 0.07;
    if (_strikeT < back) {
      final k = Curves.easeOut.transform(_strikeT / back);
      _strikeOffset = power * ballRadius * 7 * k;
    } else if (_strikeT < back + fwd) {
      final k = Curves.easeIn.transform((_strikeT - back) / fwd);
      _strikeOffset = power * ballRadius * 7 * (1 - k) - k * ballRadius * 0.5;
    } else {
      if (!_impactFired) {
        _impactFired = true;
        onStrikeImpact?.call();
      }
      _strikeOffset = 0;
      if (_strikeT > back + fwd + 0.08) {
        _strikeT = -1;
        visible = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final r = ballRadius;
    final offset = r + gap + (striking ? _strikeOffset : power * r * 7);
    final tipX = -offset;
    final buttX = tipX - length;
    final thick = r * 0.78;
    final rect = Rect.fromLTRB(buttX, -thick / 2, tipX, thick / 2);

    // Shadow under the stick.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(Offset(r * 0.25, r * 0.6)), Radius.circular(thick)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );

    final img = image;
    if (img != null) {
      // Sprite is horizontal with the tip at the left; mirror so the tip points at the ball.
      canvas.save();
      canvas.translate(tipX, 0);
      canvas.scale(-1, 1);
      final ih = img.height.toDouble();
      final iw = img.width.toDouble();
      final drawH = thick * 2.2;
      final drawW = length;
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), Rect.fromLTWH(0, -drawH / 2, drawW, drawH), Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      return;
    }
    // Procedural cue: tapered shaft, dark butt, ferrule and leather tip.
    final shaft = Path()
      ..moveTo(tipX, -thick * 0.28)
      ..lineTo(buttX, -thick * 0.5)
      ..lineTo(buttX, thick * 0.5)
      ..lineTo(tipX, thick * 0.28)
      ..close();
    final wood = skin == 'ebony'
        ? ui.Gradient.linear(Offset(buttX, 0), Offset(tipX, 0), const [Color(0xFF0E0B0A), Color(0xFF2A2320), Color(0xFFC9A227), Color(0xFFE6D3A3)], const [0, 0.45, 0.52, 1])
        : ui.Gradient.linear(Offset(buttX, 0), Offset(tipX, 0), const [Color(0xFF4A2412), Color(0xFF7A4A22), Color(0xFFD9B98A), Color(0xFFEAD7B4)], const [0, 0.4, 0.55, 1]);
    canvas.drawPath(shaft, Paint()..shader = wood);
    // Lacquer highlight along the top edge.
    canvas.drawPath(shaft, Paint()..shader = ui.Gradient.linear(Offset(0, -thick / 2), Offset(0, thick / 2), [Colors.white.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.35)]));
    // Decorative rings at the joint.
    final joint = buttX + length * 0.5;
    canvas.drawRect(Rect.fromLTWH(joint - r * 0.15, -thick * 0.42, r * 0.3, thick * 0.84), Paint()..color = const Color(0xFFC9A227));
    canvas.drawRect(Rect.fromLTWH(joint + r * 0.4, -thick * 0.42, r * 0.12, thick * 0.84), Paint()..color = const Color(0xFFC9A227));
    // Ferrule and tip.
    canvas.drawRect(Rect.fromLTWH(tipX - r * 0.55, -thick * 0.28, r * 0.55, thick * 0.56), Paint()..color = const Color(0xFFF1E9DA));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(tipX - r * 0.08, -thick * 0.27, r * 0.22, thick * 0.54), Radius.circular(r * 0.1)), Paint()..color = const Color(0xFF3F7AC8));
  }
}
