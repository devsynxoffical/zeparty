import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'card_painter.dart';
import 'layout.dart';
import 'pile_component.dart';

/// An opponent's hand: a fan of face-down mini cards (capped visually) with the
/// exact count, glowing on their turn, red-ringed when catchable and gold-ringed
/// after declaring. Cards never reveal identity because the server never sends it.
class OpponentFanComponent extends PositionComponent {
  OpponentFanComponent({required this.seat, required this.art, required Vector2 position}) : super(position: position, anchor: Anchor.center, size: Vector2(260, 140), priority: 25);

  final int seat;
  final CardArt art;
  int count = 0;
  bool active = false;
  bool catchable = false;
  bool declared = false;
  bool forfeited = false;
  double _pulse = 0;
  double _sheen = 0;
  /// Brief flash when cards arrive or leave.
  double _flash = 0;

  static const double miniScale = 0.46;

  /// World position where the k-th card of the fan sits (for fly animations).
  Vector2 cardSlot(int k) {
    final n = math.max(1, math.min(count, 9));
    final i = k.clamp(0, n - 1);
    final spread = math.min(26.0, 150 / n);
    final x = (i - (n - 1) / 2) * spread;
    return position + Vector2(x, 0);
  }

  void flash() => _flash = 1;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 2.4;
    _sheen = (_sheen + dt * 0.08) % 1;
    _flash = math.max(0, _flash - dt * 2);
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final shown = math.min(count, 9);
    final spread = shown <= 1 ? 0.0 : math.min(26.0, 150 / shown);
    final w = ArenaLayout.cardW * miniScale;
    final h = ArenaLayout.cardH * miniScale;
    if (active) {
      canvas.drawOval(Rect.fromCenter(center: c, width: size.x * 0.95, height: size.y * 1.1), Paint()..color = ZpColors.goldLight.withValues(alpha: 0.18 + 0.1 * math.sin(_pulse))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
    }
    if (catchable) {
      canvas.drawOval(Rect.fromCenter(center: c, width: size.x * 0.9, height: size.y), Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = ZpColors.danger.withValues(alpha: 0.6 + 0.4 * math.sin(_pulse * 1.5)));
    }
    for (var i = 0; i < shown; i++) {
      final x = c.dx + (i - (shown - 1) / 2) * spread;
      final tilt = (i - (shown - 1) / 2) * 0.07;
      canvas.save();
      canvas.translate(x, c.dy + tilt.abs() * 40);
      canvas.rotate(tilt);
      final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      CardPainter.paint(canvas, rect, faceUp: false, sheen: _sheen + i * 0.05, art: art, dim: forfeited ? 0.7 : 0, glow: _flash > 0 ? Colors.white : null, glowStrength: _flash);
      canvas.restore();
    }
    if (count == 0 && !forfeited) {
      drawLabel(canvas, 'OUT', c, 22, ZpColors.goldLight);
    }
    // Count badge (or final-card marker).
    final badge = Offset(c.dx, c.dy + h * 0.5 + 24);
    final color = declared ? ZpColors.goldLight : (count == 1 ? ZpColors.danger : ZpColors.obsidian.withValues(alpha: 0.8));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: badge, width: count == 1 ? 120 : 60, height: 32), const Radius.circular(16)), Paint()..color = color);
    drawLabel(canvas, forfeited ? 'LEFT' : (count == 1 ? (declared ? 'LAST CARD' : 'CATCH?') : '$count'), badge, 17, declared ? ZpColors.obsidian : ZpColors.ivory);
  }
}
