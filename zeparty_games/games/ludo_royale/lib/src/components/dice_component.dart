import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Crystal die. Rolls by tumbling through faces with rotation, scale and bounce,
/// then settles on the server-authorised value. Never shows a result before the
/// server sends one: while waiting it keeps tumbling.
class DiceComponent extends PositionComponent with TapCallbacks {
  DiceComponent({required this.faces, required this.onTap, required double cellSize, required this.seatColorOf})
      : super(size: Vector2.all(cellSize * 1.35), anchor: Anchor.center, priority: 50);

  final List<Sprite> faces; // index 0 = face 1
  final VoidCallback onTap;
  final Color Function() seatColorOf;

  int face = 6;
  bool rolling = false;
  bool enabled = false;
  double _idle = 0;
  double _tumble = 0;
  int? _pendingResult;
  Completer<void>? _settle;
  final _rng = math.Random();
  double _glow = 0;

  /// Start tumbling. Call [settle] when the authoritative value arrives.
  void startRolling() {
    if (rolling) return;
    rolling = true;
    _pendingResult = null;
    _tumble = 0;
    add(ScaleEffect.to(Vector2.all(1.18), EffectController(duration: 0.14, curve: Curves.easeOut)));
  }

  /// Resolve with the server's value; completes after the landing animation.
  Future<void> settle(int value) {
    final c = Completer<void>();
    _settle = c;
    _pendingResult = value;
    if (!rolling) {
      rolling = true;
      _tumble = 0;
    }
    return c.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _idle += dt;
    if (rolling) {
      _tumble += dt;
      // Face flicker slows down over time; minimum tumble 0.55 s so quick server replies still read as a roll.
      final interval = 0.045 + _tumble * 0.06;
      if ((_tumble / interval).floor() != ((_tumble - dt) / interval).floor()) {
        var next = _rng.nextInt(6) + 1;
        if (next == face) next = next % 6 + 1;
        face = next;
      }
      angle = math.sin(_tumble * 18) * 0.35;
      if (_pendingResult != null && _tumble >= 0.55) _land();
    } else {
      angle = math.sin(_idle * 1.2) * 0.03;
      _glow = enabled ? 0.5 + 0.5 * math.sin(_idle * 3) : 0;
    }
  }

  void _land() {
    final value = _pendingResult!;
    _pendingResult = null;
    rolling = false;
    face = value;
    angle = 0;
    final c = _settle;
    _settle = null;
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(0.86), EffectController(duration: 0.08, curve: Curves.easeIn)),
      ScaleEffect.to(Vector2.all(1.12), EffectController(duration: 0.14, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.22, curve: Curves.elasticOut)),
    ], onComplete: () => c?.complete()));
    add(RotateEffect.by(_rng.nextBool() ? 0.12 : -0.12, EffectController(duration: 0.1, reverseDuration: 0.18, curve: Curves.easeOut)));
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final center = Offset(r, r);
    final lift = rolling ? math.sin(_tumble * 9).abs() * r * 0.45 : 0.0;
    // Shadow
    canvas.drawOval(Rect.fromCenter(center: Offset(r, r * 1.6), width: size.x * (0.8 - lift / size.x * 0.4), height: size.x * 0.3), Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    // Turn glow ring when it is this player's roll.
    if (_glow > 0) {
      canvas.drawCircle(center, r * (1.0 + 0.12 * _glow), Paint()..color = seatColorOf().withValues(alpha: 0.25 + 0.3 * _glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45));
    }
    canvas.save();
    canvas.translate(0, -lift);
    faces[(face - 1).clamp(0, 5)].render(canvas, size: size, overridePaint: Paint()..filterQuality = FilterQuality.medium);
    // Specular sweep while rolling
    if (rolling) {
      canvas.drawCircle(center.translate(-r * 0.3, -r * 0.3), r * 0.5, Paint()..color = Colors.white.withValues(alpha: 0.18)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3)..blendMode = BlendMode.plus);
    }
    canvas.restore();
    if (enabled && !rolling) {
      canvas.drawCircle(center, r * 1.08, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.08..color = ZpColors.goldLight.withValues(alpha: 0.35 + 0.45 * _glow));
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!enabled || rolling) return;
    onTap();
  }

  @override
  bool containsLocalPoint(Vector2 point) => (point - size / 2).length <= size.x * 0.7;
}
