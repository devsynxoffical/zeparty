import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'arena_component.dart';

/// Particle and screen effects built from the shared particle sheet. Budgets
/// scale with [GraphicsQuality] and respect "reduce effects". When the sheet is
/// missing every effect falls back to procedurally drawn glows.
class Fx {
  Fx({this.sheet, required this.unit});

  /// 3 x 2 sheet: glow, sparkle, gold confetti, red confetti, ring, bokeh.
  final SpriteSheet? sheet;
  final double unit;
  final _rng = math.Random();

  Sprite? get glow => sheet?.getSprite(0, 0);
  Sprite? get sparkle => sheet?.getSprite(0, 1);
  Sprite? get confettiGold => sheet?.getSprite(0, 2);
  Sprite? get confettiRed => sheet?.getSprite(1, 0);
  Sprite? get ring => sheet?.getSprite(1, 1);
  Sprite? get bokeh => sheet?.getSprite(1, 2);

  int _budget(int wanted) {
    final q = GraphicsSettings.instance;
    final cap = q.current.particleBudget ~/ 4;
    final n = math.min(wanted, cap);
    return q.reduceEffects ? n ~/ 3 : n;
  }

  Particle _dot(Sprite? sprite, double size, Color color) {
    if (sprite != null) {
      return SpriteParticle(sprite: sprite, size: Vector2.all(size), overridePaint: Paint()..colorFilter = ColorFilter.mode(color, BlendMode.modulate));
    }
    return CircleParticle(radius: size / 2, paint: Paint()..color = color..blendMode = BlendMode.plus);
  }

  /// Contact burst: sparks fly away from the hit point, biased along [direction].
  Component sparks(Vector2 at, {required Color color, Vector2? direction, int count = 18, double speed = 1}) {
    final n = _budget(count);
    final dir = direction == null || direction.length2 == 0 ? null : direction.normalized();
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.45,
        generator: (i) {
          var a = _rng.nextDouble() * math.pi * 2;
          if (dir != null) a = math.atan2(dir.y, dir.x) + (_rng.nextDouble() - 0.5) * 1.8;
          final v = (0.5 + _rng.nextDouble()) * unit * 45 * speed;
          final s = unit * (1.2 + _rng.nextDouble() * 1.6);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2.zero(),
            child: ScalingParticle(to: 0, child: _dot(i % 3 == 0 ? sparkle : glow, s, i % 4 == 0 ? NeonPalette.white : color)),
          );
        },
      ),
    );
  }

  Component ringPulse(Vector2 at, {required Color color, double scale = 1}) => ParticleSystemComponent(
        priority: 16,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.55,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(
              Offset.zero,
              unit * (4 + t * 16) * scale,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = unit * 1.2 * (1 - t) + 0.5
                ..color = color.withValues(alpha: (1 - t) * 0.9),
            );
          },
        ),
      );

  /// Goal explosion at the goal mouth: a big radial burst plus confetti-like shards.
  Component goalExplosion(Vector2 at, {required Color color, required bool upward}) {
    final n = _budget(64);
    final dirY = upward ? -1.0 : 1.0;
    return ParticleSystemComponent(
      priority: 70,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 1.1,
        generator: (i) {
          final a = -math.pi / 2 * dirY + (_rng.nextDouble() - 0.5) * math.pi * 1.1;
          final v = (0.6 + _rng.nextDouble()) * unit * 70;
          final s = unit * (1.5 + _rng.nextDouble() * 3);
          final sprite = switch (i % 4) { 0 => sparkle, 1 => ring, 2 => glow, _ => confettiGold };
          final tint = switch (i % 3) { 0 => NeonPalette.white, 1 => color, _ => Color.lerp(color, NeonPalette.white, 0.5)! };
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 40 * dirY),
            child: RotatingParticle(from: 0, to: _rng.nextDouble() * math.pi * 4, child: ScalingParticle(to: 0.1, child: _dot(sprite, s, tint))),
          );
        },
      ),
    );
  }

  /// Full-arena confetti rain for the winner.
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(120);
    return ParticleSystemComponent(
      priority: 80,
      particle: Particle.generate(
        count: n,
        lifespan: 3.2,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => confettiGold, 1 => confettiRed, 2 => ring, _ => sparkle };
          final tint = switch (i % 4) { 0 => accent, 1 => NeonPalette.white, 2 => Color.lerp(accent, NeonPalette.white, 0.5)!, _ => accent };
          final s = unit * (2.5 + _rng.nextDouble() * 2.5);
          return AcceleratedParticle(
            position: Vector2(x, -unit * (5 + _rng.nextDouble() * 60)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 20, unit * (20 + _rng.nextDouble() * 20)),
            acceleration: Vector2(0, unit * 15),
            child: RotatingParticle(from: _rng.nextDouble() * math.pi, to: _rng.nextDouble() * math.pi * 6, child: _dot(sprite, s, tint)),
          );
        },
      ),
    );
  }

  /// Ambient drifting bokeh over the arena (high quality only).
  Component ambient(Vector2 size) {
    if (!GraphicsSettings.instance.current.ambientAnimation || GraphicsSettings.instance.reduceEffects) return Component();
    return ParticleSystemComponent(
      priority: 5,
      particle: Particle.generate(
        count: 18,
        lifespan: 10,
        generator: (i) => MovingParticle(
          from: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          to: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          child: _dot(bokeh, unit * (1 + _rng.nextDouble() * 2.5), (i.isEven ? NeonPalette.cyan : NeonPalette.magenta).withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}

/// Full-screen flash that fades out; added to the world on goals.
class ScreenFlash extends PositionComponent {
  ScreenFlash({required Vector2 size, required this.color, this.duration = 0.35}) : super(position: Vector2.zero(), size: size, priority: 90);
  final Color color;
  final double duration;
  double _t = 0;
  final Paint _p = Paint()..blendMode = BlendMode.plus;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final f = (1 - _t / duration).clamp(0.0, 1.0);
    _p.color = color.withValues(alpha: 0.55 * f * f);
    canvas.drawRect(size.toRect(), _p);
  }
}
