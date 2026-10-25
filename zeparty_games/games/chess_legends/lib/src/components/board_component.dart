import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/board_fen.dart' as fen;

/// Board skin: optional textures for the two square families plus the tints
/// used when the textures are missing or as an overlay on top of them.
class BoardSkin {
  const BoardSkin({required this.id, this.darkTexture, this.lightTexture, required this.dark, required this.light, required this.frame, required this.frameLine, required this.coordColor});
  final String id;
  final ui.Image? darkTexture;
  final ui.Image? lightTexture;
  final Color dark;
  final Color light;
  final Color frame;
  final Color frameLine;
  final Color coordColor;

  static BoardSkin resolve(String id, {ui.Image? darkTexture, ui.Image? lightTexture}) => switch (id) {
        'ivory' => BoardSkin(id: id, darkTexture: darkTexture, lightTexture: lightTexture, dark: const Color(0xFFA67B4F), light: const Color(0xFFF1E7D0), frame: const Color(0xFF3A2A1C), frameLine: ZpColors.gold, coordColor: ZpColors.champagne),
        _ => BoardSkin(id: 'obsidian', darkTexture: darkTexture, lightTexture: lightTexture, dark: const Color(0xFF131119), light: const Color(0xFF3B3647), frame: const Color(0xFF0B0A0F), frameLine: ZpColors.gold, coordColor: ZpColors.goldLight),
      };
}

/// Highlight layers the game sets after every state change.
class BoardHighlights {
  String? selected;
  String? hover;
  List<String> legal = const [];
  List<String> captures = const [];
  (String, String)? lastMove;
  String? checkSquare;
  bool darkened = false;
}

/// Draws the 8 x 8 board with an engraved frame and delivers square-level input.
/// Geometry: `border` around a grid of `cell` sized squares. The viewer's colour is
/// at the bottom when [flipped] is false for white and true for black.
class BoardComponent extends PositionComponent with TapCallbacks, DragCallbacks {
  BoardComponent({required this.skin, required this.cell, required this.border, required this.flipped, required this.onSquareTap, required this.onDragBegin, required this.onDragMove, required this.onDragFinish})
      : super(size: Vector2.all(cell * 8 + border * 2), priority: 0);

  BoardSkin skin;
  final double cell;
  final double border;
  bool flipped;
  final void Function(String square) onSquareTap;
  final bool Function(String square) onDragBegin;
  final void Function(Vector2 worldPoint) onDragMove;
  final void Function(String? square) onDragFinish;

  final BoardHighlights highlights = BoardHighlights();
  ui.Picture? _static;
  double _sweep = 0;
  double _pulse = 0;
  bool _dragging = false;

  @override
  Future<void> onLoad() async {
    _static = _recordStatic();
  }

  /// Re-record after an orientation or skin change.
  void rebuild() => _static = _recordStatic();

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

  /// Column/row on screen for an algebraic square.
  (int col, int row) cellOf(String square) {
    final f = fen.fileOf(square);
    final r = fen.rankOf(square);
    return flipped ? (7 - f, r) : (f, 7 - r);
  }

  Vector2 squareCenter(String square) {
    final (col, row) = cellOf(square);
    return Vector2(border + (col + 0.5) * cell, border + (row + 0.5) * cell);
  }

  Rect squareRect(String square) {
    final (col, row) = cellOf(square);
    return Rect.fromLTWH(border + col * cell, border + row * cell, cell, cell);
  }

