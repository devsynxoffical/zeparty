import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/board.dart';

/// Board skin: textures and tints for one cosmetic board.
class BoardSkin {
  const BoardSkin({required this.id, required this.surface, required this.trim, required this.crest, required this.star, required this.trackTint, required this.lineColor, required this.baseAlpha, required this.glowColor});
  final String id;
  final ui.Image surface;
  final ui.Image trim;
  final ui.Image crest;
  final ui.Image star;
  final Color trackTint;
  final Color lineColor;
  final double baseAlpha;
  final Color glowColor;
}

/// Procedurally composed board drawn once into a Picture and replayed each frame.
/// Geometry comes from model/board.dart so every cell lines up with server positions.
class BoardComponent extends PositionComponent {
  BoardComponent({required this.skin, required this.cell, required this.activeColors, required this.safeMode}) : super(size: Vector2.all(cell * 15), priority: 0);

  final BoardSkin skin;
  final double cell;
  final List<LudoColor> activeColors;
  final String safeMode;

  ui.Picture? _picture;
  double _shimmer = 0;

  static Color colorOf(LudoColor c) => switch (c) {
        LudoColor.red => ZpColors.ruby,
        LudoColor.green => ZpColors.emerald,
        LudoColor.yellow => ZpColors.amber,
        LudoColor.blue => ZpColors.sapphire,
      };

  @override
  Future<void> onLoad() async {
    _picture = _record();
  }

