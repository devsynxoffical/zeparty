import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects built from the shared particle sheet (3 x 2: glow, sparkle,
/// gold confetti, red confetti, ring, bokeh). Falls back to drawn circles when
/// the sheet is missing. Budgets scale with [GraphicsQuality] and "reduce effects".
class Fx {
  Fx({required this.sheet, required this.unit});

  final SpriteSheet? sheet;

  /// World pixels per table unit (ball radius is about 2.86 of these).
  final double unit;
  final _rng = math.Random();

  Sprite? _sprite(int row, int col) => sheet?.getSprite(row, col);
  Sprite? get glow => _sprite(0, 0);
  Sprite? get sparkle => _sprite(0, 1);
  Sprite? get confettiGold => _sprite(0, 2);
  Sprite? get confettiRed => _sprite(1, 0);
  Sprite? get ring => _sprite(1, 1);
  Sprite? get bokeh => _sprite(1, 2);

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
    return CircleParticle(radius: size / 2, paint: Paint()..color = color);
  }

  /// Burst of sparks at a pocket when a ball drops.
  Component pocketBurst(Vector2 at, {required Color color, int count = 26}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.75,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.5 + _rng.nextDouble()) * unit * 14;
          final s = unit * (0.6 + _rng.nextDouble() * 0.9);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 18),
            child: ScalingParticle(to: 0, child: _dot(i % 3 == 0 ? sparkle : glow, s, i % 4 == 0 ? ZpColors.goldLight : color)),
          );
        },
      ),
    );
  }

  Component ringPulse(Vector2 at, {required Color color}) => ParticleSystemComponent(
        priority: 15,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.55,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, unit * (2 + t * 6), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.5 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Small puff of chalk at the cue tip on impact.
  Component chalkPuff(Vector2 at, double angle) {
    final n = _budget(10);
    return ParticleSystemComponent(
      priority: 40,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.35,
        generator: (i) {
          final a = angle + math.pi + (_rng.nextDouble() - 0.5) * 1.2;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * unit * (3 + _rng.nextDouble() * 5),
            child: ScalingParticle(to: 0, child: _dot(bokeh, unit * 0.8, Colors.white.withValues(alpha: 0.5))),
          );
        },
      ),
    );
  }

  /// Full-table confetti rain for the winner.
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(120);
    return ParticleSystemComponent(
      priority: 70,
      particle: Particle.generate(
        count: n,
        lifespan: 2.8,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => confettiGold, 1 => confettiRed, 2 => ring, _ => sparkle };
          final tint = switch (i % 4) { 0 => ZpColors.goldLight, 1 => accent, 2 => ZpColors.champagne, _ => Colors.white };
          return AcceleratedParticle(
            position: Vector2(x, -unit * (4 + _rng.nextDouble() * 30)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 8, unit * (8 + _rng.nextDouble() * 10)),
            acceleration: Vector2(0, unit * 6),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 6,
              child: _dot(sprite, unit * 1.6, tint),
            ),
          );
        },
      ),
    );
  }

  /// Slow drifting dust in the spotlight (high quality only).
  Component ambientDust(Vector2 size) {
    if (!GraphicsSettings.instance.current.ambientAnimation || GraphicsSettings.instance.reduceEffects) return Component();
    return ParticleSystemComponent(
      priority: 5,
      particle: Particle.generate(
        count: 20,
        lifespan: 10,
        generator: (i) => MovingParticle(
          from: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          to: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          child: _dot(bokeh, unit * (0.4 + _rng.nextDouble() * 0.8), ZpColors.goldLight.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}
