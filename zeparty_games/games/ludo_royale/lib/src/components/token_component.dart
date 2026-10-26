import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/board.dart';
import 'board_component.dart';

/// One player token. Moves along the board path with hop animations, shows a
/// pulsing legal-move ring and a contact shadow, and reports taps.
class TokenComponent extends PositionComponent with TapCallbacks {
  TokenComponent({required this.seat, required this.color, required this.index, required this.sprite, required this.board, required this.onTap, required this.cellSize})
      : super(size: Vector2.all(cellSize * 0.92), anchor: Anchor.center, priority: 20);

  final int seat;
  final LudoColor color;
  final int index;
  final Sprite sprite;
  final BoardComponent board;
  final double cellSize;
  final void Function(TokenComponent) onTap;

  int step = -1;
  bool _legal = false;
  bool _selected = false;
  double _pulse = 0;
  double _lift = 0;
  bool moving = false;

  Color get tint => BoardComponent.colorOf(color);

  set legal(bool v) {
    _legal = v;
    if (!v) _selected = false;
  }

  bool get legal => _legal;
  set selected(bool v) => _selected = v;

  /// Place instantly (initial sync, reconnection, drift correction).
  void snapTo(int newStep, {Vector2? offset}) {
    step = newStep;
    position = board.cellCenter(cellForStep(color, newStep, index)) + (offset ?? Vector2.zero());
    _updatePriority();
  }

  void _updatePriority() => priority = 20 + (position.y / cellSize).floor();

  /// Animate along every cell between the current step and [to]. Resolves when done.
  Future<void> moveTo(int to, {Vector2? finalOffset, double stepDuration = 0.16, void Function(int)? onStep}) async {
    if (moving) return;
    moving = true;
    _legal = false;
    _selected = false;
    final from = step;
    final cells = from < 0 && to == 0 ? [cellForStep(color, 0, index)] : pathCells(color, from, to, index);
    for (var i = 0; i < cells.length; i++) {
      final target = board.cellCenter(cells[i]) + (i == cells.length - 1 ? (finalOffset ?? Vector2.zero()) : Vector2.zero());
      final c = Completer<void>();
      final dur = from < 0 ? stepDuration * 2.2 : stepDuration;
      add(MoveToEffect(target, EffectController(duration: dur, curve: Curves.easeInOut), onComplete: c.complete));
      add(_HopEffect(duration: dur, height: from < 0 ? cellSize * 0.8 : cellSize * 0.35, onLift: (v) => _lift = v));
      await c.future;
      step = from < 0 ? 0 : from + i + 1;
      _updatePriority();
      onStep?.call(step);
    }
    step = to;
    moving = false;
  }

  /// Captured: shrink + fly back to base.
  Future<void> sendHome() async {
    moving = true;
    final c = Completer<void>();
    final target = board.cellCenter(cellForStep(color, -1, index));
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.25), EffectController(duration: 0.12, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(0.6), EffectController(duration: 0.18, curve: Curves.easeIn)),
    ]));
    add(MoveToEffect(target, EffectController(duration: 0.55, curve: Curves.easeInOutCubic, startDelay: 0.1), onComplete: () {
      add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.25, curve: Curves.elasticOut), onComplete: c.complete));
    }));
    await c.future;
    step = -1;
    _updatePriority();
    moving = false;
  }

  Future<void> celebrateHome() async {
    final c = Completer<void>();
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.35), EffectController(duration: 0.18, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(0.78), EffectController(duration: 0.3, curve: Curves.easeInBack)),
    ], onComplete: c.complete));
    await c.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_legal) _pulse = (_pulse + dt * 2.2) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final center = Offset(r, r);
    // Contact shadow (larger and softer when lifted).
    final shadowScale = 1 + _lift / cellSize * 0.6;
    canvas.drawOval(Rect.fromCenter(center: Offset(r, r * 1.55), width: size.x * 0.75 * shadowScale, height: size.x * 0.28 * shadowScale), Paint()..color = Colors.black.withValues(alpha: 0.35 / shadowScale)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25));
    if (_legal) {
      final glow = 0.55 + 0.45 * math.sin(_pulse);
      canvas.drawCircle(center, r * (1.05 + 0.08 * glow), Paint()..color = ZpColors.goldLight.withValues(alpha: 0.18 + 0.25 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35));
      canvas.drawCircle(center, r * 1.02, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.12..color = (_selected ? Colors.white : ZpColors.goldLight).withValues(alpha: 0.5 + 0.5 * glow));
    }
    canvas.save();
    canvas.translate(0, -_lift);
    sprite.render(canvas, size: size, overridePaint: Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (moving) return;
    onTap(this);
  }

  @override
  bool containsLocalPoint(Vector2 point) => (point - size / 2).length <= size.x * 0.62;
}

/// Parabolic lift used during hops; purely visual, does not touch position.
class _HopEffect extends Effect {
  _HopEffect({required double duration, required this.height, required this.onLift}) : super(EffectController(duration: duration));
  final double height;
  final void Function(double) onLift;

  @override
  void apply(double progress) => onLift(math.sin(progress * math.pi) * height);

  @override
  void onFinish() {
    onLift(0);
    super.onFinish();
    removeFromParent();
  }
}
