import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated circular neon glowing ring around avatar with dash highlights and sweep rotation.
class AnimatedReactionRing extends StatelessWidget {
  final double radius;
  final double rotationAngle;
  final double opacity;
  final double strokeWidth;

  const AnimatedReactionRing({
    super.key,
    required this.radius,
    required this.rotationAngle,
    this.opacity = 1.0,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0.0) return const SizedBox.shrink();

    final outerSize = (radius + strokeWidth * 2 + 4) * 2;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size(outerSize, outerSize),
        painter: ReactionRingPainter(
          rotationAngle: rotationAngle,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class ReactionRingPainter extends CustomPainter {
  final double rotationAngle;
  final double strokeWidth;

  ReactionRingPainter({
    required this.rotationAngle,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final drawRadius = (size.width - strokeWidth * 2) / 2;

    if (drawRadius <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: drawRadius);

    // 1. Neon Glow Sweep Gradient
    final sweepGradient = SweepGradient(
      transform: GradientRotation(rotationAngle),
      colors: const [
        Color(0xFFE040FB), // Neon Purple
        Color(0xFF7C4DFF), // Deep Violet
        Color(0xFF00E5FF), // Cyan Sparkle
        Color(0xFFFF4081), // Neon Pink
        Color(0xFFFFD700), // Gold Accent
        Color(0xFFE040FB), // Neon Purple
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 0.9, 1.0],
    );

    // 2. Outer Soft Blur Glow Paint
    final glowPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 2.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawCircle(center, drawRadius, glowPaint);

    // 3. Crisp Foreground Neon Ring Arc (Segmented for rotation visibility)
    final mainPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const int segmentCount = 3;
    const double sweepAngle = (2 * math.pi / segmentCount) * 0.72;
    const double gapAngle = (2 * math.pi / segmentCount) * 0.28;

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = rotationAngle + i * (sweepAngle + gapAngle);
      canvas.drawArc(rect, startAngle, sweepAngle, false, mainPaint);
    }

    // 4. Bright highlight dots at segment leading edges
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    for (int i = 0; i < segmentCount; i++) {
      final tipAngle = rotationAngle + i * (sweepAngle + gapAngle) + sweepAngle;
      final tipX = center.dx + drawRadius * math.cos(tipAngle);
      final tipY = center.dy + drawRadius * math.sin(tipAngle);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.8, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ReactionRingPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
