import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/pool_state.dart';

/// Table skin chosen from cosmetics: textures (optional) and a felt tint.
class TableSkin {
  const TableSkin({required this.id, required this.felt, required this.railWood, required this.feltTint, required this.feltDeep});
  final String id;
  final ui.Image? felt;
  final ui.Image? railWood;

  /// Base cloth colour (multiplied over the texture, or used flat when it is missing).
  final Color feltTint;

  /// Darker cloth colour for cushion noses and the spotlight falloff.
  final Color feltDeep;

  static TableSkin forCosmetic(String id, {ui.Image? felt, ui.Image? railWood}) => switch (id) {
        'ruby' => TableSkin(id: id, felt: felt, railWood: railWood, feltTint: const Color(0xFF8E1E2E), feltDeep: const Color(0xFF4C0E18)),
        'midnight' => TableSkin(id: id, felt: felt, railWood: railWood, feltTint: const Color(0xFF1F2E5A), feltDeep: const Color(0xFF0E1630)),
        _ => TableSkin(id: id, felt: felt, railWood: railWood, feltTint: const Color(0xFF1F7A4D), feltDeep: const Color(0xFF0E4A2B)),
      };
}

/// Procedurally composed table drawn once into a Picture: wooden rail with a
/// soft bevel, diamond sights, felt with a spotlight falloff, cushion noses with
/// pocket openings and leather pocket rings. Geometry comes from [PoolTable] so
/// the cloth rectangle maps 1:1 onto server coordinates (scaled by [scale]).
class TableComponent extends PositionComponent {
  TableComponent({required this.table, required this.skin, required this.unit, required this.rail})
      : super(position: Vector2(-rail * unit, -rail * unit), size: Vector2((table.width + 2 * rail) * unit, (table.height + 2 * rail) * unit), priority: 0);

  final PoolTable table;
  final TableSkin skin;

  /// World pixels per table unit.
  final double unit;

  /// Rail width in table units.
  final double rail;

  ui.Picture? _picture;
  double _sheen = 0;

  @override
  Future<void> onLoad() async {
    _picture = _record();
  }

  @override
  void update(double dt) {
    _sheen = (_sheen + dt * 0.08) % 1.0;
  }

  @override
  void render(Canvas canvas) {
    final p = _picture;
    if (p != null) canvas.drawPicture(p);
    // Very slow lacquer sheen across the rails so the wood feels lit.
    final w = size.x;
    final x = (_sheen * 2 - 0.5) * w;
    final paint = Paint()
      ..shader = ui.Gradient.linear(Offset(x - w * 0.2, 0), Offset(x + w * 0.2, size.y), [Colors.transparent, Colors.white.withValues(alpha: 0.035), Colors.transparent], [0, 0.5, 1])
      ..blendMode = BlendMode.plus;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }

  /// Local (component) offset of a table coordinate.
  Offset local(double x, double y) => Offset((x + rail) * unit, (y + rail) * unit);

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final s = unit;
    final railPx = rail * s;
    final full = Rect.fromLTWH(0, 0, size.x, size.y);
    final cloth = Rect.fromLTWH(railPx, railPx, table.width * s, table.height * s);
    final r = table.ballRadius * s;

    // Floor shadow.
    c.drawRRect(
      RRect.fromRectAndRadius(full.inflate(railPx * 0.5).shift(Offset(0, railPx * 0.6)), Radius.circular(railPx * 1.2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, railPx * 0.9),
    );

    // Rail: wood texture or lacquered gradient.
    final railRRect = RRect.fromRectAndRadius(full, Radius.circular(railPx * 0.9));
    final wood = skin.railWood;
    if (wood != null) {
      c.drawRRect(railRRect, Paint()..shader = ui.ImageShader(wood, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scaleByDouble(railPx * 4 / wood.width, railPx * 4 / wood.width, 1, 1)).storage));
      c.drawRRect(railRRect, Paint()..color = const Color(0xFF2A1407).withValues(alpha: 0.25));
    } else {
      c.drawRRect(railRRect, Paint()..shader = ui.Gradient.linear(full.topLeft, full.bottomRight, const [Color(0xFF4A2412), Color(0xFF2D140A), Color(0xFF55301A), Color(0xFF26110A)], const [0, 0.35, 0.7, 1]));
      // Faux grain.
      final grain = Paint()
        ..color = Colors.black.withValues(alpha: 0.10)
        ..strokeWidth = 1.2;
      final rnd = math.Random(7);
      for (var i = 0; i < 140; i++) {
        final y = rnd.nextDouble() * size.y;
        final x1 = rnd.nextDouble() * size.x;
        c.drawLine(Offset(x1, y), Offset(x1 + 40 + rnd.nextDouble() * 160, y + (rnd.nextDouble() - 0.5) * 6), grain);
      }
    }
    // Rail bevel: light top-left, dark bottom-right, plus a gold inlay line.
    c.drawRRect(railRRect.deflate(1.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..shader = ui.Gradient.linear(full.topLeft, full.bottomRight, [Colors.white.withValues(alpha: 0.28), Colors.transparent, Colors.black.withValues(alpha: 0.45)], const [0, 0.5, 1]));
    c.drawRRect(RRect.fromRectAndRadius(cloth.inflate(railPx * 0.62), Radius.circular(railPx * 0.4)), Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.5, s * 0.18)..color = ZpColors.gold.withValues(alpha: 0.55));

