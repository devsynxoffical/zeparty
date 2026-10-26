import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/card.dart';

/// Optional decorative images. Any entry may be null; the painter then draws the
/// holographic face itself (and the result still looks designed).
class CardArt {
  const CardArt({this.back, this.faces = const {}, this.symbols = const {}});
  final ui.Image? back;
  final Map<CcColor, ui.Image> faces;
  final Map<CcKind, ui.Image> symbols;
  static const none = CardArt();
}

/// Draws a Color Clash card (face or back) into a rect. Pure canvas code so the
/// same art is used by Flame components, Flutter previews and the colour picker.
class CardPainter {
  CardPainter._();

  static const double aspect = 0.68; // width / height

  /// Paint a card. [sheen] (0..1) slides the holographic highlight band.
  static void paint(Canvas canvas, Rect rect, {CcCard? card, bool faceUp = true, double sheen = 0.3, CardArt art = CardArt.none, double dim = 0, Color? glow, double glowStrength = 0}) {
    final r = rect.width * 0.09;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
    if (glow != null && glowStrength > 0) {
      canvas.drawRRect(rr.inflate(rect.width * 0.04), Paint()..color = glow.withValues(alpha: 0.55 * glowStrength)..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.12 * glowStrength + 0.1));
    }
    // Contact shadow.
    canvas.drawRRect(rr.shift(Offset(0, rect.height * 0.02)), Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.width * 0.05));
    canvas.save();
    canvas.clipRRect(rr);
    if (!faceUp || card == null) {
      _paintBack(canvas, rect, sheen, art.back);
    } else {
      _paintFace(canvas, rect, card, sheen, art);
    }
    if (dim > 0) canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.55 * dim));
    canvas.restore();
    // Edge.
    canvas.drawRRect(rr.deflate(0.5), Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1, rect.width * 0.012)..color = Colors.white.withValues(alpha: 0.75));
  }

  // ---------------------------------------------------------------------------
  // Back
  // ---------------------------------------------------------------------------

  static void _paintBack(Canvas canvas, Rect rect, double sheen, ui.Image? image) {
    if (image != null) {
      paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.cover);
    } else {
      canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A1B4E), Color(0xFF120C22), Color(0xFF1F1440)]).createShader(rect));
      // Diamond lattice.
      final lattice = Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(0.8, rect.width * 0.008)..color = ZpColors.gold.withValues(alpha: 0.22);
      final step = rect.width / 5;
      for (var d = -rect.height; d < rect.width + rect.height; d += step) {
        canvas.drawLine(Offset(rect.left + d, rect.top), Offset(rect.left + d - rect.height, rect.bottom), lattice);
        canvas.drawLine(Offset(rect.left + d, rect.top), Offset(rect.left + d + rect.height, rect.bottom), lattice);
      }
      // Central emblem: three concentric rings and a prism triangle.
      final c = rect.center;
      final er = rect.width * 0.26;
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(c, er * (1 - i * 0.28), Paint()..style = PaintingStyle.stroke..strokeWidth = rect.width * 0.014..shader = SweepGradient(colors: [CcColor.ruby.color, CcColor.gold.color, CcColor.emerald.color, CcColor.sapphire.color, CcColor.ruby.color], transform: GradientRotation(sheen * math.pi * 2 + i)).createShader(Rect.fromCircle(center: c, radius: er)));
      }
      _prismTriangle(canvas, c, er * 0.42, strokeWidth: rect.width * 0.014);
      // Border frame.
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(rect.width * 0.07), Radius.circular(rect.width * 0.05)), Paint()..style = PaintingStyle.stroke..strokeWidth = rect.width * 0.012..color = ZpColors.goldLight.withValues(alpha: 0.6));
    }
    _sheen(canvas, rect, sheen, 0.18);
  }

  // ---------------------------------------------------------------------------
  // Face
  // ---------------------------------------------------------------------------

  static void _paintFace(Canvas canvas, Rect rect, CcCard card, double sheen, CardArt art) {
    final faceImage = art.faces[card.color];
    if (card.color.isWild) {
      _wildBackground(canvas, rect);
    } else if (faceImage != null) {
      paintImage(canvas: canvas, rect: rect, image: faceImage, fit: BoxFit.cover);
    } else {
      final c = card.color.color;
      final d = card.color.deep;
      canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(c, Colors.white, 0.18)!, c, d]).createShader(rect));
      // Faint iridescent bands.
      canvas.drawRect(rect, Paint()..blendMode = BlendMode.screen..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0), const Color(0x3300E5FF), Colors.white.withValues(alpha: 0), const Color(0x33FF4FA3), Colors.white.withValues(alpha: 0)], stops: const [0, 0.3, 0.5, 0.7, 1]).createShader(rect));
    }
    // Inner plate.
    final plate = rect.deflate(rect.width * 0.085);
    final plateR = RRect.fromRectAndRadius(plate, Radius.circular(rect.width * 0.06));
    canvas.drawRRect(plateR, Paint()..style = PaintingStyle.stroke..strokeWidth = rect.width * 0.012..color = Colors.white.withValues(alpha: 0.8));
    // Central oval: tilted ellipse, lighter.
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-0.5);
    final oval = Rect.fromCenter(center: Offset.zero, width: rect.width * 0.66, height: rect.height * 0.74);
    canvas.drawOval(oval, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.72)]).createShader(oval));
    canvas.restore();

    final ink = card.color.isWild ? const Color(0xFF1B1030) : card.color.deep;
    // Central glyph.
    final centre = rect.center;
    final big = rect.width * 0.5;
    switch (card.kind) {
      case CcKind.number:
        _text(canvas, card.glyph, centre, big, ink, shadow: true);
      case CcKind.skip:
        _symbolOrImage(canvas, art, card.kind, centre, big * 0.9, ink, () => _skipSymbol(canvas, centre, big * 0.42, ink, rect.width * 0.05));
      case CcKind.flip:
        _symbolOrImage(canvas, art, card.kind, centre, big * 0.9, ink, () => _flipSymbol(canvas, centre, big * 0.44, ink, rect.width * 0.05));
      case CcKind.surge:
        _symbolOrImage(canvas, art, card.kind, centre, big * 0.9, ink, () => _surgeSymbol(canvas, centre, big * 0.48, ink, '+2', rect.width * 0.2));
      case CcKind.prismSurge:
        _symbolOrImage(canvas, art, card.kind, centre, big * 0.9, ink, () => _surgeSymbol(canvas, centre, big * 0.48, ink, '+4', rect.width * 0.2, spectrum: true));
      case CcKind.prism:
        _symbolOrImage(canvas, art, card.kind, centre, big * 0.9, ink, () => _prismTriangle(canvas, centre, big * 0.5, strokeWidth: rect.width * 0.05, fill: true));
      case CcKind.echo:
        _echoSymbol(canvas, centre, big * 0.5, ink, rect.width * 0.035);
    }
    // Corner indices.
    final small = rect.width * 0.16;
    final tl = Offset(rect.left + rect.width * 0.17, rect.top + rect.height * 0.11);
    final br = Offset(rect.right - rect.width * 0.17, rect.bottom - rect.height * 0.11);
    _cornerMark(canvas, card, tl, small, Colors.white, 0);
    _cornerMark(canvas, card, br, small, Colors.white, math.pi);
    _sheen(canvas, rect, sheen, 0.28);
  }

  static void _symbolOrImage(Canvas canvas, CardArt art, CcKind kind, Offset centre, double size, Color ink, VoidCallback fallback) {
    final img = art.symbols[kind];
    if (img == null) {
      fallback();
      return;
    }
    paintImage(canvas: canvas, rect: Rect.fromCenter(center: centre, width: size, height: size), image: img, fit: BoxFit.contain);
  }

  static void _cornerMark(Canvas canvas, CcCard card, Offset at, double size, Color ink, double rotation) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(rotation);
    switch (card.kind) {
      case CcKind.number:
        _text(canvas, card.glyph, Offset.zero, size, ink, shadow: true);
      case CcKind.skip:
        _skipSymbol(canvas, Offset.zero, size * 0.42, ink, size * 0.14);
      case CcKind.flip:
        _flipSymbol(canvas, Offset.zero, size * 0.45, ink, size * 0.14);
      case CcKind.surge:
        _text(canvas, '+2', Offset.zero, size * 0.8, ink, shadow: true);
      case CcKind.prismSurge:
        _text(canvas, '+4', Offset.zero, size * 0.8, ink, shadow: true);
      case CcKind.prism:
        _prismTriangle(canvas, Offset.zero, size * 0.5, strokeWidth: size * 0.14);
      case CcKind.echo:
        _echoSymbol(canvas, Offset.zero, size * 0.5, ink, size * 0.1);
    }
    canvas.restore();
  }

  static void _wildBackground(Canvas canvas, Rect rect) {
    // Light split by a prism: a conic sweep through the four colours under a dark core.
    canvas.drawRect(rect, Paint()..shader = SweepGradient(center: Alignment.center, colors: [CcColor.ruby.color, CcColor.gold.color, CcColor.emerald.color, CcColor.sapphire.color, CcColor.ruby.color], transform: const GradientRotation(-math.pi / 4)).createShader(rect));
    canvas.drawRect(rect, Paint()..shader = const RadialGradient(colors: [Color(0xFF1B1030), Color(0xAA1B1030), Color(0x001B1030)], stops: [0, 0.35, 1]).createShader(rect));
  }

  // ---------------------------------------------------------------------------
  // Symbols (original: slashed circle, two arrows, bolt, spectrum triangle, waves)
  // ---------------------------------------------------------------------------

  static void _skipSymbol(Canvas canvas, Offset c, double r, Color ink, double stroke) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = ink..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, p);
    final d = r * 0.72;
    canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), p);
  }

  static void _flipSymbol(Canvas canvas, Offset c, double r, Color ink, double stroke) {
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = ink..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final box = Rect.fromCircle(center: c, radius: r);
    // Two opposing arcs with arrow heads.
    canvas.drawArc(box, -math.pi * 0.85, math.pi * 0.7, false, p);
    canvas.drawArc(box, math.pi * 0.15, math.pi * 0.7, false, p);
    void head(double angle, bool cw) {
      final tip = c + Offset(math.cos(angle), math.sin(angle)) * r;
      final dir = cw ? angle + math.pi / 2 : angle - math.pi / 2;
      final a = tip - Offset(math.cos(dir - 0.5), math.sin(dir - 0.5)) * r * 0.45;
      final b = tip - Offset(math.cos(dir + 0.5), math.sin(dir + 0.5)) * r * 0.45;
      canvas.drawPath(Path()..moveTo(a.dx, a.dy)..lineTo(tip.dx, tip.dy)..lineTo(b.dx, b.dy), p);
    }
    head(-math.pi * 0.15, true);
    head(math.pi * 0.85, true);
  }

  static void _surgeSymbol(Canvas canvas, Offset c, double r, Color ink, String label, double fontSize, {bool spectrum = false}) {
    final bolt = Path()
      ..moveTo(c.dx + r * 0.15, c.dy - r)
      ..lineTo(c.dx - r * 0.45, c.dy + r * 0.1)
      ..lineTo(c.dx - r * 0.02, c.dy + r * 0.1)
      ..lineTo(c.dx - r * 0.25, c.dy + r)
      ..lineTo(c.dx + r * 0.45, c.dy - r * 0.15)
      ..lineTo(c.dx + r * 0.02, c.dy - r * 0.15)
      ..close();
    final fill = Paint()..color = ink;
    if (spectrum) {
      fill.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [CcColor.ruby.color, CcColor.gold.color, CcColor.emerald.color, CcColor.sapphire.color]).createShader(Rect.fromCircle(center: c, radius: r));
    }
    canvas.save();
    canvas.translate(-r * 0.35, 0);
    canvas.drawPath(bolt, fill);
    canvas.drawPath(bolt, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.08..color = ink.withValues(alpha: 0.9));
    canvas.restore();
    _text(canvas, label, c + Offset(r * 0.55, r * 0.45), fontSize, ink, shadow: true);
  }

  static void _prismTriangle(Canvas canvas, Offset c, double r, {required double strokeWidth, bool fill = false}) {
    final pts = [for (var i = 0; i < 3; i++) c + Offset(math.cos(-math.pi / 2 + i * 2 * math.pi / 3), math.sin(-math.pi / 2 + i * 2 * math.pi / 3)) * r];
    final tri = Path()..moveTo(pts[0].dx, pts[0].dy)..lineTo(pts[1].dx, pts[1].dy)..lineTo(pts[2].dx, pts[2].dy)..close();
    final shader = SweepGradient(center: Alignment.center, colors: [CcColor.ruby.color, CcColor.gold.color, CcColor.emerald.color, CcColor.sapphire.color, CcColor.ruby.color]).createShader(Rect.fromCircle(center: c, radius: r));
    if (fill) canvas.drawPath(tri, Paint()..shader = shader);
    canvas.drawPath(tri, Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeJoin = StrokeJoin.round..shader = fill ? null : shader..color = const Color(0xFF1B1030));
    // A beam entering and a spectrum fanning out.
    final beam = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth * 0.6..strokeCap = StrokeCap.round..color = Colors.white;
    canvas.drawLine(c + Offset(-r * 1.3, r * 0.1), c + Offset(-r * 0.35, r * 0.1), beam);
    final fan = [CcColor.ruby, CcColor.gold, CcColor.emerald, CcColor.sapphire];
    for (var i = 0; i < 4; i++) {
      final a = -0.35 + i * 0.24;
      canvas.drawLine(c + Offset(r * 0.35, r * 0.1), c + Offset(r * 0.35 + math.cos(a) * r * 1.1, r * 0.1 + math.sin(a) * r * 1.1), Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth * 0.6..strokeCap = StrokeCap.round..color = fan[i].color);
    }
  }

  static void _echoSymbol(Canvas canvas, Offset c, double r, Color ink, double stroke) {
    for (var i = 0; i < 3; i++) {
      final rr = r * (0.35 + i * 0.32);
      canvas.drawArc(Rect.fromCircle(center: c, radius: rr), -math.pi * 0.75, math.pi * 1.5, false, Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round..color = ink.withValues(alpha: 1 - i * 0.22));
    }
    canvas.drawCircle(c, r * 0.14, Paint()..color = ink);
  }

  // ---------------------------------------------------------------------------
  // Text and sheen
  // ---------------------------------------------------------------------------

  static final Map<String, ui.Paragraph> _paragraphCache = {};

  static void _text(Canvas canvas, String s, Offset centre, double size, Color color, {bool shadow = false}) {
    if (s.isEmpty) return;
    final key = '$s|${size.toStringAsFixed(1)}|${color.toARGB32()}|$shadow';
    final para = _paragraphCache.putIfAbsent(key, () {
      final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontWeight: FontWeight.w900, fontSize: size))
        ..pushStyle(ui.TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size, shadows: shadow ? [ui.Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: size * 0.08, offset: Offset(0, size * 0.04))] : null))
        ..addText(s);
      final p = b.build()..layout(ui.ParagraphConstraints(width: size * 3));
      return p;
    });
    canvas.drawParagraph(para, centre - Offset(para.width / 2, para.height / 2));
  }

  static void _sheen(Canvas canvas, Rect rect, double sheen, double strength) {
    final t = sheen % 1;
    final x = rect.left - rect.width + t * rect.width * 3;
    final band = Rect.fromLTWH(x, rect.top, rect.width * 0.9, rect.height);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.skew(-0.35, 0);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRect(band, Paint()..blendMode = BlendMode.plus..shader = LinearGradient(colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: strength), Colors.white.withValues(alpha: 0)]).createShader(band));
    canvas.restore();
    // Static top-edge gloss.
    canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.35), Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)]).createShader(rect));
  }
}
