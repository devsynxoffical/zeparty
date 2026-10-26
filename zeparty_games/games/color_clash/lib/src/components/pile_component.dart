import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/card.dart';
import 'card_painter.dart';
import 'layout.dart';

/// Face-down draw pile: a short stack of backs with a count badge. Tap to draw.
class DrawPileComponent extends PositionComponent with TapCallbacks {
  DrawPileComponent({required this.art, required this.onTap}) : super(size: Vector2(ArenaLayout.cardW, ArenaLayout.cardH), anchor: Anchor.center, position: ArenaLayout.drawPilePos, priority: 20);

  final CardArt art;
  final VoidCallback onTap;
  int count = 0;
  bool enabled = false;
  double _pulse = 0;
  double _sheen = 0.2;

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 2.5;
    _sheen = (_sheen + dt * 0.1) % 1;
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    final layers = count == 0 ? 0 : math.min(4, 1 + count ~/ 12);
    if (layers == 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.09)), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: 0.25));
    }
    for (var i = layers - 1; i >= 0; i--) {
      final r = rect.shift(Offset(-i * 3.0, -i * 4.0));
      CardPainter.paint(canvas, r, faceUp: false, sheen: _sheen + i * 0.1, art: art, glow: enabled && i == 0 ? ZpColors.goldLight : null, glowStrength: enabled ? 0.6 + 0.4 * math.sin(_pulse) : 0);
    }
    // Count badge.
    final badge = Offset(size.x * 0.5, size.y + 26);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: badge, width: 74, height: 34), const Radius.circular(17)), Paint()..color = ZpColors.obsidian.withValues(alpha: 0.75));
    _label(canvas, '$count', badge, 20, ZpColors.ivory);
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    if (enabled) onTap();
  }
}

/// Discard pile: the top card face up over a few slightly rotated earlier cards.
class DiscardPileComponent extends PositionComponent {
  DiscardPileComponent({required this.art}) : super(size: Vector2(ArenaLayout.cardW, ArenaLayout.cardH), anchor: Anchor.center, position: ArenaLayout.discardPos, priority: 20);

  final CardArt art;
  final List<_Laid> _stack = [];
  CcColor currentColor = CcColor.ruby;
  int count = 0;
  double _sheen = 0.5;
  double _glow = 0;
  final _rng = math.Random();

  CcCard? get top => _stack.isEmpty ? null : _stack.last.card;

  /// Snap to the authoritative top card (initial sync, resync).
  void setTop(CcCard? card) {
    _stack.clear();
    if (card != null) _stack.add(_Laid(card, 0));
  }

  /// A card landed from a play animation: keep a shallow history for depth.
  void push(CcCard card) {
    _stack.add(_Laid(card, (_rng.nextDouble() - 0.5) * 0.35));
    if (_stack.length > 4) _stack.removeAt(0);
    _glow = 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sheen = (_sheen + dt * 0.1) % 1;
    _glow = math.max(0, _glow - dt * 1.5);
  }

  @override
  void render(Canvas canvas) {
    final rect = Offset.zero & size.toSize();
    final c = rect.center;
    if (_stack.isEmpty) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size.x * 0.09)), Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: 0.25));
    }
    // Colour halo shows the current colour even when the top card is wild.
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(16), Radius.circular(size.x * 0.14)), Paint()..color = currentColor.color.withValues(alpha: 0.35 + _glow * 0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    for (var i = 0; i < _stack.length; i++) {
      final l = _stack[i];
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(l.angle);
      canvas.translate(-c.dx, -c.dy);
      CardPainter.paint(canvas, rect, card: l.card, faceUp: true, sheen: _sheen + i * 0.2, art: art, dim: i == _stack.length - 1 ? 0 : 0.3);
      canvas.restore();
    }
    // Count badge.
    final badge = Offset(size.x * 0.5, size.y + 26);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: badge, width: 74, height: 34), const Radius.circular(17)), Paint()..color = ZpColors.obsidian.withValues(alpha: 0.75));
    _label(canvas, '$count', badge, 20, ZpColors.ivory);
  }
}

class _Laid {
  _Laid(this.card, this.angle);
  final CcCard card;
  final double angle;
}

final Map<String, ui.Paragraph> _labelCache = {};
void _label(Canvas canvas, String s, Offset centre, double size, Color color) {
  final key = '$s|$size|${color.toARGB32()}';
  final para = _labelCache.putIfAbsent(key, () {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: size, fontWeight: FontWeight.w700))
      ..pushStyle(ui.TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700))
      ..addText(s);
    return b.build()..layout(ui.ParagraphConstraints(width: size * 6));
  });
  canvas.drawParagraph(para, centre - Offset(para.width / 2, para.height / 2));
}

/// Shared label helper for other components.
void drawLabel(Canvas canvas, String s, Offset centre, double size, Color color) => _label(canvas, s, centre, size, color);
