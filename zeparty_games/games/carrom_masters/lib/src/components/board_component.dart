import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/geometry.dart' as g;

/// Procedurally drawn carrom playfield with the walnut frame image laid over
/// it. Geometry is exact (board units * [unit]) so pieces and hit areas line
/// up with the server; the wood texture and frame are decorative layers with
/// procedural fallbacks.
class BoardComponent extends PositionComponent {
  BoardComponent({required this.unit, required this.border, this.wood, this.frame}) : super(size: Vector2.all(g.boardSize * unit + border * 2), priority: 0);

  /// Pixels per board unit.
  final double unit;
  /// Width of the frame border around the playfield in pixels.
  final double border;
  final ui.Image? wood;
  final ui.Image? frame;

  ui.Picture? _picture;
  double _sheen = 0;

  Offset toWorld(g.BPoint p) => Offset(border + p.x * unit, border + p.y * unit);
  g.BPoint toFrameUnits(Vector2 world) => g.BPoint((world.x - border) / unit, (world.y - border) / unit);

  @override
  Future<void> onLoad() async {
    _picture = _record();
  }

  @override
  void update(double dt) {
    _sheen = (_sheen + dt * 0.12) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    final p = _picture;
    if (p != null) canvas.drawPicture(p);
    // Slow specular drift so the lacquer feels lit by the club chandeliers.
    final w = size.x;
    final x = (_sheen * 1.6 - 0.3) * w;
    final rect = Rect.fromLTWH(border, border, g.boardSize * unit, g.boardSize * unit);
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(Offset(x - w * 0.25, 0), Offset(x + w * 0.25, w), [const Color(0x00FFFFFF), const Color(0x12FFFFFF), const Color(0x00FFFFFF)], [0, 0.5, 1])
        ..blendMode = BlendMode.plus,
    );
    canvas.restore();
    final f = frame;
    if (f != null) {
      canvas.drawImageRect(f, Rect.fromLTWH(0, 0, f.width.toDouble(), f.height.toDouble()), Rect.fromLTWH(0, 0, size.x, size.y), Paint()..filterQuality = FilterQuality.medium);
    }
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final play = Rect.fromLTWH(border, border, g.boardSize * unit, g.boardSize * unit);
    final bleed = play.inflate(border * 0.6);

    if (frame == null) _drawProceduralFrame(c);

    // Playfield wood: tiled texture or painted grain. Bleeds under the frame.
    c.save();
    c.clipRect(frame == null ? play : bleed);
    final w = wood;
    if (w != null) {
      final scale = (unit * 24) / w.width; // one tile ~ 24 board units
      final m = Matrix4.identity()
        ..translateByDouble(play.left, play.top, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      c.drawRect(bleed, Paint()..shader = ui.ImageShader(w, TileMode.repeated, TileMode.repeated, m.storage));
      c.drawRect(bleed, Paint()..color = const Color(0x14C9A227)..blendMode = BlendMode.overlay);
    } else {
      c.drawRect(bleed, Paint()..shader = ui.Gradient.linear(bleed.topLeft, bleed.bottomRight, [const Color(0xFFE7C9A0), const Color(0xFFD9B585), const Color(0xFFE2C094)], [0, 0.5, 1]));
      final grain = Paint()..strokeWidth = unit * 0.08;
      final rnd = math.Random(7);
      for (var i = 0; i < 90; i++) {
        final y = bleed.top + rnd.nextDouble() * bleed.height;
        final a = 0.05 + rnd.nextDouble() * 0.08;
        grain.color = const Color(0xFF8E5A2B).withValues(alpha: a);
        final path = Path()..moveTo(bleed.left, y);
        for (var x = bleed.left; x <= bleed.right; x += unit * 6) {
          path.lineTo(x, y + math.sin(x / (unit * 9) + i) * unit * 0.4);
        }
        c.drawPath(path, grain..style = PaintingStyle.stroke);
      }
    }
    // Directional lighting: soft highlight from the top left, vignette at the edges.
    c.drawRect(bleed, Paint()..shader = ui.Gradient.radial(play.topLeft + Offset(play.width * 0.25, play.height * 0.2), play.width * 1.1, [const Color(0x2EFFFFFF), const Color(0x00FFFFFF)]));
    c.drawRect(bleed, Paint()..shader = ui.Gradient.radial(play.center, play.width * 0.78, [const Color(0x00000000), const Color(0x00000000), const Color(0x33000000)], [0, 0.7, 1]));
    c.restore();

    _drawMarkings(c);
    _drawPockets(c);
    // Cushion inner edge: a crisp dark line plus an inner shadow.
    c.drawRect(play.deflate(unit * 0.1), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.25..color = const Color(0x9931190B));
    c.drawRect(play, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 1.2..color = const Color(0x22000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.8));
    return rec.endRecording();
  }