    // Diamond sights.
    final diamond = Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s * 1.6), [ZpColors.champagne, ZpColors.goldDeep]);
    void sight(Offset at) {
      final d = s * 0.9;
      final path = Path()
        ..moveTo(at.dx, at.dy - d)
        ..lineTo(at.dx + d * 0.62, at.dy)
        ..lineTo(at.dx, at.dy + d)
        ..lineTo(at.dx - d * 0.62, at.dy)
        ..close();
      c.drawPath(path, diamond);
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.5));
    }
    final midY = railPx * 0.5;
    for (var k = 1; k < 8; k++) {
      if (k == 4) continue;
      final x = cloth.left + cloth.width * k / 8;
      sight(Offset(x, midY));
      sight(Offset(x, size.y - midY));
    }
    for (var k = 1; k < 4; k++) {
      final y = cloth.top + cloth.height * k / 4;
      sight(Offset(midY, y));
      sight(Offset(size.x - midY, y));
    }

    // Cushion bed: a slab of darker cloth between rail and playfield.
    final bed = cloth.inflate(railPx * 0.42);
    c.drawRRect(RRect.fromRectAndRadius(bed, Radius.circular(s * 0.8)), Paint()..color = skin.feltDeep);

    // Cloth.
    final felt = skin.felt;
    if (felt != null) {
      c.drawRect(cloth, Paint()..shader = ui.ImageShader(felt, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scaleByDouble(s * 30 / felt.width, s * 30 / felt.width, 1, 1)).storage));
      c.drawRect(cloth, Paint()..color = skin.feltTint.withValues(alpha: 0.55)..blendMode = BlendMode.multiply);
    } else {
      c.drawRect(cloth, Paint()..color = skin.feltTint);
      // Woven nap: faint diagonal hatching.
      final nap = Paint()
        ..color = Colors.black.withValues(alpha: 0.05)
        ..strokeWidth = 1;
      for (var x = cloth.left - cloth.height; x < cloth.right; x += s * 0.7) {
        c.drawLine(Offset(x, cloth.bottom), Offset(x + cloth.height, cloth.top), nap);
      }
    }
    // Spotlight falloff: brighter centre, darker corners.
    c.drawRect(
      cloth,
      Paint()
        ..shader = ui.Gradient.radial(cloth.center, cloth.width * 0.62, [Colors.white.withValues(alpha: 0.16), Colors.transparent, Colors.black.withValues(alpha: 0.34)], const [0, 0.55, 1]),
    );
    // Head string and foot spot.
    final hx = cloth.left + table.headStringX * s;
    c.drawLine(Offset(hx, cloth.top), Offset(hx, cloth.bottom), Paint()..color = Colors.white.withValues(alpha: 0.07)..strokeWidth = 1);
    c.drawCircle(Offset(cloth.left + table.footSpot.x * s, cloth.top + table.footSpot.y * s), s * 0.35, Paint()..color = Colors.white.withValues(alpha: 0.18));

    // Cushion noses drawn over the bed along the server's segments.
    final nose = Paint()
      ..color = skin.feltDeep.withValues(alpha: 0.95)
      ..strokeWidth = s * 1.1
      ..strokeCap = StrokeCap.round;
    final noseLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = s * 0.3
      ..strokeCap = StrokeCap.round;
    for (final seg in table.cushions) {
      final a = Offset(cloth.left + seg.x1 * s, cloth.top + seg.y1 * s);
      final b = Offset(cloth.left + seg.x2 * s, cloth.top + seg.y2 * s);
      c.drawLine(a, b, nose);
      c.drawLine(a, b, noseLight);
    }

    // Pockets: leather ring, dark hole with inner shadow.
    for (final p in table.pockets) {
      final centre = Offset(cloth.left + p.x * s, cloth.top + p.y * s);
      final pr = p.r * s;
      c.drawCircle(centre, pr * 1.28, Paint()..shader = ui.Gradient.radial(centre, pr * 1.3, const [Color(0xFF3A2416), Color(0xFF17100A)]));
      c.drawCircle(centre, pr * 1.28, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, s * 0.2)..color = ZpColors.goldDeep.withValues(alpha: 0.6));
      c.drawCircle(centre, pr, Paint()..shader = ui.Gradient.radial(centre.translate(-pr * 0.2, -pr * 0.2), pr, [const Color(0xFF000000), const Color(0xFF05070A), Colors.black.withValues(alpha: 0.85)], const [0, 0.7, 1]));
      c.drawCircle(centre, pr, Paint()..style = PaintingStyle.stroke..strokeWidth = pr * 0.25..color = Colors.black.withValues(alpha: 0.6)..maskFilter = MaskFilter.blur(BlurStyle.inner, pr * 0.3));
    }
    // Faint ball-sized cue ball ghost on the head spot area? No: keep the cloth clean.
    assert(r > 0);
    return rec.endRecording();
  }
}
