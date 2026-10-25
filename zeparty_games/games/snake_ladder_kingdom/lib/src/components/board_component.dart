import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/kingdom_state.dart';
import 'board_geometry.dart';

/// Floating island board: every square is a parchment/stone island tile with a
/// sculpted 2.5D side, linked by a stone path that follows the boustrophedon.
/// Drawn once into a Picture; the procedural version is the base and the
/// optional `island_tile.webp` texture is layered over the tile tops.
class KingdomBoardComponent extends PositionComponent {
  KingdomBoardComponent({required this.geo, required this.tileTexture}) : super(size: Vector2.all(geo.worldSize), priority: 0);

  final BoardGeometry geo;
  final ui.Image? tileTexture;

  ui.Picture? _picture;
  double _time = 0;

  static Color colorOf(KingdomColor c) => switch (c) {
        KingdomColor.red => ZpColors.ruby,
        KingdomColor.green => ZpColors.emerald,
        KingdomColor.yellow => ZpColors.amber,
        KingdomColor.blue => ZpColors.sapphire,
      };

  static const _parchmentA = Color(0xFFE7D7B1);
  static const _parchmentB = Color(0xFFD9C398);
  static const _stoneA = Color(0xFFB9B1A3);
  static const _stoneB = Color(0xFFA69D8E);
  static const _sideDark = Color(0xFF5B4A3A);
  static const _sideLight = Color(0xFF7D6650);
  static const _moss = Color(0xFF4F7F4A);

