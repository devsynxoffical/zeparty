import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/scoring.dart';

/// Calibration of the generated dartboard image (`boards/dartboard.webp`).
///
/// The image is square and includes the black number ring, so the playable board
/// (outer edge of the double ring) is only part of the half-size. Measured on the
/// shipped 1024 px asset: the double ring spans x 133..880 and y 123..883, giving a
/// playable radius of about 377 px, which is 0.736 of the 512 px half-size, with the
/// board centre about 5 px left and 9 px above the image centre. If the art is
/// regenerated, re-measure and update these two constants; the scoring geometry is
/// drawn by code and does not move.
const double kBoardImagePlayRadius = 0.736;

/// Board centre offset inside the image as a fraction of the half-size (x right, y down).
const Offset kBoardImageCenterOffset = Offset(-0.010, -0.018);

/// Renders the dartboard: the image (when bundled) scaled so its double ring outer
/// edge sits exactly on [radius], or a complete procedural regulation board.
/// Converts between board units and world coordinates for every other component.
class BoardComponent extends PositionComponent {
  BoardComponent({required Vector2 worldSize, required this.boardCenter, required this.radius, this.image}) : super(size: worldSize, priority: 10);

  /// Board centre in world units.
  final Vector2 boardCenter;
  final double radius;
  final ui.Image? image;

  Vector2 toWorld(double bx, double by) => Vector2(boardCenter.x + bx * radius, boardCenter.y + by * radius);
  Vector2 toBoard(Vector2 world) => Vector2((world.x - boardCenter.x) / radius, (world.y - boardCenter.y) / radius);

  static const Color _cream = Color(0xFFE9DCC0);
  static const Color _black = Color(0xFF17151A);
  static const Color _red = Color(0xFFC8252F);
  static const Color _green = Color(0xFF1E7B4A);
  static const Color _wire = Color(0xFFB9BCC2);

  @override
  void render(Canvas canvas) {
    final c = boardCenter.toOffset();
    // Drop shadow and halo so the board reads as a physical object on the wall.
    canvas.drawCircle(c + const Offset(0, 14), radius * 1.3, Paint()..color = Colors.black.withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26));
    canvas.drawCircle(c, radius * 1.34, Paint()..shader = RadialGradient(colors: [ZpColors.gold.withValues(alpha: 0.18), Colors.transparent], stops: const [0.72, 1]).createShader(Rect.fromCircle(center: c, radius: radius * 1.34)));

    final img = image;
    if (img != null) {
      final half = radius / kBoardImagePlayRadius;
      final boardCenterInImage = Offset(half * (1 + kBoardImageCenterOffset.dx), half * (1 + kBoardImageCenterOffset.dy));
      final topLeft = c - boardCenterInImage;
      final dst = Rect.fromLTWH(topLeft.dx, topLeft.dy, half * 2, half * 2);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);
    } else {
      _renderProcedural(canvas, c);
    }
    // Warm spotlight falloff over the whole board, subtle.
    canvas.drawCircle(c, radius * 1.3, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent, Colors.black.withValues(alpha: 0.18)], stops: const [0, 0.55, 1]).createShader(Rect.fromCircle(center: c, radius: radius * 1.3)));
  }

  void _renderProcedural(Canvas canvas, Offset c) {
    final r = radius;
    // Number ring: deep black with a brushed highlight.
    canvas.drawCircle(c, r * 1.3, Paint()..shader = const RadialGradient(colors: [Color(0xFF2A2730), Color(0xFF0E0D11)], stops: [0.78, 1]).createShader(Rect.fromCircle(center: c, radius: r * 1.3)));
    canvas.drawCircle(c, r * 1.3, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.025..color = ZpColors.goldDeep.withValues(alpha: 0.8));
    canvas.drawCircle(c, r * 1.3 - r * 0.03, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.006..color = ZpColors.goldLight.withValues(alpha: 0.5));

    final step = BoardGeometry.segmentDegrees * math.pi / 180;
    for (var i = 0; i < kSegments.length; i++) {
      final start = -math.pi / 2 + i * step - step / 2;
      final even = i.isEven;
      _band(canvas, c, BoardGeometry.outerBull * r, BoardGeometry.trebleInner * r, start, step, even ? _black : _cream);
      _band(canvas, c, BoardGeometry.trebleInner * r, BoardGeometry.trebleOuter * r, start, step, even ? _red : _green);
      _band(canvas, c, BoardGeometry.trebleOuter * r, BoardGeometry.doubleInner * r, start, step, even ? _black : _cream);
      _band(canvas, c, BoardGeometry.doubleInner * r, BoardGeometry.doubleOuter * r, start, step, even ? _red : _green);
    }
    canvas.drawCircle(c, BoardGeometry.outerBull * r, Paint()..color = _green);
    canvas.drawCircle(c, BoardGeometry.innerBull * r, Paint()..color = _red);

    // Wires.
    final wire = Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.006..color = _wire;
    for (final ring in [BoardGeometry.innerBull, BoardGeometry.outerBull, BoardGeometry.trebleInner, BoardGeometry.trebleOuter, BoardGeometry.doubleInner, BoardGeometry.doubleOuter]) {
      canvas.drawCircle(c, ring * r, wire);
    }
    for (var i = 0; i < kSegments.length; i++) {
      final a = -math.pi / 2 + i * step - step / 2;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (BoardGeometry.outerBull * r), c + Offset(math.cos(a), math.sin(a)) * r, wire);
    }

    // Numbers.
    for (var i = 0; i < kSegments.length; i++) {
      final a = -math.pi / 2 + i * step;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r * 1.15);
      final tp = TextPainter(
        text: TextSpan(text: '${kSegments[i]}', style: TextStyle(color: _cream, fontSize: r * 0.13, fontWeight: FontWeight.w600, fontFamily: 'serif')),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  void _band(Canvas canvas, Offset c, double inner, double outer, double start, double sweep, Color color) {
    final path = Path()
      ..arcTo(Rect.fromCircle(center: c, radius: outer), start, sweep, true)
      ..arcTo(Rect.fromCircle(center: c, radius: inner), start + sweep, -sweep, false)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }
}
