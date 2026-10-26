import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Floating aim reticle. Sits at [position] (world), draws a crosshair plus the
/// predicted scatter circles so players understand the throw model before
/// committing. [fatigue] (0..1) tints the ring as the sway grows.
class AimReticleComponent extends PositionComponent {
  AimReticleComponent({required this.boardRadius}) : super(anchor: Anchor.center, size: Vector2.all(10), priority: 50);

  final double boardRadius;

  /// Predicted 1-sigma scatter for a perfect release, in world units.
  double sigmaBest = 0;

  /// Predicted 1-sigma scatter for a poor release, in world units.
  double sigmaWorst = 0;
  double fatigue = 0;
  bool locked = false;
  bool visible = false;
  double _pulse = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!visible) return;
    final c = Offset.zero;
    final pulse = 0.5 + 0.5 * math.sin(_pulse * 5);
    final ringColor = Color.lerp(ZpColors.goldLight, ZpColors.danger, fatigue)!;
    // Worst-case spread (soft) and best-case spread (crisp): ~86% of darts land within 2 sigma.
    if (sigmaWorst > 0) {
      canvas.drawCircle(c, sigmaWorst * 2, Paint()..color = ringColor.withValues(alpha: 0.08));
      canvas.drawCircle(c, sigmaWorst * 2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = ringColor.withValues(alpha: 0.35));
    }
    if (sigmaBest > 0) {
      canvas.drawCircle(c, sigmaBest * 2, Paint()..color = ringColor.withValues(alpha: 0.12));
      canvas.drawCircle(c, sigmaBest * 2, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = ringColor.withValues(alpha: locked ? 1 : 0.6 + 0.4 * pulse));
    }
    // Crosshair.
    final cross = Paint()..color = ringColor..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    final arm = boardRadius * 0.06;
    final gap = boardRadius * 0.018;
    canvas.drawLine(Offset(-arm, 0), Offset(-gap, 0), cross);
    canvas.drawLine(Offset(gap, 0), Offset(arm, 0), cross);
    canvas.drawLine(Offset(0, -arm), Offset(0, -gap), cross);
    canvas.drawLine(Offset(0, gap), Offset(0, arm), cross);
    canvas.drawCircle(c, boardRadius * 0.012, Paint()..color = Colors.white);
    canvas.drawCircle(c, boardRadius * 0.012, Paint()..color = ringColor.withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
}
