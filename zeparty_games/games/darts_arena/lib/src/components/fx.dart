import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects built from the shared particle sheet, with procedural
/// particles when the sheet is not bundled. Budgets scale with graphics
/// quality and respect "reduce effects".
class Fx {
  Fx({required this.sheet, required this.unit});

  /// 3 x 2 sheet: glow, sparkle, gold confetti, red confetti, ring, bokeh. Null = procedural.
  final SpriteSheet? sheet;

  /// Reference length (board radius) that sizes every effect.
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

  /// Impact sparks where a dart lands.
  Component impact(Vector2 at, {required Color color, int count = 14}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 70,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.45,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.4 + _rng.nextDouble()) * unit * 0.9;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 1.5),
            child: ScalingParticle(to: 0, child: _bit(i.isEven ? sparkle : glow, Vector2.all(unit * (0.03 + _rng.nextDouble() * 0.04)), color)),
          );
        },
      ),
    );
  }

  /// Gold burst for a bullseye.
  Component bullseyeBurst(Vector2 at) {
    final n = _budget(42);
    return ParticleSystemComponent(
      priority: 75,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.9,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.5 + _rng.nextDouble()) * unit * 1.6;
          final sprite = switch (i % 3) { 0 => confettiGold, 1 => sparkle, _ => glow };
          final tint = i % 3 == 2 ? Colors.white : ZpColors.goldLight;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 2.2),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 4,
              child: ScalingParticle(to: 0.2, child: _bit(sprite, Vector2(unit * 0.05, unit * 0.07), tint, shard: i % 3 == 0)),
            ),
          );
        },
      ),
    );
  }

  Component ringPulse(Vector2 at, {required Color color}) => ParticleSystemComponent(
        priority: 45,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.55,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, unit * (0.05 + t * 0.35), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.02 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Full-scene confetti rain for a leg or match win.
  Component confetti(Vector2 size, {required Color accent, int count = 120}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 90,
      particle: Particle.generate(
        count: n,
        lifespan: 2.8,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => confettiGold, 1 => confettiRed, 2 => ring, _ => sparkle };
          final tint = switch (i % 4) { 0 => ZpColors.goldLight, 1 => accent, 2 => ZpColors.champagne, _ => Colors.white };
          return AcceleratedParticle(
            position: Vector2(x, -unit * (0.2 + _rng.nextDouble() * 1.5)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 0.6, unit * (0.5 + _rng.nextDouble() * 0.5)),
            acceleration: Vector2(0, unit * 0.4),
            child: RotatingParticle(
              from: _rng.nextDouble() * math.pi,
              to: _rng.nextDouble() * math.pi * 6,
              child: _bit(sprite, Vector2(unit * 0.08, unit * 0.11), tint, shard: true),
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
          child: _bit(bokeh, Vector2.all(unit * (0.03 + _rng.nextDouble() * 0.05)), ZpColors.goldLight.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