  void _drawProceduralFrame(Canvas c) {
    final outer = Rect.fromLTWH(0, 0, size.x, size.y);
    final rr = RRect.fromRectAndRadius(outer, Radius.circular(border * 0.35));
    c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(outer.topLeft, outer.bottomRight, [const Color(0xFF5A3218), const Color(0xFF3B1F0E), const Color(0xFF4E2B14)], [0, 0.5, 1]));
    final rnd = math.Random(3);
    for (var i = 0; i < 60; i++) {
      final y = rnd.nextDouble() * size.y;
      c.drawLine(Offset(0, y), Offset(size.x, y + rnd.nextDouble() * 20 - 10), Paint()..color = const Color(0xFF2A1407).withValues(alpha: 0.12 + rnd.nextDouble() * 0.1)..strokeWidth = 1 + rnd.nextDouble() * 2);
    }
    // Gold inlay line and bevel.
    c.drawRRect(RRect.fromRectAndRadius(outer.deflate(border * 0.42), Radius.circular(border * 0.1)), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.3..color = ZpColors.gold.withValues(alpha: 0.55));
    c.drawRRect(rr.deflate(unit * 0.3), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.6..color = const Color(0x55FFE0B0));
  }

  void _drawMarkings(Canvas c) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.28
      ..color = const Color(0xCC2B1B10);
    final red = Paint()..color = const Color(0xFFB4262E);
    final ink = Paint()..color = const Color(0xDD2B1B10);
    // Four baselines: two parallel lines with a circle at each end, one per edge.
    for (var edge = 0; edge < 4; edge++) {
      Offset w(double x, double y) => toWorld(g.toBoard(edge, g.BPoint(x, y)));
      final y1 = g.baselineY - 1.5;
      final y2 = g.baselineY + 1.5;
      c.drawLine(w(g.baselineXMin, y1), w(g.baselineXMax, y1), line);
      c.drawLine(w(g.baselineXMin, y2), w(g.baselineXMax, y2), line);
      for (final x in [g.baselineXMin, g.baselineXMax]) {
        final centre = w(x, g.baselineY);
        c.drawCircle(centre, unit * 2.1, Paint()..color = const Color(0xFFF0DCC0));
        c.drawCircle(centre, unit * 2.1, line);
        c.drawCircle(centre, unit * 1.0, red);
      }
      // Diagonal arrows from each corner circle towards the pocket.
      for (final x in [g.baselineXMin, g.baselineXMax]) {
        final dirX = x < 50 ? -1.0 : 1.0;
        final start = g.BPoint(x + dirX * 3.4, g.baselineY + 3.4);
        final end = g.BPoint(x + dirX * 8.6, g.baselineY + 8.6);
        final a = w(start.x, start.y);
        final b = w(end.x, end.y);
        c.drawLine(a, b, line);
        final d = (b - a) / (b - a).distance;
        final n = Offset(-d.dy, d.dx);
        final head = Path()
          ..moveTo(b.dx, b.dy)
          ..lineTo(b.dx - d.dx * unit * 1.6 + n.dx * unit * 0.9, b.dy - d.dy * unit * 1.6 + n.dy * unit * 0.9)
          ..lineTo(b.dx - d.dx * unit * 1.6 - n.dx * unit * 0.9, b.dy - d.dy * unit * 1.6 - n.dy * unit * 0.9)
          ..close();
        c.drawPath(head, ink);
        c.drawCircle(a, unit * 0.9, line);
      }
    }
    // Centre circle with decorative ring.
    final centre = toWorld(g.boardCenter);
    c.drawCircle(centre, unit * 10.6, line);
    c.drawCircle(centre, unit * 9.6, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.14..color = ZpColors.goldDeep.withValues(alpha: 0.7));
    for (var i = 0; i < 24; i++) {
      final a = (math.pi * 2 / 24) * i;
      final r1 = unit * 9.8;
      final r2 = unit * 10.4;
      final p1 = centre + Offset(math.cos(a), math.sin(a)) * r1;
      final p2 = centre + Offset(math.cos(a), math.sin(a)) * r2;
      c.drawLine(p1, p2, Paint()..strokeWidth = unit * 0.12..color = ZpColors.goldDeep.withValues(alpha: 0.65));
    }
    c.drawCircle(centre, unit * 1.6, red..style = PaintingStyle.fill);
    c.drawCircle(centre, unit * 1.6, line);
    // Petal motif inside the centre ring.
    final petal = Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.12..color = const Color(0x66B4262E);
    for (var i = 0; i < 8; i++) {
      final a = (math.pi / 4) * i;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..quadraticBezierTo(centre.dx + math.cos(a - 0.35) * unit * 6, centre.dy + math.sin(a - 0.35) * unit * 6, centre.dx + math.cos(a) * unit * 8.6, centre.dy + math.sin(a) * unit * 8.6)
        ..quadraticBezierTo(centre.dx + math.cos(a + 0.35) * unit * 6, centre.dy + math.sin(a + 0.35) * unit * 6, centre.dx, centre.dy);
      c.drawPath(path, petal);
    }
  }

  void _drawPockets(Canvas c) {
    for (final p in g.pockets) {
      final centre = toWorld(p);
      final r = g.pocketRadius * unit;
      c.drawCircle(centre, r * 1.25, Paint()..color = const Color(0x55000000)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.9));
      c.drawCircle(centre, r, Paint()..shader = ui.Gradient.radial(centre + Offset(-r * 0.2, -r * 0.2), r, [const Color(0xFF1A0E07), const Color(0xFF070402)]));
      c.drawCircle(centre, r, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.22..color = const Color(0xAA3E2A1A));
      // Net sheen.
      c.drawArc(Rect.fromCircle(center: centre, radius: r * 0.75), math.pi * 1.1, math.pi * 0.6, false, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.15..color = const Color(0x33FFFFFF));
    }
  }
}