  @override
  Future<void> onLoad() async {
    _picture = _record();
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final p = _picture;
    if (p != null) canvas.drawPicture(p);
    // Slow magical light sweep across the islands.
    final w = size.x;
    final x = ((_time * 0.06) % 1.5 - 0.25) * w;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, w),
      Paint()
        ..shader = ui.Gradient.linear(Offset(x - w * 0.2, 0), Offset(x + w * 0.2, w), [Colors.transparent, Colors.white.withValues(alpha: 0.045), Colors.transparent], [0, 0.5, 1])
        ..blendMode = BlendMode.plus,
    );
  }

  Rect _tileRect(int square) {
    final tl = geo.squareTopLeft(square);
    final gap = geo.cell * 0.08;
    return Rect.fromLTWH(tl.x + gap, tl.y + gap, geo.cell - gap * 2, geo.cell - gap * 2);
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final cell = geo.cell;
    final n = geo.boardSize;
    final rng = math.Random(7);

    // Soft shadow of the whole floating landmass on the sky below.
    final gridRect = Rect.fromLTWH(geo.margin, geo.margin, geo.gridSize, geo.gridSize);
    c.drawRRect(RRect.fromRectAndRadius(gridRect.inflate(cell * 0.3).shift(Offset(0, cell * 0.45)), Radius.circular(cell * 0.8)), Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.7));

    // Bedrock slab under the tiles so the islands feel connected underneath.
    c.drawRRect(RRect.fromRectAndRadius(gridRect.inflate(cell * 0.12), Radius.circular(cell * 0.4)), Paint()..color = const Color(0xFF3E3129).withValues(alpha: 0.75));

    // Sculpted stone path: wide dark band, lighter inner band, cobbles.
    final path = Path();
    for (var s = 1; s <= n; s++) {
      final p = geo.squareCenter(s);
      if (s == 1) {
        path.moveTo(p.x, p.y);
      } else {
        path.lineTo(p.x, p.y);
      }
    }
    final dock = geo.dockPosition(0);
    final first = geo.squareCenter(1);
    final entry = Path()
      ..moveTo(dock.x, dock.y)
      ..quadraticBezierTo(first.x, dock.y, first.x, first.y);
    for (final pth in [entry, path]) {
      c.drawPath(pth, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.46..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = _sideDark.withValues(alpha: 0.9));
      c.drawPath(pth, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.34..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = _stoneB);
    }

    // Tiles.
    for (var s = 1; s <= n; s++) {
      _drawTile(c, s, rng);
    }

    // Faint path band over the tiles so the direction stays readable.
    c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.18..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.10));
    for (var s = 1; s < n; s++) {
      final a = geo.squareCenter(s);
      final b = geo.squareCenter(s + 1);
      final m = (a + b) / 2;
      final d = (b - a).normalized();
      final arrow = Path()
        ..moveTo(m.x - d.x * cell * 0.07 - d.y * cell * 0.07, m.y - d.y * cell * 0.07 + d.x * cell * 0.07)
        ..lineTo(m.x + d.x * cell * 0.08, m.y + d.y * cell * 0.08)
        ..lineTo(m.x - d.x * cell * 0.07 + d.y * cell * 0.07, m.y - d.y * cell * 0.07 - d.x * cell * 0.07);
      c.drawPath(arrow, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.035..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..color = _sideDark.withValues(alpha: 0.35));
    }

    // Numbers, start marker and the castle on the final square.
    for (var s = 1; s <= n; s++) {
      _drawNumber(c, s);
    }
    _drawStart(c);
    _drawCastle(c, n);
    _drawDock(c);
    return rec.endRecording();
  }

  void _drawTile(Canvas c, int square, math.Random rng) {
    final cell = geo.cell;
    final r = _tileRect(square);
    final radius = Radius.circular(cell * 0.16);
    final parchment = (square ~/ geo.cols + square) % 3 != 0;
    final top = parchment ? (square.isEven ? _parchmentA : _parchmentB) : (square.isEven ? _stoneA : _stoneB);
    final depth = cell * 0.11;

    // Drop shadow of the individual island.
    c.drawRRect(RRect.fromRectAndRadius(r.shift(Offset(0, depth * 1.6)), radius), Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08));
    // Side face (extrusion), slightly rough bottom edge.
    final side = Path()
      ..addRRect(RRect.fromRectAndRadius(r.shift(Offset(0, depth)), radius));
    c.drawPath(side, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomLeft, [_sideLight, _sideDark]));
    // Hanging root/crystal nubs under a few islands.
    if (rng.nextDouble() < 0.35) {
      final nx = r.left + cell * (0.25 + rng.nextDouble() * 0.4);
      final ny = r.bottom + depth;
      final nub = Path()
        ..moveTo(nx - cell * 0.06, ny)
        ..lineTo(nx, ny + cell * 0.12)
        ..lineTo(nx + cell * 0.06, ny)
        ..close();
      c.drawPath(nub, Paint()..color = _sideDark);
    }
    // Top face.
    final topR = RRect.fromRectAndRadius(r, radius);
    c.drawRRect(topR, Paint()..color = top);
    final tex = tileTexture;
    if (tex != null) {
      final scale = cell * 1.4 / tex.width;
      final m = Matrix4.identity()
        ..translateByDouble(r.left - (square * 37) % 40, r.top - (square * 53) % 40, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      c.drawRRect(topR, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, m.storage)..blendMode = BlendMode.multiply..color = Colors.white.withValues(alpha: 0.85));
    } else {
      // Procedural stone grain: speckles and a couple of hairline cracks.
      final grain = Paint()..color = Colors.black.withValues(alpha: 0.07);
      for (var i = 0; i < 14; i++) {
        c.drawCircle(Offset(r.left + rng.nextDouble() * r.width, r.top + rng.nextDouble() * r.height), cell * (0.012 + rng.nextDouble() * 0.02), grain);
      }
      if (rng.nextDouble() < 0.4) {
        final sx = r.left + rng.nextDouble() * r.width;
        final sy = r.top + rng.nextDouble() * r.height;
        final crack = Path()
          ..moveTo(sx, sy)
          ..relativeLineTo(cell * 0.12, cell * 0.05)
          ..relativeLineTo(cell * 0.06, cell * 0.11);
        c.drawPath(crack, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.012..color = Colors.black.withValues(alpha: 0.18));
      }
    }
    // Light from top-left, dark bevel bottom-right.
    c.drawRRect(topR, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [Colors.white.withValues(alpha: 0.22), Colors.transparent, Colors.black.withValues(alpha: 0.12)], [0, 0.5, 1]));
    c.drawRRect(topR.deflate(cell * 0.01), Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.02..color = ZpColors.goldDeep.withValues(alpha: 0.35));
    // Moss tufts on the edges of some islands.
    if (rng.nextDouble() < 0.45) {
      final mx = r.left + cell * (0.15 + rng.nextDouble() * 0.6);
      c.drawOval(Rect.fromCenter(center: Offset(mx, r.bottom - cell * 0.02), width: cell * 0.18, height: cell * 0.07), Paint()..color = _moss.withValues(alpha: 0.75));
    }
  }

  void _drawNumber(Canvas c, int square) {
    final cell = geo.cell;
    final r = _tileRect(square);
    final tp = TextPainter(
      text: TextSpan(text: '$square', style: TextStyle(fontSize: cell * 0.17, fontWeight: FontWeight.w700, color: _sideDark.withValues(alpha: 0.85), fontFamily: 'serif')),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(r.left + cell * 0.07, r.top + cell * 0.04));
  }

  void _drawStart(Canvas c) {
    final cell = geo.cell;
    final p = geo.squareCenter(1);
    c.drawCircle(p.toOffset(), cell * 0.3, Paint()..color = ZpColors.emerald.withValues(alpha: 0.18));
    c.drawCircle(p.toOffset(), cell * 0.3, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.03..color = ZpColors.emerald.withValues(alpha: 0.6));
  }

  void _drawCastle(Canvas c, int square) {
    final cell = geo.cell;
    final r = _tileRect(square);
    final center = r.center;
    // Golden glow and ring.
    c.drawCircle(center, cell * 0.42, Paint()..color = ZpColors.goldLight.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.2));
    c.drawCircle(center, cell * 0.34, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.035..color = ZpColors.gold);
    // Little keep: two towers and a gate.
    final w = cell * 0.46;
    final h = cell * 0.34;
    final base = Rect.fromCenter(center: center.translate(0, cell * 0.06), width: w, height: h);
    final stone = Paint()..shader = ui.Gradient.linear(base.topLeft, base.bottomRight, [const Color(0xFFCFC6B6), const Color(0xFF8F8372)]);
    c.drawRect(base, stone);
    for (final dx in [-w / 2 + w * 0.12, w / 2 - w * 0.12]) {
      final tower = Rect.fromCenter(center: Offset(center.dx + dx, base.top - h * 0.1), width: w * 0.24, height: h * 0.7);
      c.drawRect(tower, stone);
      for (var i = 0; i < 3; i++) {
        c.drawRect(Rect.fromLTWH(tower.left + i * tower.width / 3 + tower.width * 0.04, tower.top - h * 0.12, tower.width * 0.25, h * 0.12), stone);
      }
      c.drawLine(Offset(tower.center.dx, tower.top - h * 0.14), Offset(tower.center.dx, tower.top - h * 0.45), Paint()..color = _sideDark..strokeWidth = cell * 0.015);
      final flag = Path()
        ..moveTo(tower.center.dx, tower.top - h * 0.45)
        ..lineTo(tower.center.dx + w * 0.16, tower.top - h * 0.38)
        ..lineTo(tower.center.dx, tower.top - h * 0.3)
        ..close();
      c.drawPath(flag, Paint()..color = ZpColors.ruby);
    }
    final gate = Rect.fromCenter(center: Offset(center.dx, base.bottom - h * 0.25), width: w * 0.26, height: h * 0.5);
    c.drawRRect(RRect.fromRectAndCorners(gate, topLeft: Radius.circular(w * 0.13), topRight: Radius.circular(w * 0.13)), Paint()..color = _sideDark);
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTWH(base.left + i * w / 4 + w * 0.03, base.top - h * 0.12, w * 0.14, h * 0.12), stone);
    }
  }

  void _drawDock(Canvas c) {
    final cell = geo.cell;
    final p = geo.dockPosition(0);
    final r = Rect.fromCenter(center: Offset(p.x + cell * 1.25, p.y + cell * 0.1), width: cell * 3.6, height: cell * 0.7);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(cell * 0.3));
    c.drawRRect(rr.shift(Offset(0, cell * 0.12)), Paint()..color = _sideDark);
    c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomLeft, [_stoneA, _stoneB]));
    c.drawRRect(rr.deflate(cell * 0.01), Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.02..color = ZpColors.goldDeep.withValues(alpha: 0.4));
    final tp = TextPainter(
      text: TextSpan(text: 'CAMP', style: TextStyle(fontSize: cell * 0.16, letterSpacing: cell * 0.03, fontWeight: FontWeight.w700, color: _sideDark.withValues(alpha: 0.7))),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(r.right - tp.width - cell * 0.18, r.center.dy - tp.height / 2));
  }
}
