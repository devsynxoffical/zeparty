import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticleSpec {
  final double angle;
  final double distance;
  final double size;
  final String char;
  final Color color;
  final double speed;

  const ParticleSpec({
    required this.angle,
    required this.distance,
    required this.size,
    required this.char,
    required this.color,
    required this.speed,
  });
}

/// Particle sparkle/heart overlay that drifts outward and upward around the reaction avatar.
class ReactionParticleOverlay extends StatefulWidget {
  final double radius;
  final double progress; // 0.0 to 1.0 (driven by reaction animation timeline)
  final double opacity;

  const ReactionParticleOverlay({
    super.key,
    required this.radius,
    required this.progress,
    this.opacity = 1.0,
  });

  @override
  State<ReactionParticleOverlay> createState() => _ReactionParticleOverlayState();
}

class _ReactionParticleOverlayState extends State<ReactionParticleOverlay> {
  late List<ParticleSpec> _particles;

  @override
  void initState() {
    super.initState();
    _initParticles();
  }

  void _initParticles() {
    final rand = math.Random(42);
    final symbols = ['✨', '💖', '✦', '🌟', '❣️', '✨', '💕', '✦'];
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF4081), // Pink
      const Color(0xFFE040FB), // Purple
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFFAFAFA), // White
      const Color(0xFFFF69B4), // Hot Pink
      const Color(0xFFFFD700), // Gold
      const Color(0xFF00E5FF), // Cyan
    ];

    _particles = List.generate(8, (i) {
      final angle = (i * (2 * math.pi / 8)) + (rand.nextDouble() * 0.3 - 0.15);
      return ParticleSpec(
        angle: angle,
        distance: widget.radius * (1.1 + rand.nextDouble() * 0.4),
        size: 10.0 + rand.nextDouble() * 6.0,
        char: symbols[i % symbols.length],
        color: colors[i % colors.length],
        speed: 18.0 + rand.nextDouble() * 14.0,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opacity <= 0.0 || widget.progress <= 0.0) return const SizedBox.shrink();

    final size = widget.radius * 3.5;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: _particles.map((p) {
          final currentDist = p.distance + (widget.progress * p.speed);
          final upwardFloat = widget.progress * 24.0;
          final dx = currentDist * math.cos(p.angle);
          final dy = (currentDist * math.sin(p.angle)) - upwardFloat;

          double particleOpacity = widget.opacity;
          if (widget.progress < 0.2) {
            particleOpacity *= (widget.progress / 0.2);
          } else if (widget.progress > 0.75) {
            particleOpacity *= (1.0 - widget.progress) / 0.25;
          }
          particleOpacity = particleOpacity.clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Opacity(
              opacity: particleOpacity,
              child: Text(
                p.char,
                style: TextStyle(
                  fontSize: p.size,
                  color: p.color,
                  shadows: [
                    Shadow(
                      color: p.color.withValues(alpha: 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