  @override
  void update(double dt) {
    _shimmer = (_shimmer + dt * 0.25) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    final p = _picture;
    if (p != null) canvas.drawPicture(p);
    // Soft moving specular sweep across the board so the marble feels lit.
    final w = size.x;
    final x = (_shimmer * 2 - 0.5) * w;
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(x - w * 0.25, 0), Offset(x + w * 0.25, w), [Colors.transparent, Colors.white.withValues(alpha: 0.05), Colors.transparent], [0.0, 0.5, 1.0])
      ..blendMode = BlendMode.plus;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, w), paint);
  }

  Rect _cellRect(double row, double col, [double inset = 0]) => Rect.fromLTWH(col * cell + inset, row * cell + inset, cell - inset * 2, cell - inset * 2);

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = size.x;
    final full = Rect.fromLTWH(0, 0, w, w);

    // Drop shadow under the floating board.
    c.drawRRect(RRect.fromRectAndRadius(full.inflate(cell * 0.35).shift(Offset(0, cell * 0.35)), Radius.circular(cell * 0.9)), Paint()..color = Colors.black.withValues(alpha: 0.55)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.6));

    // Gold outer frame.
    final frameOuter = RRect.fromRectAndRadius(full.inflate(cell * 0.32), Radius.circular(cell * 0.7));
    c.drawRRect(frameOuter, Paint()..shader = ui.ImageShader(skin.trim, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scaleByDouble(cell * 3 / skin.trim.width, cell * 3 / skin.trim.width, 1, 1)).storage));
    c.drawRRect(frameOuter, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.06..color = ZpColors.goldLight.withValues(alpha: 0.9));
    c.drawRRect(frameOuter.deflate(cell * 0.12), Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.03..color = ZpColors.goldDeep);

    // Surface.
    final surfaceRR = RRect.fromRectAndRadius(full.inflate(cell * 0.12), Radius.circular(cell * 0.45));
    c.save();
    c.clipRRect(surfaceRR);
    c.drawRect(full.inflate(cell), Paint()..shader = ui.ImageShader(skin.surface, TileMode.mirror, TileMode.mirror, (Matrix4.identity()..scaleByDouble(cell * 5 / skin.surface.width, cell * 5 / skin.surface.width, 1, 1)).storage));
    // Vignette so edges recede.
    c.drawRect(full.inflate(cell), Paint()..shader = ui.Gradient.radial(full.center, w * 0.78, [Colors.transparent, Colors.black.withValues(alpha: 0.35)]));
    c.restore();

    // Base quadrants.
    for (final color in LudoColor.values) {
      final o = baseOrigin[color]!;
      final rect = Rect.fromLTWH(o.col * cell, o.row * cell, cell * 6, cell * 6);
      final active = activeColors.contains(color);
      final tint = colorOf(color);
      final rr = RRect.fromRectAndRadius(rect.deflate(cell * 0.18), Radius.circular(cell * 0.4));
      c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [tint.withValues(alpha: active ? skin.baseAlpha : skin.baseAlpha * 0.35), tint.withValues(alpha: active ? skin.baseAlpha * 0.65 : skin.baseAlpha * 0.2)]));
      c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.05..color = ZpColors.gold.withValues(alpha: active ? 0.9 : 0.35));
      // Inner plate
      final inner = RRect.fromRectAndRadius(rect.deflate(cell * 0.95), Radius.circular(cell * 0.3));
      c.drawRRect(inner, Paint()..shader = ui.ImageShader(skin.surface, TileMode.mirror, TileMode.mirror, (Matrix4.identity()..scaleByDouble(cell * 5 / skin.surface.width, cell * 5 / skin.surface.width, 1, 1)).storage));
      c.drawRRect(inner, Paint()..color = Colors.black.withValues(alpha: 0.12));
      c.drawRRect(inner, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.035..color = ZpColors.gold.withValues(alpha: active ? 0.7 : 0.3));
      // Base slots
      for (final slot in baseCells[color]!) {
        final center = Offset((slot.col + 0.5) * cell, (slot.row + 0.5) * cell);
        c.drawCircle(center, cell * 0.44, Paint()..color = tint.withValues(alpha: active ? 0.75 : 0.25));
        c.drawCircle(center, cell * 0.44, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.04..color = ZpColors.goldLight.withValues(alpha: active ? 0.9 : 0.4));
        c.drawCircle(center.translate(-cell * 0.12, -cell * 0.14), cell * 0.16, Paint()..color = Colors.white.withValues(alpha: 0.12));
      }
    }

    // Track cells.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, cell * 0.025)
      ..color = skin.lineColor;
    for (var i = 0; i < trackCells.length; i++) {
      final t = trackCells[i];
      final r = _cellRect(t.row, t.col, cell * 0.04);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.14));
      LudoColor? owner;
      for (final e in startIndex.entries) {
        if (e.value == i) owner = e.key;
      }
      if (owner != null) {
        c.drawRRect(rr, Paint()..color = colorOf(owner).withValues(alpha: 0.85));
        c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomLeft, [Colors.white.withValues(alpha: 0.22), Colors.transparent]));
      } else {
        c.drawRRect(rr, Paint()..color = skin.trackTint);
      }
      c.drawRRect(rr, line);
      if (isSafeSquare(i, safeMode)) {
        final s = cell * 0.62;
        c.drawImageRect(skin.star, Rect.fromLTWH(0, 0, skin.star.width.toDouble(), skin.star.height.toDouble()), Rect.fromCenter(center: r.center, width: s, height: s), Paint()..filterQuality = FilterQuality.medium..color = Colors.white.withValues(alpha: owner != null ? 0.9 : 1));
      }
    }

    // Home columns.
    for (final color in LudoColor.values) {
      final tint = colorOf(color);
      for (final hc in homeColumnCells[color]!) {
        final r = _cellRect(hc.row, hc.col, cell * 0.04);
        final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.14));
        c.drawRRect(rr, Paint()..color = tint.withValues(alpha: activeColors.contains(color) ? 0.8 : 0.3));
        c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomLeft, [Colors.white.withValues(alpha: 0.18), Colors.transparent]));
        c.drawRRect(rr, line);
      }
    }

    // Centre home: four triangles pointing to the centre + crest.
    final center = Offset(7.5 * cell, 7.5 * cell);
    final tri = {
      LudoColor.red: [Offset(6 * cell, 6 * cell), Offset(6 * cell, 9 * cell)],
      LudoColor.green: [Offset(6 * cell, 6 * cell), Offset(9 * cell, 6 * cell)],
      LudoColor.yellow: [Offset(9 * cell, 6 * cell), Offset(9 * cell, 9 * cell)],
      LudoColor.blue: [Offset(6 * cell, 9 * cell), Offset(9 * cell, 9 * cell)],
    };
    for (final e in tri.entries) {
      final path = Path()
        ..moveTo(e.value[0].dx, e.value[0].dy)
        ..lineTo(e.value[1].dx, e.value[1].dy)
        ..lineTo(center.dx, center.dy)
        ..close();
      c.drawPath(path, Paint()..color = colorOf(e.key).withValues(alpha: activeColors.contains(e.key) ? 0.9 : 0.35));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.03..color = ZpColors.gold.withValues(alpha: 0.8));
    }
    c.drawCircle(center, cell * 1.05, Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.2));
    final crestSize = cell * 2.1;
    c.drawImageRect(skin.crest, Rect.fromLTWH(0, 0, skin.crest.width.toDouble(), skin.crest.height.toDouble()), Rect.fromCenter(center: center, width: crestSize, height: crestSize), Paint()..filterQuality = FilterQuality.medium);

    // Thin gold inner border around the full playing area.
    c.drawRRect(surfaceRR, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.04..color = ZpColors.gold.withValues(alpha: 0.7));
    return rec.endRecording();
  }

  /// World position of a cell centre.
  Vector2 cellCenter(Cell cellRef) => Vector2((cellRef.col + 0.5) * cell, (cellRef.row + 0.5) * cell);
}
