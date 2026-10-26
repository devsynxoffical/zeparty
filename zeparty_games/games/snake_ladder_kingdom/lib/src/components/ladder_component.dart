import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/layouts.dart';
import 'board_geometry.dart';

/// Golden ladder stretched between its two squares. Uses `boards/ladder.webp`
/// (vertical, transparent) rotated and scaled along the line when available,
/// otherwise draws rails and rungs procedurally in the same gold.
class LadderComponent extends PositionComponent {
  LadderComponent({required this.geo, required this.link, required this.image}) : super(priority: 2) {
    final (a, b) = geo.ladderLine(link);
    bottom = a;
    top = b;
    final d = top - bottom;
    length = d.length;
    // Local "up" (0,-1) rotated by angle must equal the bottom->top direction.
    angle = math.atan2(d.x, -d.y);
    anchor = Anchor.bottomCenter;
    position = bottom;
    size = Vector2(geo.cell * 0.46, length);
  }

  final BoardGeometry geo;
  final Link link;
  final ui.Image? image;
  late final Vector2 bottom;
  late final Vector2 top;
  late final double length;
  ui.Picture? _picture;
  double _shine = 0;

  @override
  Future<void> onLoad() async {
    if (image == null) _picture = _recordProcedural();
  }

  @override
  void update(double dt) {
    _shine = (_shine + dt * 0.4) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    // Contact shadow along the ladder.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.02, w * 0.92, h), Radius.circular(w * 0.1)), Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12));
    final img = image;
    if (img != null) {
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(0, 0, w, h), Paint()..filterQuality = FilterQuality.medium);
    } else {
      final p = _picture;
      if (p != null) canvas.drawPicture(p);
    }
    // Travelling glint so the gold feels lit.
    final y = _shine * h;
    canvas.drawRect(Rect.fromLTWH(0, y - h * 0.06, w, h * 0.12), Paint()..shader = ui.Gradient.linear(Offset(0, y - h * 0.06), Offset(0, y + h * 0.06), [Colors.transparent, Colors.white.withValues(alpha: 0.35), Colors.transparent], [0, 0.5, 1])..blendMode = BlendMode.plus);
  }

  ui.Picture _recordProcedural() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = size.x;
    final h = size.y;
    final railW = w * 0.16;
    final gold = Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [ZpColors.goldDeep, ZpColors.goldLight, ZpColors.gold, ZpColors.goldDeep], [0, 0.35, 0.65, 1]);
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = w * 0.025..color = const Color(0xFF4A3608);
    for (final x in [railW / 2 + w * 0.04, w - railW / 2 - w * 0.04]) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, h / 2), width: railW, height: h), Radius.circular(railW / 2));
      c.drawRRect(r, gold);
      c.drawRRect(r, edge);
      // Finials at both ends.
      c.drawCircle(Offset(x, 0), railW * 0.75, Paint()..color = ZpColors.goldLight);
      c.drawCircle(Offset(x, 0), railW * 0.75, edge);
      c.drawCircle(Offset(x, h), railW * 0.75, Paint()..color = ZpColors.goldLight);
      c.drawCircle(Offset(x, h), railW * 0.75, edge);
    }
    final rungs = math.max(3, (h / (geo.cell * 0.32)).round());
    final rungPaint = Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, railW * 0.6), [ZpColors.goldLight, ZpColors.goldDeep]);
    for (var i = 1; i < rungs; i++) {
      final y = h * i / rungs;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(railW * 0.9, y - railW * 0.28, w - railW * 1.8, railW * 0.56), Radius.circular(railW * 0.28));
      c.drawRRect(r.shift(Offset(0, railW * 0.15)), Paint()..color = Colors.black.withValues(alpha: 0.25));
      c.drawRRect(r, rungPaint);
      c.drawRRect(r, edge);
    }
    return rec.endRecording();
  }

  /// Point along the ladder, 0 = bottom, 1 = top.
  Vector2 pointAt(double t) => bottom + (top - bottom) * t;
}
