import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects for Carrom Masters. Uses the shared 3 x 2 particle sheet
/// (glow, sparkle, gold confetti, red confetti, ring, bokeh) when it is
/// bundled and falls back to painted shapes otherwise. Budgets follow the
/// graphics quality and the "reduce effects" switch.
class Fx {
  Fx({required this.sheet, required this.unit});

  final SpriteSheet? sheet;
  /// World pixels per board unit.
  final double unit;
  final _rng = math.Random();

  Sprite? get _glow => sheet?.getSprite(0, 0);
  Sprite? get _sparkle => sheet?.getSprite(0, 1);
  Sprite? get _confettiGold => sheet?.getSprite(0, 2);
  Sprite? get _confettiRed => sheet?.getSprite(1, 0);
  Sprite? get _ring => sheet?.getSprite(1, 1);
  Sprite? get _bokeh => sheet?.getSprite(1, 2);

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

  /// Short wood-dust burst at a coin impact; intensity scales with impact speed.
  Component impact(Vector2 at, {double intensity = 0.5, Color color = const Color(0xFFF1E3B8)}) {
    final n = _budget((6 + intensity * 14).round());
    if (n <= 0) return Component();
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.35 + intensity * 0.2,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.4 + _rng.nextDouble()) * unit * (8 + 18 * intensity);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 10),
            child: ScalingParticle(to: 0, child: _dot(i.isEven ? _sparkle : _glow, unit * (0.5 + _rng.nextDouble() * 0.7), color)),
          );
        },
      ),
    );
  }

  /// Cushion thud: a flat puff pressed against the wall.
  Component cushionPuff(Vector2 at, Vector2 normal, {double intensity = 0.5}) {
    final n = _budget((4 + intensity * 8).round());
    if (n <= 0) return Component();
    return ParticleSystemComponent(
      priority: 60,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.3,
        generator: (i) {
          final spread = (_rng.nextDouble() - 0.5) * 1.6;
          final dir = Vector2(normal.x * math.cos(spread) - normal.y * math.sin(spread), normal.x * math.sin(spread) + normal.y * math.cos(spread));
          return MovingParticle(
            to: dir * unit * (3 + 6 * intensity) * _rng.nextDouble(),
            child: ScalingParticle(to: 0, child: _dot(_glow, unit * 0.6, const Color(0xAAF1E3B8))),
          );
        },
      ),
    );
  }

  /// Pocket swirl: sparks spiral into the pocket while a ring collapses.
  Component pocketSwirl(Vector2 at, {Color accent = ZpColors.goldLight}) {
    final n = _budget(18);
    final swirl = ParticleSystemComponent(
      priority: 61,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.55,
        generator: (i) {
          final a0 = _rng.nextDouble() * math.pi * 2;
          final r0 = unit * (2.5 + _rng.nextDouble() * 2.5);
          return ComputedParticle(
            lifespan: 0.55,
            renderer: (canvas, p) {
              final t = p.progress;
              final a = a0 + t * math.pi * 2.2;
              final r = r0 * (1 - t);
              final pos = Offset(math.cos(a) * r, math.sin(a) * r);
              canvas.drawCircle(pos, unit * 0.45 * (1 - t * 0.6), Paint()..color = accent.withValues(alpha: (1 - t) * 0.9));
            },
          );
        },
      ),
    );
    final ring = ParticleSystemComponent(
      priority: 61,
      position: at,
      particle: ComputedParticle(
        lifespan: 0.45,
        renderer: (canvas, p) {
          final t = p.progress;
          canvas.drawCircle(Offset.zero, unit * (4.5 - t * 3.5), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.35 * (1 - t)..color = accent.withValues(alpha: (1 - t) * 0.8));
        },
      ),
    );
    return Component(children: [swirl, ring]);
  }

  /// Ring pulse (queen covered, extra strike).
  Component ringPulse(Vector2 at, {Color color = ZpColors.goldLight}) => ParticleSystemComponent(
        priority: 15,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.6,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, unit * (2 + t * 7), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.5 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Full-board confetti rain for the winning side.
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(110);
    return ParticleSystemComponent(
      priority: 70,
      particle: Particle.generate(
        count: n,
        lifespan: 2.8,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => _confettiGold, 1 => _confettiRed, 2 => _ring, _ => _sparkle };
          final tint = switch (i % 4) { 0 => ZpColors.goldLight, 1 => accent, 2 => ZpColors.champagne, _ => Colors.white };
          return AcceleratedParticle(
            position: Vector2(x, -unit * (2 + _rng.nextDouble() * 20)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 8, unit * (10 + _rng.nextDouble() * 10)),
            acceleration: Vector2(0, unit * 6),
            child: RotatingParticle(from: _rng.nextDouble() * math.pi, to: _rng.nextDouble() * math.pi * 6, child: _dot(sprite, unit * 1.4, tint)),
          );
        },
      ),
    );
  }

  /// Slow chandelier dust for the ambient layer (high quality only).
  Component ambientDust(Vector2 size) {
    if (!GraphicsSettings.instance.current.ambientAnimation || GraphicsSettings.instance.reduceEffects) return Component();
    return ParticleSystemComponent(
      priority: 5,
      particle: Particle.generate(
        count: 18,
        lifespan: 10,
        generator: (i) => MovingParticle(
          from: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          to: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          child: _dot(_bokeh, unit * (0.6 + _rng.nextDouble() * 1.2), ZpColors.goldLight.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}
