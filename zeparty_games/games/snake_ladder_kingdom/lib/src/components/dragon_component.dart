import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../model/layouts.dart';
import 'board_geometry.dart';

/// A friendly dragon standing in for the snake. The body is a cubic Bezier
/// from the head square (top) to the tail square (bottom), drawn with Canvas as
/// a tapered ribbon with a gradient scale pattern. The head and tail use
/// `dragon_head.webp` / `dragon_tail.webp` when available and otherwise a
/// procedural head with horns and eyes and a procedural arrow tail.
class DragonComponent extends PositionComponent {
  DragonComponent({required this.geo, required this.link, required this.headImage, required this.tailImage, required this.index}) : super(priority: 3) {
    curve = geo.snakeCurve(link);
  }

  final BoardGeometry geo;
  final Link link;
  final ui.Image? headImage;
  final ui.Image? tailImage;
  final int index;
  late final CubicBezier curve;
  ui.Picture? _body;
  double _time = 0;

  static const _palettes = [
    [Color(0xFF2E8B57), Color(0xFF7FD8A0), Color(0xFF145A32)],
    [Color(0xFF7B3FA0), Color(0xFFC79BE8), Color(0xFF3E1C57)],
    [Color(0xFF1F6FB2), Color(0xFF8FD0FF), Color(0xFF0E3A63)],
    [Color(0xFFC0392B), Color(0xFFFFA08A), Color(0xFF6E1C13)],
    [Color(0xFFD68910), Color(0xFFFFE08A), Color(0xFF7A4B04)],
  ];

  List<Color> get palette => _palettes[index % _palettes.length];

  @override
  Future<void> onLoad() async {
    _body = _recordBody();
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final b = _body;
    if (b != null) canvas.drawPicture(b);
    _renderTail(canvas);
    _renderHead(canvas);
  }

  double _widthAt(double t) => geo.cell * (0.30 - 0.18 * t);

