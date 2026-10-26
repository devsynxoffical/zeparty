import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/kingdom_state.dart';
import 'board_component.dart';
import 'board_geometry.dart';

/// One player's knight. Walks square by square with hops, climbs ladders along
/// their line, slides down dragons along the Bezier and celebrates at the castle.
/// Uses `characters/knight_<color>.webp` when present and otherwise a crest shield
/// in the seat colour.
class CharacterComponent extends PositionComponent {
  CharacterComponent({required this.seat, required this.seatIndex, required this.color, required this.image, required this.geo})
      : super(size: Vector2.all(geo.cell * 0.78), anchor: Anchor.bottomCenter, priority: 20);

  final int seat;
  final int seatIndex;
  final KingdomColor color;
  final ui.Image? image;
  final BoardGeometry geo;

  /// Last settled square (0 = dock).
  int square = 0;
  bool moving = false;
  bool highlight = false;
  double _lift = 0;
  double _idle = 0;
  double _squash = 1;
  bool _facingLeft = false;

  Color get tint => KingdomBoardComponent.colorOf(color);

  /// Feet offset so the character stands on the tile centre.
  static Vector2 _footOffset(double cell) => Vector2(0, cell * 0.22);

  Vector2 _standPoint(int sq, Vector2 offset) => geo.positionFor(sq, seatIndex) + _footOffset(geo.cell) + offset;

  void snapTo(int sq, {Vector2? offset}) {
    square = sq;
    position = _standPoint(sq, offset ?? Vector2.zero());
    _updatePriority();
  }

  void _updatePriority() => priority = 20 + (position.y / geo.cell).floor();

  Future<void> _moveTo(Vector2 target, double duration, double hopHeight, {Curve curve = Curves.easeInOut}) async {
    final c = Completer<void>();
    _facingLeft = target.x < position.x - 1;
    add(MoveToEffect(target, EffectController(duration: duration, curve: curve), onComplete: c.complete));
    if (hopHeight > 0) add(_HopEffect(duration: duration, height: hopHeight, onLift: (v) => _lift = v));
    await c.future;
    _updatePriority();
  }

  /// Walk through [path] (list of squares) one hop at a time.
  Future<void> walkPath(List<int> path, {Vector2? finalOffset, void Function(int)? onStep}) async {
    if (moving || path.isEmpty) return;
    moving = true;
    final enteringFromDock = square <= 0;
    for (var i = 0; i < path.length; i++) {
      final last = i == path.length - 1;
      final target = _standPoint(path[i], last ? (finalOffset ?? Vector2.zero()) : Vector2.zero());
      final first = i == 0 && enteringFromDock;
      await _moveTo(target, first ? 0.4 : 0.17, first ? geo.cell * 0.9 : geo.cell * 0.32);
      square = path[i];
      _squash = 0.86;
      onStep?.call(square);
    }
    moving = false;
  }

