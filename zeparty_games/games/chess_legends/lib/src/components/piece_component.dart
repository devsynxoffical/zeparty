import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'piece_painter.dart';

/// Sprites per FEN letter; a missing entry means "draw procedurally".
typedef PieceSprites = Map<String, Sprite>;

/// One chess piece. Position is the square centre in world units. It never
/// decides anything: the game moves it, captures it or promotes it from server
/// events and then snaps every piece to the authoritative FEN.
class PieceComponent extends PositionComponent {
  PieceComponent({required this.square, required this.piece, required this.sprites, required this.style, required this.cellSize, this.lifted = false})
      : super(size: Vector2.all(cellSize), anchor: Anchor.center, priority: 20);

  /// Current logical square (algebraic).
  String square;
  /// FEN letter.
  String piece;
  final PieceSprites sprites;
  final PieceStyle style;
  final double cellSize;

  bool moving = false;
  bool lifted;
  /// Drawn as a glowing king when in check.
  bool inCheck = false;
  /// Winner's king after checkmate.
  bool crowned = false;
  double _pulse = 0;
  double _alpha = 1;

  bool get isWhite => piece.toUpperCase() == piece;
  String get type => piece.toLowerCase();

  void snapTo(String newSquare, Vector2 center) {
    square = newSquare;
    position = center;
    _updatePriority();
  }

  void _updatePriority() => priority = lifted ? 40 : 20 + (position.y / cellSize).floor();

  /// Glide to [center]; resolves when the effect completes.
  Future<void> moveTo(String newSquare, Vector2 center, {double duration = 0.28}) async {
    if (moving) {
      snapTo(newSquare, center);
      return;
    }
    moving = true;
    final c = Completer<void>();
    final dist = (center - position).length / cellSize;
    final dur = duration + math.min(0.25, dist * 0.04);
    add(MoveToEffect(center, EffectController(duration: dur, curve: Curves.easeInOutCubic), onComplete: c.complete));
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.12), EffectController(duration: dur * 0.4, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1), EffectController(duration: dur * 0.6, curve: Curves.easeIn)),
    ]));
    await c.future;
    square = newSquare;
    moving = false;
    _updatePriority();
  }

  /// Captured: shrink and fade, then remove.
  Future<void> captureOut() async {
    moving = true;
    final c = Completer<void>();
    add(ScaleEffect.to(Vector2.all(0.15), EffectController(duration: 0.42, curve: Curves.easeInBack), onComplete: c.complete));
    add(_FadeEffect(duration: 0.42, onAlpha: (a) => _alpha = a));
    await c.future;
    removeFromParent();
  }

  /// Promotion: pop and swap the glyph.
  Future<void> promoteTo(String newPiece) async {
    final c = Completer<void>();
    add(SequenceEffect([
      ScaleEffect.to(Vector2.all(0.6), EffectController(duration: 0.14, curve: Curves.easeIn)),
      ScaleEffect.to(Vector2.all(1.2), EffectController(duration: 0.18, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.14, curve: Curves.easeInOut)),
    ], onComplete: c.complete));
    await Future<void>.delayed(const Duration(milliseconds: 140));
    piece = newPiece;
    await c.future;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (inCheck || crowned || lifted) _pulse = (_pulse + dt * 2.6) % (math.pi * 2);
  }

  @override
  void render(Canvas canvas) {
    final s = size.x;
    final center = Offset(s / 2, s / 2);
    final glow = 0.55 + 0.45 * math.sin(_pulse);
    if (inCheck) {
      canvas.drawCircle(center, s * (0.46 + 0.05 * glow), Paint()..color = ZpColors.danger.withValues(alpha: 0.35 + 0.3 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.22));
    }
    if (crowned) {
      canvas.drawCircle(center, s * (0.5 + 0.08 * glow), Paint()..color = ZpColors.goldLight.withValues(alpha: 0.4 + 0.35 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.25));
    }
    if (lifted) {
      // Larger, softer shadow while dragged.
      canvas.drawOval(Rect.fromCenter(center: Offset(s / 2, s * 0.98), width: s * 0.7, height: s * 0.2), Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12));
    }
    final inset = s * 0.08;
    final rect = Rect.fromLTWH(inset, inset - (lifted ? s * 0.08 : 0), s - inset * 2, s - inset * 2);
    final sprite = sprites[piece];
    if (_alpha < 1) canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: _alpha));
    if (sprite != null) {
      final tint = style.imageTint;
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
      // Refined contact shadow under bitmap pieces.
      canvas.drawOval(Rect.fromCenter(center: Offset(s / 2, s * 0.9), width: s * 0.55, height: s * 0.12), Paint()..color = Colors.black.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05));
      sprite.render(canvas, position: Vector2(rect.left, rect.top), size: Vector2(rect.width, rect.height), overridePaint: paint);
    } else {
      canvas.save();
      canvas.translate(rect.left, rect.top);
      PiecePainter.paint(canvas, type: type, white: isWhite, size: rect.width, style: style);
      canvas.restore();
    }
    if (_alpha < 1) canvas.restore();
  }
}

class _FadeEffect extends Effect {
  _FadeEffect({required double duration, required this.onAlpha}) : super(EffectController(duration: duration));
  final void Function(double) onAlpha;
  @override
  void apply(double progress) => onAlpha(1 - progress);
  @override
  void onFinish() {
    super.onFinish();
    removeFromParent();
  }
}