  /// Square under a point in board (world) coordinates, or null outside the grid.
  String? squareAt(Vector2 p) {
    final col = ((p.x - border) / cell).floor();
    final row = ((p.y - border) / cell).floor();
    if (col < 0 || col > 7 || row < 0 || row > 7) return null;
    final f = flipped ? 7 - col : col;
    final r = flipped ? row : 7 - row;
    return fen.squareName(f, r);
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  @override
  void onTapUp(TapUpEvent event) {
    if (_dragging) return;
    final s = squareAt(event.localPosition);
    if (s != null) onSquareTap(s);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final s = squareAt(event.localPosition);
    _dragging = s != null && onDragBegin(s);
    if (_dragging) highlights.hover = s;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_dragging) return;
    final p = event.localEndPosition;
    highlights.hover = squareAt(p);
    onDragMove(p);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!_dragging) return;
    _dragging = false;
    final target = highlights.hover;
    highlights.hover = null;
    onDragFinish(target);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (!_dragging) return;
    _dragging = false;
    highlights.hover = null;
    onDragFinish(null);
  }

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    final ambient = GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects;
    if (ambient) _sweep = (_sweep + dt * 0.08) % 1.0;
    _pulse = (_pulse + dt * 2.4) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    final pic = _static;
    if (pic != null) canvas.drawPicture(pic);
    _renderHighlights(canvas);
    _renderLighting(canvas);
    if (highlights.darkened) {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.black.withValues(alpha: 0.45));
    }
  }

  void _renderHighlights(Canvas c) {
    final h = highlights;
    final glow = 0.5 + 0.5 * math.sin(_pulse);
    final lm = h.lastMove;
    if (lm != null) {
      for (final s in [lm.$1, lm.$2]) {
        c.drawRect(squareRect(s), Paint()..color = ZpColors.goldLight.withValues(alpha: 0.28));
        c.drawRect(squareRect(s).deflate(1), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = ZpColors.gold.withValues(alpha: 0.55));
      }
    }
    if (h.checkSquare != null) {
      final r = squareRect(h.checkSquare!);
      c.drawRect(r, Paint()..shader = ui.Gradient.radial(r.center, cell * 0.7, [ZpColors.danger.withValues(alpha: 0.55 + 0.25 * glow), ZpColors.danger.withValues(alpha: 0)]));
    }
    if (h.selected != null) {
      final r = squareRect(h.selected!);
      c.drawRect(r, Paint()..color = ZpColors.goldLight.withValues(alpha: 0.35));
      c.drawRect(r.deflate(1.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = ZpColors.goldLight.withValues(alpha: 0.8 + 0.2 * glow));
    }
    for (final s in h.legal) {
      final isCapture = h.captures.contains(s);
      final center = squareRect(s).center;
      if (isCapture) {
        c.drawCircle(center, cell * 0.44, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.07..color = ZpColors.ruby.withValues(alpha: 0.75 + 0.2 * glow));
      } else {
        c.drawCircle(center, cell * 0.15, Paint()..color = ZpColors.goldLight.withValues(alpha: 0.8));
        c.drawCircle(center, cell * 0.15, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = ZpColors.goldDeep.withValues(alpha: 0.7));
      }
    }
    if (h.hover != null && h.legal.contains(h.hover)) {
      c.drawRect(squareRect(h.hover!).deflate(2), Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = Colors.white.withValues(alpha: 0.75));
    }
  }

  void _renderLighting(Canvas c) {
    final w = size.x;
    final full = size.toRect();
    // Slow light sweep over the whole board.
    if (GraphicsSettings.instance.current.ambientAnimation && !GraphicsSettings.instance.reduceEffects) {
      final x = (_sweep * 2.2 - 0.6) * w;
      c.drawRect(full, Paint()..shader = ui.Gradient.linear(Offset(x - w * 0.3, 0), Offset(x + w * 0.3, w), [Colors.transparent, ZpColors.champagne.withValues(alpha: 0.06), Colors.transparent], const [0.0, 0.5, 1.0])..blendMode = BlendMode.plus);
    }
    // Soft gold vignette.
    c.drawRect(full, Paint()..shader = ui.Gradient.radial(full.center, w * 0.78, [Colors.transparent, ZpColors.goldDeep.withValues(alpha: 0.08), Colors.black.withValues(alpha: 0.35)], const [0.55, 0.8, 1.0]));
  }

  ui.Picture _recordStatic() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final w = size.x;
    final full = Rect.fromLTWH(0, 0, w, w);

    // Floating shadow.
    c.drawRRect(RRect.fromRectAndRadius(full.inflate(cell * 0.25).shift(Offset(0, cell * 0.3)), Radius.circular(cell * 0.4)), Paint()..color = Colors.black.withValues(alpha: 0.55)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.5));

    // Frame: deep lacquer with an engraved double gold line.
    final frameR = RRect.fromRectAndRadius(full, Radius.circular(border * 0.5));
    c.drawRRect(frameR, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, w), [skin.frame, Color.lerp(skin.frame, Colors.white, 0.12)!, skin.frame], const [0.0, 0.5, 1.0]));
    c.drawRRect(frameR.deflate(border * 0.18), Paint()..style = PaintingStyle.stroke..strokeWidth = border * 0.06..color = skin.frameLine.withValues(alpha: 0.9));
    c.drawRRect(frameR.deflate(border * 0.32), Paint()..style = PaintingStyle.stroke..strokeWidth = border * 0.025..color = skin.frameLine.withValues(alpha: 0.5));
    // Engraving groove highlights.
    c.drawRRect(frameR.deflate(border * 0.18 + border * 0.035), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.6));
    // Corner ornaments.
    for (final corner in [Offset(border * 0.5, border * 0.5), Offset(w - border * 0.5, border * 0.5), Offset(border * 0.5, w - border * 0.5), Offset(w - border * 0.5, w - border * 0.5)]) {
      c.drawCircle(corner, border * 0.14, Paint()..color = skin.frameLine.withValues(alpha: 0.9));
      c.drawCircle(corner, border * 0.22, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = skin.frameLine.withValues(alpha: 0.5));
    }

    // Squares.
    final grid = Rect.fromLTWH(border, border, cell * 8, cell * 8);
    for (var col = 0; col < 8; col++) {
      for (var row = 0; row < 8; row++) {
        final f = flipped ? 7 - col : col;
        final r = flipped ? row : 7 - row;
        final light = fen.isLightSquare(fen.squareName(f, r));
        final rect = Rect.fromLTWH(border + col * cell, border + row * cell, cell, cell);
        _paintSquare(c, rect, light);
      }
    }
    // Inner bevel around the grid.
    c.drawRect(grid.inflate(1.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = skin.frameLine.withValues(alpha: 0.85));
    c.drawRect(grid, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.7));

    // Coordinates engraved into the frame.
    final style = TextStyle(color: skin.coordColor.withValues(alpha: 0.85), fontSize: border * 0.42, fontWeight: FontWeight.w600, letterSpacing: 1);
    final shadow = TextStyle(color: Colors.black.withValues(alpha: 0.7), fontSize: border * 0.42, fontWeight: FontWeight.w600, letterSpacing: 1);
    for (var i = 0; i < 8; i++) {
      final fileLetter = fen.files[flipped ? 7 - i : i];
      final rankNumber = '${flipped ? i + 1 : 8 - i}';
      final fx = border + (i + 0.5) * cell;
      final ry = border + (i + 0.5) * cell;
      _text(c, fileLetter, Offset(fx, w - border * 0.5), style, shadow);
      _text(c, fileLetter, Offset(fx, border * 0.5), style, shadow);
      _text(c, rankNumber, Offset(border * 0.5, ry), style, shadow);
      _text(c, rankNumber, Offset(w - border * 0.5, ry), style, shadow);
    }
    return rec.endRecording();
  }

  void _paintSquare(Canvas c, Rect rect, bool light) {
    final tex = light ? skin.lightTexture : skin.darkTexture;
    final base = light ? skin.light : skin.dark;
    if (tex != null) {
      final scale = cell * 2 / tex.width;
      c.drawRect(rect, Paint()..shader = ui.ImageShader(tex, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scaleByDouble(scale, scale, 1, 1)).storage));
      // Tint so both skins keep their identity even over a shared marble texture.
      c.drawRect(rect, Paint()..color = base.withValues(alpha: 0.45));
    } else {
      // Procedural marble: base, diagonal sheen, veins.
      c.drawRect(rect, Paint()..color = base);
      c.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [Colors.white.withValues(alpha: light ? 0.16 : 0.08), Colors.transparent, Colors.black.withValues(alpha: light ? 0.08 : 0.25)], const [0.0, 0.5, 1.0]));
      final rng = math.Random(rect.left.round() * 31 + rect.top.round() * 17);
      final vein = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = (light ? Colors.black : Colors.white).withValues(alpha: light ? 0.06 : 0.05);
      for (var i = 0; i < 2; i++) {
        final p = Path()..moveTo(rect.left + rng.nextDouble() * cell, rect.top);
        p.quadraticBezierTo(rect.left + rng.nextDouble() * cell, rect.top + rng.nextDouble() * cell, rect.left + rng.nextDouble() * cell, rect.bottom);
        c.drawPath(p, vein);
      }
    }
    // Subtle inner edge so squares read as inlaid stone.
    c.drawRect(rect.deflate(0.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: light ? 0.12 : 0.35));
  }

  void _text(Canvas c, String s, Offset center, TextStyle style, TextStyle shadow) {
    for (final (st, off) in [(shadow, const Offset(0.8, 0.8)), (style, Offset.zero)]) {
      final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr)..layout();
      tp.paint(c, center - Offset(tp.width / 2, tp.height / 2) + off);
    }
  }
}
