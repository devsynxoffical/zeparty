import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// One dart. Flies in from the bottom of the screen along an arc, shrinking with a
/// slight spin, then sticks into the board with a wobble. [position] is the tip.
class DartComponent extends PositionComponent {
  DartComponent({required this.sprite, required this.gold, required double length, this.seatColor = ZpColors.gold})
      : super(size: Vector2(length * 0.5, length), anchor: Anchor.topCenter, priority: 40);

  final Sprite? sprite;
  final bool gold;
  final Color seatColor;

  /// Resting lean so a front-view dart reads as stuck into the board.
  static const double restAngle = 0.22;

  bool flying = false;
  bool stuck = false;
  double _t = 0;
  double _duration = 0.5;
  Vector2 _from = Vector2.zero();
  Vector2 _to = Vector2.zero();
  double _startScale = 2.4;
  Completer<void>? _done;

  /// Place instantly as a stuck dart (snapshots, late join).
  void stickAt(Vector2 tip) {
    position = tip;
    scale = Vector2.all(1);
    angle = restAngle;
    flying = false;
    stuck = true;
  }

  Future<void> flyTo(Vector2 tip, {required Vector2 from, double duration = 0.5}) {
    _done?.complete();
    _done = Completer<void>();
    _from = from;
    _to = tip;
    _t = 0;
    _duration = duration;
    _startScale = 2.4;
    position = from.clone();
    scale = Vector2.all(_startScale);
    angle = -0.35;
    flying = true;
    stuck = false;
    return _done!.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!flying) return;
    _t = math.min(_duration, _t + dt);
    final k = _t / _duration;
    final e = Curves.easeIn.transform(k);
    final lift = math.sin(k * math.pi) * size.y * 0.9;
    position = Vector2(_from.x + (_to.x - _from.x) * e, _from.y + (_to.y - _from.y) * e - lift);
    final s = _startScale + (1 - _startScale) * Curves.easeOut.transform(k);
    scale = Vector2.all(s);
    angle = -0.35 + (restAngle + 0.35) * k + math.sin(k * math.pi * 2) * 0.12 * (1 - k);
    if (_t >= _duration) {
      flying = false;
      stuck = true;
      position = _to.clone();
      scale = Vector2.all(1);
      angle = restAngle;
      _wobble();
      _done?.complete();
    }
  }

  void _wobble() {
    add(SequenceEffect([
      RotateEffect.by(0.16, EffectController(duration: 0.06)),
      RotateEffect.by(-0.26, EffectController(duration: 0.09)),
      RotateEffect.by(0.14, EffectController(duration: 0.08)),
      RotateEffect.by(-0.04, EffectController(duration: 0.07)),
    ]));
  }

  Future<void> fadeOut() {
    final c = Completer<void>();
    add(ScaleEffect.to(Vector2.all(0.01), EffectController(duration: 0.22, curve: Curves.easeIn), onComplete: () {
      removeFromParent();
      c.complete();
    }));
    return c.future;
  }

  @override
  void render(Canvas canvas) {
    final s = sprite;
    if (s != null) {
      // Contact shadow on the board, offset down-right like a real spotlight.
      if (stuck) canvas.drawOval(Rect.fromCenter(center: Offset(size.x * 0.5, size.y * 0.05), width: size.x * 0.5, height: size.x * 0.2), Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      s.render(canvas, size: size);
      return;
    }
    _renderProcedural(canvas);
  }

  void _renderProcedural(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final cx = w / 2;
    final metal = gold ? const [Color(0xFFF6E3A1), Color(0xFFC9A227), Color(0xFF7A5A0E)] : const [Color(0xFFF2F4F7), Color(0xFF9EA4AD), Color(0xFF4B5058)];
    // Point.
    canvas.drawPath(Path()..moveTo(cx, 0)..lineTo(cx - w * 0.05, h * 0.2)..lineTo(cx + w * 0.05, h * 0.2)..close(), Paint()..shader = LinearGradient(colors: metal).createShader(Rect.fromLTWH(cx - w * 0.05, 0, w * 0.1, h * 0.2)));
    // Barrel: brushed metal with knurl lines.
    final barrel = Rect.fromLTWH(cx - w * 0.14, h * 0.2, w * 0.28, h * 0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(barrel, Radius.circular(w * 0.08)), Paint()..shader = LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: metal, stops: const [0, 0.45, 1]).createShader(barrel));
    final knurl = Paint()..color = Colors.black.withValues(alpha: 0.28)..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final y = barrel.top + barrel.height * i / 8;
      canvas.drawLine(Offset(barrel.left + 2, y), Offset(barrel.right - 2, y), knurl);
    }
    // Shaft.
    final shaft = Rect.fromLTWH(cx - w * 0.07, h * 0.5, w * 0.14, h * 0.22);
    canvas.drawRRect(RRect.fromRectAndRadius(shaft, Radius.circular(w * 0.04)), Paint()..color = gold ? const Color(0xFF3A2A08) : const Color(0xFF1B1D22));
    // Flights: two translucent wings with the seat accent.
    final flight = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [seatColor.withValues(alpha: 0.95), seatColor.withValues(alpha: 0.65)]).createShader(Rect.fromLTWH(0, h * 0.7, w, h * 0.3));
    canvas.drawPath(Path()..moveTo(cx, h * 0.66)..lineTo(cx - w * 0.5, h * 0.98)..lineTo(cx - w * 0.5, h * 0.86)..lineTo(cx, h * 0.74)..close(), flight);
    canvas.drawPath(Path()..moveTo(cx, h * 0.66)..lineTo(cx + w * 0.5, h * 0.98)..lineTo(cx + w * 0.5, h * 0.86)..lineTo(cx, h * 0.74)..close(), flight);
    canvas.drawPath(Path()..moveTo(cx, h * 0.66)..lineTo(cx - w * 0.5, h * 0.98)..lineTo(cx, h * 0.92)..lineTo(cx + w * 0.5, h * 0.98)..close(), Paint()..color = Colors.white.withValues(alpha: 0.18));
  }
}
