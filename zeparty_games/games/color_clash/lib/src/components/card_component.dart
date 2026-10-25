import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../model/card.dart';
import 'card_painter.dart';
import 'layout.dart';

/// One rendered card in the world. Handles the 3D-ish flip (scale-x through zero
/// swapping back and face), glow for playable cards, dimming, lift-on-select and
/// fly-to animations. Tap reporting is optional.
class CardComponent extends PositionComponent with TapCallbacks {
  CardComponent({this.card, bool faceUp = false, required this.art, this.onTap, double scale = 1, super.position})
      : _faceUp = faceUp,
        super(size: Vector2(ArenaLayout.cardW, ArenaLayout.cardH), anchor: Anchor.center, scale: Vector2.all(scale), priority: 30);

  final CardArt art;
  final void Function(CardComponent)? onTap;

  CcCard? card;
  bool _faceUp;
  /// 0 = showing current side fully, 1 = mid flip (edge on).
  double _flip = 0;
  double _flipDir = 0;
  double _sheen = math.Random().nextDouble();
  double glowStrength = 0;
  double dim = 0;
  bool playable = false;
  bool selected = false;
  bool busy = false;
  Color? glowColor;
  double _pulse = math.Random().nextDouble() * math.pi * 2;
  Completer<void>? _flipDone;

  bool get faceUp => _faceUp;

  /// Instantly show the given side.
  void showFace(bool up) {
    _faceUp = up;
    _flip = 0;
    _flipDir = 0;
  }

  /// Animate a flip to [up]. Resolves when done.
  Future<void> flipTo(bool up, {double duration = 0.32}) {
    if (_faceUp == up && _flipDir == 0) return Future.value();
    _flipDone?.complete();
    final c = Completer<void>();
    _flipDone = c;
    _flipTarget = up;
    _flipDir = 1 / (duration / 2);
    return c.future;
  }

  bool _flipTarget = true;

  /// Move with an arc and rotation. Resolves when the card lands.
  Future<void> flyTo(Vector2 target, {double angleTo = 0, double duration = 0.42, double arc = 90, Curve curve = Curves.easeInOutCubic}) {
    busy = true;
    final c = Completer<void>();
    final start = position.clone();
    final startAngle = angle;
    var t = 0.0;
    add(_LambdaEffect(
      duration: duration,
      onTick: (p) {
        t = curve.transform(p);
        final x = start.x + (target.x - start.x) * t;
        final y = start.y + (target.y - start.y) * t - math.sin(t * math.pi) * arc;
        position.setValues(x, y);
        angle = startAngle + (angleTo - startAngle) * t;
      },
      onDone: () {
        position.setFrom(target);
        angle = angleTo;
        busy = false;
        c.complete();
      },
    ));
    return c.future;
  }

  Future<void> scaleTo(double s, {double duration = 0.25}) {
    final c = Completer<void>();
    add(ScaleEffect.to(Vector2.all(s), EffectController(duration: duration, curve: Curves.easeOut), onComplete: c.complete));
    return c.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 2.2;
    _sheen = (_sheen + dt * 0.12) % 1;
    if (_flipDir != 0) {
      _flip += dt * _flipDir;
      if (_flipDir > 0 && _flip >= 1) {
        // Edge on: swap side, come back.
        _flip = 1;
        _faceUp = _flipTarget;
        _flipDir = -_flipDir;
      } else if (_flipDir < 0 && _flip <= 0) {
        _flip = 0;
        _flipDir = 0;
        _flipDone?.complete();
        _flipDone = null;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final sx = (1 - _flip).clamp(0.02, 1.0);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(sx, 1 + (1 - sx) * 0.04);
    canvas.translate(-size.x / 2, -size.y / 2);
    final rect = Offset.zero & size.toSize();
    final pulse = playable ? 0.65 + 0.35 * math.sin(_pulse) : 0.0;
    final glow = selected ? 1.0 : pulse * glowStrength;
    CardPainter.paint(
      canvas,
      rect,
      card: card,
      faceUp: _faceUp,
      sheen: _sheen,
      art: art,
      dim: dim,
      glow: glowColor ?? (card?.color.isWild == true ? const Color(0xFFCDB4FF) : (card?.color.color ?? Colors.white)),
      glowStrength: glow,
    );
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (onTap == null) return;
    event.handled = true;
    onTap!(this);
  }
}

/// Small helper effect that calls back with normalised progress each frame.
class _LambdaEffect extends Component {
  _LambdaEffect({required this.duration, required this.onTick, required this.onDone});
  final double duration;
  final void Function(double) onTick;
  final VoidCallback onDone;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    final p = (_t / duration).clamp(0.0, 1.0);
    onTick(p);
    if (p >= 1) {
      onDone();
      removeFromParent();
    }
  }
}
