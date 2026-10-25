import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../model/course.dart';

/// Decorative textures for the course. Any entry may be null: the renderer then
/// draws a designed procedural equivalent (gradients, stripes, ripples).
class CourseSkin {
  const CourseSkin({this.turf, this.sand, this.water, this.rock, this.flag});
  final ui.Image? turf;
  final ui.Image? sand;
  final ui.Image? water;
  final ui.Image? rock;
  final ui.Image? flag;
}

/// Draws a [Course] in world space (course units x [unit]). Geometry is exact and
/// drawn by code; textures are clipped fills over it. Moving obstacles are drawn at
/// [obstacleValues], which the game sets from the state's clock or from replay frames.
class CourseComponent extends PositionComponent {
  CourseComponent({required Course course, required this.skin, required this.unit}) : _course = course {
    priority = 10;
    _rebuild();
  }

  final CourseSkin skin;
  final double unit;
  Course _course;
  Course get course => _course;
  set course(Course c) {
    _course = c;
    _rebuild();
  }

  /// Scalar state per obstacle (bar angle / block offset).
  List<double> obstacleValues = const [];
  double _time = 0;

  late Path _turfPath;
  late List<Path> _sandPaths;
  late List<Path> _waterPaths;
  late Rect _bounds;
  ui.Picture? _staticLayer;

  static const Color turfA = Color(0xFF3FAE5A);
  static const Color turfB = Color(0xFF2E8E47);
  static const Color sandA = Color(0xFFF2DDA4);
  static const Color sandB = Color(0xFFD9BC78);
  static const Color waterDeep = Color(0xFF0E6FA8);
  static const Color waterShallow = Color(0xFF3FC2E8);
  static const Color rockA = Color(0xFF8D8A86);
  static const Color rockB = Color(0xFF5A5652);
  static const Color woodA = Color(0xFFB9783D);
  static const Color woodB = Color(0xFF7A4A22);

  Offset _o(Vec v) => Offset(v.x * unit, v.y * unit);

  /// Column-major 4x4 transform for a tiled image shader: uniform scale plus translation.
  static Float64List _tile(double scale, {double dx = 0, double dy = 0}) {
    final m = Float64List(16);
    m[0] = scale;
    m[5] = scale;
    m[10] = 1;
    m[12] = dx;
    m[13] = dy;
    m[15] = 1;
    return m;
  }

  Path _path(List<Vec> poly) {
    final p = Path();
    if (poly.isEmpty) return p;
    p.moveTo(poly.first.x * unit, poly.first.y * unit);
    for (final v in poly.skip(1)) {
      p.lineTo(v.x * unit, v.y * unit);
    }
    p.close();
    return p;
  }

  void _rebuild() {
    final c = _course;
    size = Vector2(c.width * unit, c.height * unit);
    _bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    _turfPath = _path(c.turf)..fillType = PathFillType.evenOdd;
    for (final island in c.islands) {
      _turfPath.addPath(_path(island), Offset.zero);
    }
    _sandPaths = c.sand.map(_path).toList();
    _waterPaths = c.water.map(_path).toList();
    obstacleValues = c.obstacleValuesAt(0);
    _staticLayer?.dispose();
    _staticLayer = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Water shimmer and flag wave are ambient motion: frozen under "reduce effects".
    if (!GraphicsSettings.instance.reduceEffects) _time += dt;
  }

  @override
  void render(Canvas canvas) {
    _staticLayer ??= _recordStatic();
    canvas.drawPicture(_staticLayer!);
    _renderWaterShimmer(canvas);
    _renderObstacles(canvas);
    _renderFlag(canvas);
  }

  // ---------------------------------------------------------------------------
  // Static layer: ground, hazards, walls, cup
  // ---------------------------------------------------------------------------