  /// Climb a ladder: a steady, slightly bouncy ascent along its line.
  Future<void> climbLadder(Vector2 from, Vector2 to, int toSquare, {Vector2? finalOffset}) async {
    moving = true;
    final steps = math.max(3, ((to - from).length / (geo.cell * 0.5)).round());
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final p = from + (to - from) * t + _footOffset(geo.cell) + (i == steps ? (finalOffset ?? Vector2.zero()) : Vector2.zero());
      await _moveTo(p, 0.14, geo.cell * 0.12, curve: Curves.easeOut);
    }
    square = toSquare;
    moving = false;
  }

  /// Slide down a dragon along its Bezier (head at t = 0, tail at t = 1).
  Future<void> slideDragon(CubicBezier curve, int toSquare, {Vector2? finalOffset}) async {
    moving = true;
    final c = Completer<void>();
    final foot = _footOffset(geo.cell);
    final duration = (0.6 + curve.length() / geo.cell * 0.12).clamp(0.8, 2.2);
    add(_CurveEffect(
      curve: curve,
      duration: duration,
      onPoint: (p, t) {
        final tan = curve.tangentAt(t);
        _facingLeft = tan.x < 0;
        position = p + foot;
        angle = math.sin(t * math.pi * 3) * 0.12;
        _updatePriority();
      },
      onDone: () {
        angle = 0;
        c.complete();
      },
    ));
    await c.future;
    await _moveTo(_standPoint(toSquare, finalOffset ?? Vector2.zero()), 0.2, geo.cell * 0.25, curve: Curves.easeOut);
    square = toSquare;
    _squash = 0.8;
    moving = false;
  }

  Future<void> celebrate() async {
    final c = Completer<void>();
    add(SequenceEffect([
      ScaleEffect.to(Vector2(0.85, 1.25), EffectController(duration: 0.16, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2(1.15, 0.9), EffectController(duration: 0.14, curve: Curves.easeIn)),
      ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.3, curve: Curves.elasticOut)),
    ], onComplete: c.complete));
    add(_HopEffect(duration: 0.6, height: geo.cell * 0.9, onLift: (v) => _lift = v));
    await c.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _idle += dt;
    _squash += (1 - _squash) * math.min(1, dt * 14);
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final cell = geo.cell;
    // Contact shadow on the island, larger and softer when airborne.
    final shadowScale = 1 + _lift / cell * 0.7;
    canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - cell * 0.02), width: w * 0.6 * shadowScale, height: w * 0.2 * shadowScale), Paint()..color = Colors.black.withValues(alpha: 0.35 / shadowScale)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12));
    if (highlight) {
      final glow = 0.55 + 0.45 * math.sin(_idle * 3);
      canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, h - cell * 0.02), width: w * 0.95, height: w * 0.4), Paint()..color = ZpColors.goldLight.withValues(alpha: 0.2 + 0.3 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.2));
    }
    canvas.save();
    canvas.translate(w / 2, h - _lift);
    final breathe = 1 + math.sin(_idle * 2.2 + seatIndex) * 0.015;
    canvas.scale((_facingLeft ? -1 : 1) * (2 - _squash) * breathe, _squash * breathe);
    final img = image;
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(-w / 2, -h, w, h), Paint()..filterQuality = FilterQuality.medium);
    } else {
      _renderProceduralKnight(canvas, w, h);
    }
    canvas.restore();
  }

  /// Heraldic shield with a helmet plume and a crest, coloured by seat.
  void _renderProceduralKnight(Canvas canvas, double w, double h) {
    final c = tint;
    final light = Color.lerp(c, Colors.white, 0.35)!;
    final dark = Color.lerp(c, Colors.black, 0.4)!;
    // Shield body.
    final shield = Path()
      ..moveTo(-w * 0.34, -h * 0.72)
      ..lineTo(w * 0.34, -h * 0.72)
      ..lineTo(w * 0.34, -h * 0.36)
      ..quadraticBezierTo(w * 0.34, -h * 0.05, 0, 0)
      ..quadraticBezierTo(-w * 0.34, -h * 0.05, -w * 0.34, -h * 0.36)
      ..close();
    canvas.drawPath(shield, Paint()..shader = ui.Gradient.linear(Offset(-w * 0.3, -h * 0.7), Offset(w * 0.3, 0), [light, c, dark], [0, 0.5, 1]));
    canvas.drawPath(shield, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.05..color = ZpColors.gold);
    canvas.drawPath(shield, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.015..color = ZpColors.goldDeep);
    // Chevron crest.
    final chevron = Path()
      ..moveTo(-w * 0.22, -h * 0.4)
      ..lineTo(0, -h * 0.56)
      ..lineTo(w * 0.22, -h * 0.4)
      ..lineTo(w * 0.22, -h * 0.3)
      ..lineTo(0, -h * 0.46)
      ..lineTo(-w * 0.22, -h * 0.3)
      ..close();
    canvas.drawPath(chevron, Paint()..color = ZpColors.champagne.withValues(alpha: 0.9));
    // Helmet above the shield.
    final helm = Rect.fromCenter(center: Offset(0, -h * 0.84), width: w * 0.42, height: w * 0.4);
    canvas.drawArc(helm, math.pi, math.pi, true, Paint()..shader = ui.Gradient.linear(helm.topLeft, helm.bottomRight, [const Color(0xFFE8E8EE), const Color(0xFF8A8C98)]));
    canvas.drawRect(Rect.fromLTWH(helm.left, helm.center.dy - w * 0.02, helm.width, w * 0.1), Paint()..color = const Color(0xFF8A8C98));
    canvas.drawRect(Rect.fromLTWH(helm.left + w * 0.06, helm.center.dy, helm.width - w * 0.12, w * 0.04), Paint()..color = const Color(0xFF2A2A33));
    // Plume.
    final plume = Path()
      ..moveTo(0, helm.top + w * 0.02)
      ..quadraticBezierTo(w * 0.18, helm.top - w * 0.22, w * 0.3, helm.top - w * 0.05)
      ..quadraticBezierTo(w * 0.12, helm.top - w * 0.1, 0, helm.top + w * 0.08)
      ..close();
    canvas.drawPath(plume, Paint()..color = c);
    canvas.drawPath(plume, Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.012..color = dark);
    // Specular highlight.
    canvas.drawOval(Rect.fromCenter(center: Offset(-w * 0.14, -h * 0.6), width: w * 0.14, height: h * 0.2), Paint()..color = Colors.white.withValues(alpha: 0.25));
  }
}

/// Parabolic lift used during hops; visual only.
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

/// Drives a position along a Bezier curve.
class _CurveEffect extends Effect {
  _CurveEffect({required this.curve, required double duration, required this.onPoint, required this.onDone}) : super(EffectController(duration: duration, curve: Curves.easeInOutSine));
  final CubicBezier curve;
  final void Function(Vector2, double) onPoint;
  final VoidCallback onDone;

  @override
  void apply(double progress) => onPoint(curve.pointAt(progress), progress);

  @override
  void onFinish() {
    onPoint(curve.pointAt(1), 1);
    super.onFinish();
    removeFromParent();
    onDone();
  }
}
