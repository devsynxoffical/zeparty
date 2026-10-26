import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Colour treatment for one piece collection.
class PieceStyle {
  const PieceStyle({required this.whiteFill, required this.whiteRim, required this.blackFill, required this.blackRim, this.imageTint});
  final List<Color> whiteFill;
  final Color whiteRim;
  final List<Color> blackFill;
  final Color blackRim;
  /// Tint applied to bitmap pieces when a collection has no dedicated images.
  final Color? imageTint;

  static const crystal = PieceStyle(
    whiteFill: [Color(0xFFFFFCF4), ZpColors.ivory, ZpColors.champagne, Color(0xFFD9C48E)],
    whiteRim: ZpColors.gold,
    blackFill: [Color(0xFF4A4756), Color(0xFF2B2833), Color(0xFF15131C), Color(0xFF0B0A0F)],
    blackRim: ZpColors.goldDeep,
  );

  static const onyx = PieceStyle(
    whiteFill: [Color(0xFFF4F7FF), Color(0xFFDDE5F5), Color(0xFFB8C4D6), Color(0xFF93A2BA)],
    whiteRim: Color(0xFFC9D3E3),
    blackFill: [Color(0xFF2A2F45), Color(0xFF171B2C), Color(0xFF0B0D18), Color(0xFF05060C)],
    blackRim: Color(0xFF8A7A52),
    imageTint: Color(0xFFB8C4D6),
  );

  static PieceStyle byId(String id) => id == 'onyx' ? onyx : crystal;
}

/// Procedural vector pieces. Drawn in a 100 x 100 design box and scaled to the
/// requested size; results are cached as pictures per (type, colour, size, style).
class PiecePainter {
  PiecePainter._();

  static final Map<String, ui.Picture> _cache = {};

  static void paint(Canvas canvas, {required String type, required bool white, required double size, required PieceStyle style}) {
    final key = '$type|$white|${size.toStringAsFixed(1)}|${identityHashCode(style)}';
    final pic = _cache[key] ??= _record(type, white, size, style);
    canvas.drawPicture(pic);
  }

  static ui.Picture _record(String type, bool white, double size, PieceStyle style) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final s = size / 100;
    c.scale(s, s);
    final body = _bodyPath(type);
    final fill = white ? style.whiteFill : style.blackFill;
    final rim = white ? style.whiteRim : style.blackRim;

    // Soft contact shadow.
    c.drawOval(Rect.fromCenter(center: const Offset(50, 90), width: 52, height: 12), Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // Body fill: vertical gradient, lit from the top-left.
    c.drawPath(body, Paint()..shader = ui.Gradient.linear(const Offset(30, 10), const Offset(70, 90), fill, const [0.0, 0.35, 0.75, 1.0]));
    // Side shading for volume.
    c.drawPath(body, Paint()..shader = ui.Gradient.linear(const Offset(20, 0), const Offset(80, 0), [Colors.white.withValues(alpha: white ? 0.35 : 0.12), Colors.transparent, Colors.black.withValues(alpha: white ? 0.14 : 0.45)], const [0.0, 0.45, 1.0]));
    // Crystal gloss streak.
    c.save();
    c.clipPath(body);
    c.drawOval(const Rect.fromLTWH(32, 18, 10, 46), Paint()..color = Colors.white.withValues(alpha: white ? 0.45 : 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    c.restore();
    // Rim.
    c.drawPath(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = rim..strokeJoin = StrokeJoin.round);
    // Detail lines (bishop slit, crown jewels, rook mortar) in rim colour.
    _details(c, type, rim, white);
    return rec.endRecording();
  }

  static Path _base(Path p) {
    p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(24, 78, 76, 90), const Radius.circular(4)));
    return p;
  }