  ui.Picture _recordBody() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    const samples = 48;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      final p = curve.pointAt(t);
      final tan = curve.tangentAt(t);
      final n = Vector2(-tan.y, tan.x);
      final w = _widthAt(t) / 2;
      left.add((p + n * w).toOffset());
      right.add((p - n * w).toOffset());
    }
    final ribbon = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      ribbon.lineTo(o.dx, o.dy);
    }
    for (final o in right.reversed) {
      ribbon.lineTo(o.dx, o.dy);
    }
    ribbon.close();

    final p0 = curve.p0.toOffset();
    final p3 = curve.p3.toOffset();
    // Shadow.
    c.drawPath(ribbon.shift(Offset(geo.cell * 0.05, geo.cell * 0.09)), Paint()..color = Colors.black.withValues(alpha: 0.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, geo.cell * 0.08));
    // Body gradient along the curve.
    c.drawPath(ribbon, Paint()..shader = ui.Gradient.linear(p0, p3, [palette[0], palette[2]]));
    // Belly highlight along the left edge.
    final belly = Path()..moveTo(left.first.dx, left.first.dy);
    for (final o in left.skip(1)) {
      belly.lineTo(o.dx, o.dy);
    }
    c.drawPath(belly, Paint()..style = PaintingStyle.stroke..strokeWidth = geo.cell * 0.06..strokeCap = StrokeCap.round..color = palette[1].withValues(alpha: 0.55));
    // Scales: overlapping arcs placed along the spine.
    final scale = Paint()..style = PaintingStyle.stroke..strokeWidth = geo.cell * 0.018..color = palette[2].withValues(alpha: 0.55);
    final scaleLight = Paint()..style = PaintingStyle.stroke..strokeWidth = geo.cell * 0.012..color = palette[1].withValues(alpha: 0.45);
    final len = curve.length();
    final count = (len / (geo.cell * 0.13)).round();
    for (var i = 0; i < count; i++) {
      final t = i / count;
      final p = curve.pointAt(t);
      final ang = curve.angleAt(t);
      final w = _widthAt(t);
      final rows = i.isEven ? [-0.25, 0.25] : [-0.4, 0.0, 0.4];
      for (final off in rows) {
        final n = Vector2(-math.sin(ang), math.cos(ang));
        final center = (p + n * (w * off)).toOffset();
        final r = w * 0.2;
        c.drawArc(Rect.fromCircle(center: center, radius: r), ang + math.pi * 0.15, math.pi * 0.7, false, scale);
        c.drawArc(Rect.fromCircle(center: center.translate(0, -r * 0.15), radius: r * 0.8), ang + math.pi * 0.25, math.pi * 0.5, false, scaleLight);
      }
    }
    // Dorsal fins along the back edge.
    final fin = Paint()..color = palette[2];
    for (var i = 1; i < count; i += 3) {
      final t = i / count;
      if (t > 0.85) break;
      final p = curve.pointAt(t);
      final tan = curve.tangentAt(t);
      final n = Vector2(tan.y, -tan.x);
      final w = _widthAt(t) / 2;
      final base = p - n * w;
      final tri = Path()
        ..moveTo(base.x - tan.x * w * 0.5, base.y - tan.y * w * 0.5)
        ..lineTo(base.x - n.x * w * 0.9 - tan.x * w * 0.2, base.y - n.y * w * 0.9 - tan.y * w * 0.2)
        ..lineTo(base.x + tan.x * w * 0.5, base.y + tan.y * w * 0.5)
        ..close();
      c.drawPath(tri, fin);
    }
    return rec.endRecording();
  }

  void _renderHead(Canvas canvas) {
    final p = curve.pointAt(0);
    final ang = curve.angleAt(0);
    final cell = geo.cell;
    final bob = math.sin(_time * 1.6 + index) * cell * 0.015;
    canvas.save();
    canvas.translate(p.x, p.y + bob);
    final img = headImage;
    final headSize = cell * 0.78;
    if (img != null) {
      // Image faces down (toward the tail) by convention; rotate so its down vector follows the curve.
      canvas.rotate(ang - math.pi / 2);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset.zero, width: headSize, height: headSize), Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      return;
    }
    canvas.rotate(ang);
    // Procedural head: rounded snout pointing against the body direction (+x is body direction).
    final r = cell * 0.24;
    final head = Path()
      ..moveTo(r * 0.4, -r)
      ..quadraticBezierTo(-r * 1.6, -r * 0.9, -r * 1.7, 0)
      ..quadraticBezierTo(-r * 1.6, r * 0.9, r * 0.4, r)
      ..close();
    canvas.drawPath(head.shift(Offset(cell * 0.03, cell * 0.06)), Paint()..color = Colors.black.withValues(alpha: 0.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.05));
    canvas.drawPath(head, Paint()..shader = ui.Gradient.linear(Offset(0, -r), Offset(0, r), [palette[1], palette[0], palette[2]], [0, 0.45, 1]));
    canvas.drawPath(head, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.02..color = palette[2]);
    // Horns.
    for (final s in [-1.0, 1.0]) {
      final horn = Path()
        ..moveTo(r * 0.1, s * r * 0.6)
        ..quadraticBezierTo(r * 0.9, s * r * 1.5, r * 1.2, s * r * 1.1)
        ..quadraticBezierTo(r * 0.7, s * r * 1.0, r * 0.4, s * r * 0.3)
        ..close();
      canvas.drawPath(horn, Paint()..color = const Color(0xFFEADFC4));
      canvas.drawPath(horn, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.012..color = const Color(0xFF8A7757));
    }
    // Eyes with a friendly blink.
    final blink = (math.sin(_time * 2.1 + index * 1.7) > 0.96) ? 0.15 : 1.0;
    for (final s in [-1.0, 1.0]) {
      final e = Offset(-r * 0.5, s * r * 0.5);
      canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.42, height: r * 0.42 * blink), Paint()..color = Colors.white);
      canvas.drawOval(Rect.fromCenter(center: e.translate(-r * 0.05, 0), width: r * 0.22, height: r * 0.26 * blink), Paint()..color = const Color(0xFF1A1A1A));
      canvas.drawCircle(e.translate(-r * 0.1, -r * 0.08), r * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.9 * blink));
    }
    // Nostrils and a soft smile.
    canvas.drawCircle(Offset(-r * 1.35, -r * 0.25), r * 0.07, Paint()..color = palette[2]);
    canvas.drawCircle(Offset(-r * 1.35, r * 0.25), r * 0.07, Paint()..color = palette[2]);
    canvas.drawArc(Rect.fromCircle(center: Offset(-r * 1.0, 0), radius: r * 0.55), math.pi * 0.7, math.pi * 0.6, false, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.015..color = palette[2].withValues(alpha: 0.8));
    canvas.restore();
  }

  void _renderTail(Canvas canvas) {
    final p = curve.pointAt(1);
    final ang = curve.angleAt(1);
    final cell = geo.cell;
    final sway = math.sin(_time * 2.3 + index * 0.9) * 0.08;
    canvas.save();
    canvas.translate(p.x, p.y);
    final img = tailImage;
    if (img != null) {
      canvas.rotate(ang + math.pi / 2 + sway);
      final s = cell * 0.5;
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset(0, -s * 0.3), width: s, height: s), Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      return;
    }
    canvas.rotate(ang + sway);
    final r = cell * 0.14;
    final tip = Path()
      ..moveTo(-r * 0.4, -r * 0.5)
      ..lineTo(r * 1.9, 0)
      ..lineTo(-r * 0.4, r * 0.5)
      ..lineTo(r * 0.2, 0)
      ..close();
    canvas.drawPath(tip, Paint()..color = palette[2]);
    canvas.drawPath(tip, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.012..color = palette[1].withValues(alpha: 0.6));
    canvas.restore();
  }
}