  ui.Picture _recordStatic() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    _renderGroundShadow(c);
    c.save();
    c.clipPath(_turfPath);
    _renderTurf(c);
    _renderSand(c);
    _renderWaterBase(c);
    _renderInnerShadow(c);
    c.restore();
    _renderTee(c);
    _renderCup(c);
    _renderWalls(c);
    return rec.endRecording();
  }

  void _renderGroundShadow(Canvas c) {
    c.drawPath(_turfPath.shift(Offset(0, unit * 1.6)), Paint()..color = Colors.black.withValues(alpha: 0.42)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 2));
    // Cliff edge under the island.
    c.drawPath(_turfPath.shift(Offset(0, unit * 0.9)), Paint()..color = const Color(0xFF3B5A2E));
  }

  void _renderTurf(Canvas c) {
    final tex = skin.turf;
    if (tex != null) {
      c.drawRect(_bounds, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, _tile(unit * 22 / tex.width)));
    } else {
      c.drawRect(_bounds, Paint()..shader = ui.Gradient.linear(_bounds.topLeft, _bounds.bottomRight, [turfA, turfB]));
      // Mowed stripes.
      final stripe = Paint()..color = Colors.white.withValues(alpha: 0.06);
      for (var y = 0.0; y < size.y; y += unit * 12) {
        c.drawRect(Rect.fromLTWH(0, y, size.x, unit * 6), stripe);
      }
      // Soft blade noise.
      final rng = math.Random(7);
      final dot = Paint()..color = const Color(0xFF1F6F35).withValues(alpha: 0.18);
      for (var i = 0; i < 260; i++) {
        final x = rng.nextDouble() * size.x;
        final y = rng.nextDouble() * size.y;
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: unit * 0.5, height: unit * 1.1), dot);
      }
    }
    // Sunlight falling from the top-left.
    c.drawRect(_bounds, Paint()..shader = ui.Gradient.radial(Offset(size.x * 0.25, size.y * 0.15), size.y * 0.9, [Colors.white.withValues(alpha: 0.16), Colors.transparent]));
  }

  void _renderSand(Canvas c) {
    final tex = skin.sand;
    for (final p in _sandPaths) {
      c.save();
      c.clipPath(p);
      if (tex != null) {
        c.drawRect(_bounds, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, _tile(unit * 16 / tex.width)));
      } else {
        final b = p.getBounds();
        c.drawRect(b, Paint()..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [sandA, sandB]));
        final rng = math.Random(3);
        final grain = Paint()..color = const Color(0xFFB08E4A).withValues(alpha: 0.25);
        for (var i = 0; i < 80; i++) {
          c.drawCircle(Offset(b.left + rng.nextDouble() * b.width, b.top + rng.nextDouble() * b.height), unit * 0.18, grain);
        }
      }
      // Soft inner rim so the bunker reads as sunken.
      c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 1.6..color = Colors.black.withValues(alpha: 0.22)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.8));
      c.restore();
    }
  }

  void _renderWaterBase(Canvas c) {
    final tex = skin.water;
    for (final p in _waterPaths) {
      c.save();
      c.clipPath(p);
      final b = p.getBounds();
      c.drawRect(b, Paint()..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [waterDeep, waterShallow]));
      if (tex != null) {
        c.drawRect(_bounds, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, _tile(unit * 20 / tex.width))..color = Colors.white.withValues(alpha: 0.85));
      }
      // Depth shadow along the bank.
      c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 2.4..color = Colors.black.withValues(alpha: 0.3)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit));
      c.restore();
      // Foam edge.
      c.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.35..color = Colors.white.withValues(alpha: 0.55));
    }
  }

  void _renderInnerShadow(Canvas c) {
    c.drawPath(_turfPath, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 3..color = Colors.black.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 1.2));
  }

  void _renderTee(Canvas c) {
    final t = _o(_course.tee);
    c.drawCircle(t, unit * 2.6, Paint()..color = Colors.white.withValues(alpha: 0.18));
    c.drawCircle(t, unit * 2.6, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.25..color = Colors.white.withValues(alpha: 0.45));
  }

  void _renderCup(Canvas c) {
    final h = _o(_course.hole);
    final r = cupRadius * unit;
    c.drawCircle(h, r * 1.25, Paint()..color = Colors.white.withValues(alpha: 0.22));
    c.drawCircle(h, r, Paint()..shader = ui.Gradient.radial(h + Offset(-r * 0.3, -r * 0.3), r * 1.4, [const Color(0xFF22221E), const Color(0xFF070707)]));
    c.drawCircle(h, r, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.3..color = Colors.white.withValues(alpha: 0.5));
  }

  void _renderWalls(Canvas c) {
    final w = unit * 3.2;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.35)..strokeWidth = w..strokeCap = StrokeCap.round..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.6);
    final body = Paint()..strokeWidth = w..strokeCap = StrokeCap.round;
    final tex = skin.rock;
    if (tex != null) {
      body.shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, _tile(unit * 14 / tex.width));
    } else {
      body.shader = ui.Gradient.linear(Offset.zero, Offset(0, size.y), [rockA, rockB], [0, 1], TileMode.mirror);
    }
    final dark = Paint()..strokeWidth = w * 0.45..strokeCap = StrokeCap.round..color = Colors.black.withValues(alpha: 0.28);
    final highlight = Paint()..strokeWidth = w * 0.35..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.3);
    for (final s in _course.walls) {
      c.drawLine(_o(s.a) + Offset(0, unit * 1.2), _o(s.b) + Offset(0, unit * 1.2), shadow);
    }
    for (final s in _course.walls) {
      c.drawLine(_o(s.a), _o(s.b), body);
    }
    for (final s in _course.walls) {
      c.drawLine(_o(s.a) + Offset(0, w * 0.22), _o(s.b) + Offset(0, w * 0.22), dark);
      c.drawLine(_o(s.a) + Offset(0, -w * 0.22), _o(s.b) + Offset(0, -w * 0.22), highlight);
    }
  }

  // ---------------------------------------------------------------------------
  // Dynamic layer: water shimmer, obstacles, flag
  // ---------------------------------------------------------------------------

  void _renderWaterShimmer(Canvas c) {
    if (_waterPaths.isEmpty) return;
    final tex = skin.water;
    final dx = math.sin(_time * 0.6) * unit * 3;
    final dy = _time * unit * 1.2;
    for (final p in _waterPaths) {
      c.save();
      c.clipPath(p);
      if (tex != null) {
        c.drawRect(_bounds, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, _tile(unit * 26 / tex.width, dx: dx, dy: dy))..color = Colors.white.withValues(alpha: 0.35)..blendMode = BlendMode.screen);
      } else {
        final b = p.getBounds();
        final ripple = Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.3..color = Colors.white.withValues(alpha: 0.28);
        for (var y = b.top - unit * 4; y < b.bottom + unit * 4; y += unit * 3.5) {
          final path = Path();
          final yy = y + (dy % (unit * 3.5));
          path.moveTo(b.left, yy);
          for (var x = b.left; x <= b.right; x += unit) {
            path.lineTo(x, yy + math.sin(x / (unit * 4) + _time * 1.5) * unit * 0.5);
          }
          c.drawPath(path, ripple);
        }
      }
      // Caustic highlight sweep.
      final b = p.getBounds();
      final sweep = (math.sin(_time * 0.8) + 1) / 2;
      c.drawRect(b, Paint()..shader = ui.Gradient.linear(Offset(b.left + b.width * (sweep - 0.4), b.top), Offset(b.left + b.width * (sweep + 0.1), b.bottom), [Colors.transparent, Colors.white.withValues(alpha: 0.18), Colors.transparent]));
      c.restore();
    }
  }

  void _renderObstacles(Canvas c) {
    final obs = _course.obstacles;
    for (var i = 0; i < obs.length; i++) {
      final o = obs[i];
      final value = i < obstacleValues.length ? obstacleValues[i] : o.valueAt(0);
      final (center, angle, halfW, halfH) = o.poseFor(value);
      final rect = Rect.fromCenter(center: Offset.zero, width: halfW * 2 * unit, height: halfH * 2 * unit);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(unit * 0.6));
      c.save();
      c.translate(center.x * unit, center.y * unit);
      c.rotate(angle);
      // Drop shadow (world-down regardless of rotation is close enough for a thin bar).
      c.drawRRect(rr.shift(Offset(0, unit * 1.1)), Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.8));
      final isBar = o is BarObstacle;
      final colors = isBar ? [woodA, woodB] : [rockA, rockB];
      c.drawRRect(rr, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomLeft, colors));
      if (isBar) {
        // Wood grain lines.
        final grain = Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = unit * 0.12;
        for (var k = -2; k <= 2; k++) {
          final y = k * rect.height / 6;
          c.drawLine(Offset(rect.left + unit * 0.6, y), Offset(rect.right - unit * 0.6, y + k * unit * 0.1), grain);
        }
      } else {
        // Stone block bevel.
        c.drawRRect(rr.deflate(unit * 0.5), Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.2..color = Colors.white.withValues(alpha: 0.18));
      }
      c.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.22..color = Colors.white.withValues(alpha: 0.35));
      c.drawLine(Offset(rect.left + unit * 0.5, rect.top + unit * 0.35), Offset(rect.right - unit * 0.5, rect.top + unit * 0.35), Paint()..strokeWidth = unit * 0.25..color = Colors.white.withValues(alpha: 0.4));
      c.restore();
      if (isBar) {
        // Pivot cap.
        final p = Offset(center.x * unit, center.y * unit);
        c.drawCircle(p, unit * 1.4, Paint()..color = const Color(0xFF3A3A3A));
        c.drawCircle(p, unit * 0.9, Paint()..shader = ui.Gradient.radial(p + Offset(-unit * 0.3, -unit * 0.3), unit * 1.2, [const Color(0xFFF1E3B8), const Color(0xFF9A7B2B)]));
      }
    }
  }

  void _renderFlag(Canvas c) {
    final h = _o(_course.hole);
    final poleH = unit * 11;
    final top = h + Offset(unit * 0.2, -poleH);
    c.drawLine(h + Offset(unit * 0.5, unit * 0.8), h + Offset(unit * 4.5, unit * 1.2), Paint()..color = Colors.black.withValues(alpha: 0.25)..strokeWidth = unit * 0.5..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.4));
    c.drawLine(h + Offset(unit * 0.2, 0), top, Paint()..color = const Color(0xFFF4F1EA)..strokeWidth = unit * 0.45..strokeCap = StrokeCap.round);
    c.drawCircle(top, unit * 0.5, Paint()..color = const Color(0xFFE8C96A));
    final wave = 0.86 + 0.14 * math.sin(_time * 3.1);
    c.save();
    c.translate(top.dx, top.dy);
    c.scale(wave, 1);
    final tex = skin.flag;
    if (tex != null) {
      final w = unit * 7.5;
      final hgt = w * tex.height / tex.width;
      paintImage(canvas: c, rect: Rect.fromLTWH(0, 0, w, hgt), image: tex, fit: BoxFit.fill);
    } else {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(unit * 7, unit * 1.6)
        ..lineTo(0, unit * 3.6)
        ..close();
      c.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(unit * 7, 0), [const Color(0xFFFF6B6B), const Color(0xFFC0213A)]));
      c.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = unit * 0.15..color = Colors.white.withValues(alpha: 0.5));
    }
    c.restore();
  }

  @override
  void onRemove() {
    _staticLayer?.dispose();
    _staticLayer = null;
    super.onRemove();
  }
}
