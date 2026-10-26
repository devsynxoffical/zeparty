import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'galaxy_palette.dart';

/// Particle effects built from the shared particle sheet, with procedural
/// particles when the sheet is not bundled. Budgets scale with graphics
/// quality and respect "reduce effects".
class Fx {
  Fx({required this.sheet, required this.cellSize});

  /// 3 x 2 sheet: glow, sparkle, gold confetti, red confetti, ring, bokeh. Null = procedural.
  final SpriteSheet? sheet;
  final double cellSize;
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

  /// A tinted sprite particle, or a soft procedural dot / shard when no sheet exists.
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

  /// Impact sparks when a disc lands.
  Component landingBurst(Vector2 at, {required Color color, int count = 16}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.5,
        generator: (i) {
          final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * math.pi * 1.4;
          final v = (0.4 + _rng.nextDouble()) * cellSize * 3;
          final s = cellSize * (0.08 + _rng.nextDouble() * 0.14);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, cellSize * 7),
            child: ScalingParticle(to: 0, child: _bit(i % 3 == 0 ? sparkle : glow, Vector2.all(s), i.isEven ? color : Colors.white)),
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

  /// Cinematic confetti rain over the whole chamber for the winner.
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(140);
    return ParticleSystemComponent(
      priority: 70,
      particle: Particle.generate(
        count: n,
        lifespan: 3.0,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => confettiGold, 1 => confettiRed, 2 => ring, _ => sparkle };
          final tint = switch (i % 4) { 0 => GalaxyPalette.goldLight, 1 => accent, 2 => GalaxyPalette.crystal, _ => Colors.white };
          return AcceleratedParticle(
            position: Vector2(x, -cellSize * (1 + _rng.nextDouble() * 6)),
            speed: Vector2((_rng.nextDouble() - 0.5) * cellSize * 2, cellSize * (2 + _rng.nextDouble() * 2)),
            acceleration: Vector2(0, cellSize * 1.5),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 6,
              child: _bit(sprite, Vector2(cellSize * 0.3, cellSize * 0.4), tint, shard: i % 4 < 2),
            ),
          );
        },
      ),
    );
  }
}
