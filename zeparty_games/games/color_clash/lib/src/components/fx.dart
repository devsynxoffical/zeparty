import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Particle effects built from the shared particle sheet (3x2: glow, sparkle, gold
/// confetti, red confetti, ring, bokeh). When the sheet is missing every effect
/// falls back to procedural circles so the arena still celebrates.
class Fx {
  Fx({required this.sheet, required this.unit});

  final SpriteSheet? sheet;
  /// Reference length (card width) that scales every effect.
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

  Particle _dot(Sprite? sprite, double size, Color tint) {
    if (sprite != null) {
      return SpriteParticle(sprite: sprite, size: Vector2.all(size), overridePaint: Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate));
    }
    return CircleParticle(radius: size / 2, paint: Paint()..color = tint);
  }

  Component burst(Vector2 at, {required Color color, int count = 26, double speed = 1}) {
    final n = _budget(count);
    return ParticleSystemComponent(
      priority: 90,
      position: at,
      particle: Particle.generate(
        count: n,
        lifespan: 0.7,
        generator: (i) {
          final a = _rng.nextDouble() * math.pi * 2;
          final v = (0.6 + _rng.nextDouble()) * unit * 4 * speed;
          final s = unit * (0.14 + _rng.nextDouble() * 0.18);
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * v,
            acceleration: Vector2(0, unit * 5),
            child: ScalingParticle(to: 0, child: _dot(i % 3 == 0 ? sparkle : glow, s, color)),
          );
        },
      ),
    );
  }

  Component ringPulse(Vector2 at, {required Color color, double radius = 1.2}) => ParticleSystemComponent(
        priority: 40,
        position: at,
        particle: ComputedParticle(
          lifespan: 0.6,
          renderer: (canvas, p) {
            final t = p.progress;
            canvas.drawCircle(Offset.zero, unit * (0.3 + t * radius), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.08 * (1 - t)..color = color.withValues(alpha: (1 - t) * 0.9));
          },
        ),
      );

  /// Echo: three concentric waves expanding from the discard.
  Component echoWaves(Vector2 at, {required Color color}) => ParticleSystemComponent(
        priority: 40,
        position: at,
        particle: ComputedParticle(
          lifespan: 1.1,
          renderer: (canvas, p) {
            for (var i = 0; i < 3; i++) {
              final t = ((p.progress - i * 0.18) / 0.8).clamp(0.0, 1.0);
              if (t <= 0) continue;
              canvas.drawCircle(Offset.zero, unit * (0.4 + t * 2.4), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.06 * (1 - t) + 1..color = color.withValues(alpha: (1 - t) * 0.8));
            }
          },
        ),
      );

  /// Surge: a directional pulse travelling from the attacker to the victim.
  Component surgePulse(Vector2 from, Vector2 to, {required Color color}) {
    final n = _budget(18);
    return ParticleSystemComponent(
      priority: 90,
      particle: Particle.generate(
        count: n,
        lifespan: 0.55,
        generator: (i) {
          final jitter = Vector2((_rng.nextDouble() - 0.5) * unit * 0.6, (_rng.nextDouble() - 0.5) * unit * 0.6);
          return MovingParticle(
            from: from.clone(),
            to: to + jitter,
            curve: Curves.easeIn,
            child: ScalingParticle(to: 0.3, child: _dot(i.isEven ? glow : sparkle, unit * (0.2 + _rng.nextDouble() * 0.2), color)),
          );
        },
      ),
    );
  }

  /// Full-arena confetti rain for the winner.
  Component confetti(Vector2 size, {required Color accent}) {
    final n = _budget(120);
    return ParticleSystemComponent(
      priority: 100,
      particle: Particle.generate(
        count: n,
        lifespan: 3,
        generator: (i) {
          final x = _rng.nextDouble() * size.x;
          final sprite = switch (i % 4) { 0 => confettiGold, 1 => confettiRed, 2 => ring, _ => sparkle };
          final tint = switch (i % 4) { 0 => ZpColors.goldLight, 1 => accent, 2 => ZpColors.champagne, _ => Colors.white };
          return AcceleratedParticle(
            position: Vector2(x, -unit * (1 + _rng.nextDouble() * 6)),
            speed: Vector2((_rng.nextDouble() - 0.5) * unit * 2, unit * (2 + _rng.nextDouble() * 2)),
            acceleration: Vector2(0, unit * 1.5),
            child: RotatingParticle(from: _rng.nextDouble() * math.pi, to: _rng.nextDouble() * math.pi * 6, child: _dot(sprite, unit * 0.3, tint)),
          );
        },
      ),
    );
  }

  /// Slow drifting bokeh for the ambient layer (high quality only).
  Component ambientMotes(Vector2 size) {
    if (!GraphicsSettings.instance.current.ambientAnimation || GraphicsSettings.instance.reduceEffects) return Component();
    return ParticleSystemComponent(
      priority: 2,
      particle: Particle.generate(
        count: 22,
        lifespan: 10,
        generator: (i) => MovingParticle(
          from: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          to: Vector2(_rng.nextDouble() * size.x, _rng.nextDouble() * size.y),
          child: _dot(bokeh, unit * (0.08 + _rng.nextDouble() * 0.16), const Color(0xFF7FD6FF).withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}
