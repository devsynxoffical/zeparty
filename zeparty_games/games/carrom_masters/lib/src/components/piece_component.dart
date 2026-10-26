import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/carrom_state.dart';

/// What a piece looks like: coin colour or the striker.
enum PieceKind {
  white,
  black,
  queen,
  striker;

  static PieceKind fromCoin(CoinKind k) => switch (k) { CoinKind.white => PieceKind.white, CoinKind.black => PieceKind.black, CoinKind.queen => PieceKind.queen };
}

/// A coin or the striker. Sprite when available, otherwise a procedurally
/// shaded disc. Draws a soft contact shadow that grows and trails with speed
/// (set by the replayer), a specular highlight and, for the striker, a cosmetic
/// ring tint plus an invalid-placement tint.
class PieceComponent extends PositionComponent {
  PieceComponent({required this.id, required this.kind, required this.radius, this.sprite, this.ringTint})
      : super(size: Vector2.all(radius * 2), anchor: Anchor.center, priority: kind == PieceKind.striker ? 30 : 20);

  final String id;
  final PieceKind kind;
  /// Radius in world pixels.
  final double radius;
  final Sprite? sprite;
  /// Cosmetic ring colour for the striker (null = default ivory ring).
  final Color? ringTint;

  /// Current speed in world px/s (drives the shadow). Set by the replayer.
  double speed = 0;
  /// Direction of travel, for the trailing shadow.
  Vector2 velocityDir = Vector2(0, 0);
  bool visible = true;
  /// Red tint when a placement overlaps a coin.
  bool invalid = false;
  /// Pulsing ring when the piece can be dragged.
  bool interactive = false;
  double _pulse = 0;
  /// Visual scale used by the pocket animation (1 = normal).
  double visualScale = 1;

  @override
  void update(double dt) {
    _pulse = (_pulse + dt * 2.4) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    if (!visible || visualScale <= 0.01) return;
    final c = Offset(radius, radius);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(visualScale);
    canvas.translate(-c.dx, -c.dy);

    // Shadow: light comes from the top left; faster pieces lift and trail.
    final lift = (speed / 400).clamp(0.0, 1.0);
    final shadowOffset = Offset(radius * 0.22, radius * 0.28) + Offset(-velocityDir.x, -velocityDir.y) * (radius * 0.6 * lift);
    final shadowRadius = radius * (1.0 + 0.35 * lift);
    canvas.drawOval(
      Rect.fromCenter(center: c + shadowOffset, width: shadowRadius * 2.1, height: shadowRadius * 1.9),
      Paint()
        ..color = Color.fromRGBO(20, 10, 4, 0.38 + 0.2 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * (0.25 + 0.5 * lift)),
    );

    if (interactive) {
      final a = 0.35 + 0.25 * math.sin(_pulse);
      canvas.drawCircle(c, radius * 1.35, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.12..color = ZpColors.goldLight.withValues(alpha: a));
    }

    final s = sprite;
    if (s != null) {
      s.render(canvas, size: size, overridePaint: invalid ? (Paint()..colorFilter = const ColorFilter.mode(Color(0x99E24B5C), BlendMode.srcATop)) : null);
    } else {
      _drawProcedural(canvas, c);
    }

    // Specular highlight shared by every piece so sprites and fallbacks match.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-radius * 0.3, -radius * 0.35), width: radius * 0.9, height: radius * 0.5),
      Paint()..shader = ui.Gradient.radial(c + Offset(-radius * 0.3, -radius * 0.35), radius * 0.5, [const Color(0x66FFFFFF), const Color(0x00FFFFFF)]),
    );

    if (kind == PieceKind.striker) {
      final tint = ringTint;
      if (tint != null) {
        canvas.drawCircle(c, radius * 0.78, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.16..color = tint.withValues(alpha: 0.85));
        canvas.drawCircle(c, radius * 0.78, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.3..color = tint.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15));
      }
      if (invalid) canvas.drawCircle(c, radius, Paint()..color = const Color(0x66E24B5C));
    }
    canvas.restore();
  }

  void _drawProcedural(Canvas canvas, Offset c) {
    final (base, edge, rim) = switch (kind) {
      PieceKind.white => (const Color(0xFFF4E6CC), const Color(0xFFC9B48E), const Color(0xFF8E6E12)),
      PieceKind.black => (const Color(0xFF2E2420), const Color(0xFF14100E), const Color(0xFFC9A227)),
      PieceKind.queen => (const Color(0xFFD1333B), const Color(0xFF7E141C), const Color(0xFFE8C96A)),
      PieceKind.striker => (const Color(0xFFFBF3E4), const Color(0xFFD8C7A5), const Color(0xFF8E6E12)),
    };
    canvas.drawCircle(c, radius, Paint()..shader = ui.Gradient.radial(c + Offset(-radius * 0.3, -radius * 0.3), radius * 1.3, [base, edge]));
    canvas.drawCircle(c, radius * 0.97, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.08..color = edge.withValues(alpha: 0.9));
    canvas.drawCircle(c, radius * 0.72, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.07..color = rim.withValues(alpha: 0.75));
    if (kind == PieceKind.striker) {
      canvas.drawCircle(c, radius * 0.5, Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.05..color = rim.withValues(alpha: 0.55));
      canvas.drawCircle(c, radius * 0.12, Paint()..color = rim.withValues(alpha: 0.6));
    } else {
      // Concentric lathe rings typical of turned wooden coins.
      for (var i = 1; i <= 3; i++) {
        canvas.drawCircle(c, radius * (0.2 + i * 0.16), Paint()..style = PaintingStyle.stroke..strokeWidth = radius * 0.03..color = edge.withValues(alpha: 0.35));
      }
    }
  }
}
