import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Scoring feedback text ("T20", "BULL", "BUST") that pops, drifts up and fades.
class ScorePopupComponent extends PositionComponent {
  ScorePopupComponent({required Vector2 at, required this.text, this.color = ZpColors.goldLight, this.fontSize = 56, this.lifespan = 1.1}) : super(position: at, anchor: Anchor.center, priority: 80);

  final String text;
  final Color color;
  final double fontSize;
  final double lifespan;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= dt * 40;
    if (_t >= lifespan) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final k = (_t / lifespan).clamp(0.0, 1.0);
    final pop = k < 0.15 ? Curves.easeOutBack.transform(k / 0.15) : 1.0;
    final alpha = k > 0.6 ? (1 - (k - 0.6) / 0.4) : 1.0;
    final s = math.max(0.01, pop);
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color.withValues(alpha: alpha), fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: 2, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.7 * alpha), blurRadius: 12, offset: const Offset(0, 3))])),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.scale(s);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}
