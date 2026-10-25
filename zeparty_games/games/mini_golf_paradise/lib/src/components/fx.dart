import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects for the course, built from the shared particle sheet with
/// procedural fallbacks. Budgets scale with graphics quality and "reduce effects".
class Fx {
  Fx({required this.sheet, required this.unit});

  /// 3 x 2 sheet: glow, sparkle, gold confetti, red confetti, ring, bokeh. Null = procedural.
  final SpriteSheet? sheet;

  /// World pixels per course unit.
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

  Particle _bit(Sprite? sprite, Vector2 size, Color tint, {bool shard = false}) {
    if (sprite != null) {
      return SpriteParticle(sprite: sprite, size: size, overridePaint: Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    }
    return ComputedParticle(renderer: (canvas, p) {
      final a = (1 - p.progress).clamp(0.0, 1.0);
      if (shard) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size.x, height: size.y), Radius.circular(size.x * 0.2)), Paint()..color = tint.withValues(alpha: a));
      } else {
        canvas.drawCircle(Offset.zero, size.x / 2, Paint()..color = tint.withValues(alpha: a * 0.9)..maskFilter = MaskFilter.blur(BlurStyle.normal, size.x * 0.25));
      }
    });
  }

  /// Small dust puff when the ball hits a wall or obstacle.
  Component impactPuff(Vector2 at, {Color color = const Color(0xFFE9E2CC), int count = 8}) {
    final n = _budget(count);
    if (n == 0) return Component();
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.35,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.4 + _rng.nextDouble()) * unit * 6;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            child: ScalingParticle(to: 0, child: _bit(glow, Vector2.all(unit * (0.8 + _rng.nextDouble() * 0.8)), color)),
          );
        },
      ),
    );
  }

  /// Blue-tinted splash when the ball enters water.
  Component splash(Vector2 at) {
    final n = _budget(26);
    return ParticleSystemComponent(
      priority: 65,
      position: at,
      particle: Particle.generate(
        count: n + 1,
        lifespan: 0.8,
        generator: (i) {
          if (i == n) {
            // Expanding ripple ring.
            return ComputedParticle(renderer: (canvas, p) {
              final t = p.progress;
              canvas.drawCircle(Offset.zero, unit * (1 + t * 7), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.5 * (1 - t)..color = Colors.white.withValues(alpha: (1 - t) * 0.8));
            });
          }
          final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2;
          final v = (0.6 + _rng.nextDouble()) * unit * 14;
          final tint = i.isEven ? const Color(0xFF8FE3FF) : const Color(0xFF3FB6E8);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 40),
            child: ScalingParticle(to: 0.2, child: _bit(i % 3 == 0 ? sparkle : glow, Vector2.all(unit * (0.7 + _rng.nextDouble() * 0.9)), tint)),
          );
        },
      ),
    );
  }

  /// Expanding ring at the cup.
  Component ringPulse(Vector2 at, {required Color color, double scale = 1}) => ParticleSystemComponent(
        priority: 55,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.7,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, unit * scale * (2 + t * 7), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.9 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Gold sparkle fountain for a holed ball.
  Component holeSparkle(Vector2 at) {
    final n = _budget(24);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 1.1,
        generator: (i) {
          final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.6;
          final v = (0.5 + _rng.nextDouble()) * unit * 16;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 22),
            child: ScalingParticle(to: 0, child: _bit(i.isEven ? sparkle : bokeh, Vector2.all(unit * (0.9 + _rng.nextDouble() * 1.2)), ZpColors.goldLight)),
          );
        },
      ),
    );
  }

  /// Confetti rain across the course (hole in one, match winner).
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(110);
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
            position: Vector2(x, -unit * (2 + _rng.nextDouble() * 20)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 8, unit * (10 + _rng.nextDouble() * 10)),
            acceleration: Vector2(0, unit * 6),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 6,
              child: _bit(sprite, Vector2(unit * 1.4, unit * 1.9), tint, shard: true),
            ),
          );
        },
      ),
    );
  }

  /// Slow drifting fireflies / pollen for the ambient layer (high quality only).
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
          child: _bit(bokeh, Vector2.all(unit * (0.6 + _rng.nextDouble() * 1.2)), const Color(0x66FFF4C2)),
        ),
      ),
    );
  }
}
