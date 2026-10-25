import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects built from the shared particle sheet. Budgets scale with
/// [GraphicsQuality] and respect "reduce effects".
class Fx {
  Fx({required this.sheet, required this.cellSize});

  /// 3 x 2 sheet: glow, sparkle, gold confetti, red confetti, ring, bokeh.
  final SpriteSheet sheet;
  final double cellSize;
  final _rng = math.Random();

  Sprite get glow => sheet.getSprite(0, 0);
  Sprite get sparkle => sheet.getSprite(0, 1);
  Sprite get confettiGold => sheet.getSprite(0, 2);
  Sprite get confettiRed => sheet.getSprite(1, 0);
  Sprite get ring => sheet.getSprite(1, 1);
  Sprite get bokeh => sheet.getSprite(1, 2);

  int _budget(int wanted) {
    final q = GraphicsSettings.instance;
    final cap = q.current.particleBudget ~/ 4;
    final n = math.min(wanted, cap);
    return q.reduceEffects ? n ~/ 3 : n;
  }

  Component burst(Vector2 at, {required Color color, int count = 28, double speed = 1}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.7,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.6 + _rng.nextDouble()) * cellSize * 4 * speed;
          final sprite = i % 3 == 0 ? sparkle : glow;
          final s = cellSize * (0.18 + _rng.nextDouble() * 0.22);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, cellSize * 6),
            child: ScalingParticle(
              to: 0,
              child: SpriteParticle(sprite: sprite, size: Vector2.all(s), overridePaint: Paint()..colorFilter = ColorFilter.mode(color, BlendMode.modulate)),
            ),
          );
        },
      ),
    );
  }

  Component ringPulse(Vector2 at, {required Color color}) => ParticleSystemComponent(
        priority: 15,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.6,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, cellSize * (0.3 + t * 1.2), Paint()..style = PaintingStyle.stroke..strokeWidth = cellSize * 0.1 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  Component homeSparkle(Vector2 at) {
    final n = _budget(22);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 1.1,
        generator: (i) {
          final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 1.6;
          final v = (0.5 + _rng.nextDouble()) * cellSize * 3;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, cellSize * 2.5),
            child: ScalingParticle(to: 0, child: SpriteParticle(sprite: i.isEven ? sparkle : bokeh, size: Vector2.all(cellSize * (0.2 + _rng.nextDouble() * 0.25)), overridePaint: Paint()..colorFilter = const ColorFilter.mode(ZpColors.goldLight, BlendMode.modulate))),
          );
        },
      ),
    );
  }

  /// Full-board confetti rain for the winner.
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
            position: Vector2(x, -cellSize * (1 + _rng.nextDouble() * 6)),
            speed: Vector2((_rng.nextDouble() - 0.5) * cellSize * 2, cellSize * (2 + _rng.nextDouble() * 2)),
            acceleration: Vector2(0, cellSize * 1.5),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 6,
              child: SpriteParticle(sprite: sprite, size: Vector2(cellSize * 0.32, cellSize * 0.42), overridePaint: Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate)),
            ),
          );
        },
      ),
    );
  }

  /// Slow drifting dust for the ambient layer (high quality only).
  Component ambientDust(Vector2 size) {
    if (!GraphicsSettings.instance.current.ambientAnimation || GraphicsSettings.instance.reduceEffects) return Component();
    return ParticleSystemComponent(
      priority: 5,
      particle: Particle.generate(
        count: 24,
        lifespan: 9,
        generator: (i) => MovingParticle(
          from: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          to: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          child: SpriteParticle(sprite: bokeh, size: Vector2.all(cellSize * (0.1 + _rng.nextDouble() * 0.2)), overridePaint: Paint()..colorFilter = ColorFilter.mode(ZpColors.goldLight.withValues(alpha: 0.35), BlendMode.modulate)),
        ),
      ),
    );
  }
}
