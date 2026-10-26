import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects from the shared 3 x 2 particle sheet (glow, sparkle, gold
/// confetti, red confetti, ring, bokeh). When the sheet is missing every effect
/// falls back to painted circles so nothing depends on the bitmap.
class Fx {
  Fx({required this.sheet, required this.cellSize});

  final SpriteSheet? sheet;
  final double cellSize;
  final _rng = math.Random();

  Sprite? _s(int row, int col) => sheet?.getSprite(row, col);
  Sprite? get glow => _s(0, 0);
  Sprite? get sparkle => _s(0, 1);
  Sprite? get confettiGold => _s(0, 2);
  Sprite? get confettiRed => _s(1, 0);
  Sprite? get ring => _s(1, 1);
  Sprite? get bokeh => _s(1, 2);

  int _budget(int wanted) {
    final q = GraphicsSettings.instance;
    final cap = q.current.particleBudget ~/ 4;
    final n = math.min(wanted, cap);
    return q.reduceEffects ? n ~/ 3 : n;
  }

  Particle _dot(Sprite? sprite, double size, Color tint) {
    if (sprite != null) {
      return SpriteParticle(sprite: sprite, size: Vector2.all(size), overridePaint: Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    }
    return CircleParticle(radius: size / 2, paint: Paint()..color = tint);
  }

  /// Capture burst: sparks fly out from the taken piece.
  Component burst(Vector2 at, {required Color color, int count = 26, double speed = 1}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.7,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.6 + _rng.nextDouble()) * cellSize * 3.5 * speed;
          final s = cellSize * (0.16 + _rng.nextDouble() * 0.2);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, cellSize * 5),
            child: ScalingParticle(to: 0, child: _dot(i % 3 == 0 ? sparkle : glow, s, color)),
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
            canvas.drawCircle(Offset.zero, cellSize * (0.3 + t * 1.1), Paint()..style = PaintingStyle.stroke..strokeWidth = cellSize * 0.1 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Full-board confetti rain for checkmate.
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
          final child = sprite != null
              ? SpriteParticle(sprite: sprite, size: Vector2(cellSize * 0.3, cellSize * 0.4), overridePaint: Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate))
              : CircleParticle(radius: cellSize * 0.14, paint: Paint()..color = tint);
          return AcceleratedParticle(
            position: Vector2(x, -cellSize * (1 + _rng.nextDouble() * 6)),
            speed: Vector2((_rng.nextDouble() - 0.5) * cellSize * 2, cellSize * (2 + _rng.nextDouble() * 2)),
            acceleration: Vector2(0, cellSize * 1.5),
            child: RotatingParticle(from: _rng.nextDouble() * math.pi, to: _rng.nextDouble() * math.pi * 6, child: child),
          );
        },
      ),
    );
  }

  /// Slow drifting motes for the ambient layer (high quality only).
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
          child: _dot(bokeh, cellSize * (0.08 + _rng.nextDouble() * 0.16), ZpColors.goldLight.withValues(alpha: 0.3)),
        ),
      ),
    );
  }
}