  static Path _bodyPath(String type) {
    final p = Path();
    switch (type) {
      case 'p':
        p.addOval(Rect.fromCircle(center: const Offset(50, 31), radius: 11));
        p.addOval(Rect.fromCenter(center: const Offset(50, 46), width: 28, height: 8));
        p.moveTo(41, 48);
        p.lineTo(59, 48);
        p.lineTo(68, 78);
        p.lineTo(32, 78);
        p.close();
        return _base(p);
      case 'r':
        p.moveTo(36, 47);
        p.lineTo(64, 47);
        p.lineTo(67, 78);
        p.lineTo(33, 78);
        p.close();
        // Crenellated top: block with three notches.
        final top = Path()..addRect(const Rect.fromLTRB(29, 26, 71, 47));
        final notches = Path()
          ..addRect(const Rect.fromLTRB(36, 26, 42, 34))
          ..addRect(const Rect.fromLTRB(47, 26, 53, 34))
          ..addRect(const Rect.fromLTRB(58, 26, 64, 34));
        p.addPath(Path.combine(PathOperation.difference, top, notches), Offset.zero);
        return _base(p);
      case 'n':
        p.moveTo(30, 78);
        p.lineTo(34, 66);
        p.cubicTo(40, 58, 42, 50, 40, 44);
        p.cubicTo(36, 40, 36, 36, 40, 32);
        p.lineTo(44, 22);
        p.cubicTo(47, 24, 49, 27, 50, 30);
        p.lineTo(57, 18);
        p.cubicTo(60, 24, 62, 30, 63, 34);
        p.cubicTo(72, 38, 76, 46, 74, 52);
        p.cubicTo(72, 56, 68, 56, 65, 54);
        p.cubicTo(62, 52, 58, 52, 56, 56);
        p.cubicTo(60, 62, 68, 70, 70, 78);
        p.close();
        return _base(p);
      case 'b':
        p.addOval(Rect.fromCircle(center: const Offset(50, 17), radius: 4));
        p.moveTo(50, 20);
        p.cubicTo(38, 30, 34, 42, 40, 52);
        p.lineTo(60, 52);
        p.cubicTo(66, 42, 62, 30, 50, 20);
        p.close();
        p.addOval(Rect.fromCenter(center: const Offset(50, 54), width: 28, height: 7));
        p.moveTo(42, 56);
        p.lineTo(58, 56);
        p.lineTo(66, 78);
        p.lineTo(34, 78);
        p.close();
        return _base(p);
      case 'q':
        p.moveTo(36, 52);
        p.lineTo(29, 30);
        p.lineTo(40, 42);
        p.lineTo(40, 22);
        p.lineTo(47, 42);
        p.lineTo(50, 18);
        p.lineTo(53, 42);
        p.lineTo(60, 22);
        p.lineTo(60, 42);
        p.lineTo(71, 30);
        p.lineTo(64, 52);
        p.close();
        for (final o in const [Offset(29, 29), Offset(40, 21), Offset(50, 17), Offset(60, 21), Offset(71, 29)]) {
          p.addOval(Rect.fromCircle(center: o, radius: 3.4));
        }
        p.addOval(Rect.fromCenter(center: const Offset(50, 54), width: 32, height: 7));
        p.moveTo(40, 56);
        p.lineTo(60, 56);
        p.lineTo(68, 78);
        p.lineTo(32, 78);
        p.close();
        return _base(p);
      case 'k':
      default:
        // Cross.
        p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(47.5, 8, 52.5, 30), const Radius.circular(1.5)));
        p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(42, 15, 58, 20), const Radius.circular(1.5)));
        // Crown dome.
        p.moveTo(36, 52);
        p.cubicTo(30, 40, 36, 28, 50, 30);
        p.cubicTo(64, 28, 70, 40, 64, 52);
        p.close();
        p.addOval(Rect.fromCenter(center: const Offset(50, 54), width: 32, height: 7));
        p.moveTo(40, 56);
        p.lineTo(60, 56);
        p.lineTo(68, 78);
        p.lineTo(32, 78);
        p.close();
        return _base(p);
    }
  }

  static void _details(Canvas c, String type, Color rim, bool white) {
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = rim.withValues(alpha: 0.9)..strokeCap = StrokeCap.round;
    switch (type) {
      case 'b':
        c.drawLine(const Offset(46, 34), const Offset(56, 44), line);
      case 'r':
        c.drawLine(const Offset(36, 60), const Offset(64, 60), line..strokeWidth = 1);
      case 'k':
        c.drawLine(const Offset(42, 46), const Offset(58, 46), line);
      case 'q':
        for (final o in const [Offset(29, 29), Offset(40, 21), Offset(50, 17), Offset(60, 21), Offset(71, 29)]) {
          c.drawCircle(o, 1.3, Paint()..color = white ? ZpColors.gold : ZpColors.goldLight);
        }
      case 'n':
        c.drawCircle(const Offset(54, 34), 1.6, Paint()..color = rim);
      default:
        break;
    }
    // Base band.
    c.drawLine(const Offset(26, 82), const Offset(74, 82), line..strokeWidth = 1..color = rim.withValues(alpha: 0.55));
  }
}
