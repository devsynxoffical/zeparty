import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import 'galaxy_palette.dart';
import 'grid_component.dart';

/// One glowing energy disc. Renders the skin sprite when the art exists and a
/// designed procedural plasma disc otherwise. Drops with a gravity-like fall
/// followed by a small bounce, and can be lit up as part of the winning line.
class DiscComponent extends PositionComponent {
  DiscComponent({required this.seat, required this.geometry, required this.sprite, this.plasma = false})
      : super(size: Vector2.all(geometry.cell * 0.78), anchor: Anchor.center, priority: 20);

  final int seat;
  final GridGeometry geometry;
  final Sprite? sprite;
  final bool plasma;

  /// Server cell this disc belongs to; row -1 while still in the slot.
  int row = -1;
  int col = 0;
  bool moving = false;
  bool winning = false;
  double _pulse = 0;
  double _squash = 0; // >0 flattens the disc on landing

  Color get color => GalaxyPalette.seat(seat);

  void snapTo(int toRow, int toCol) {
    row = toRow;
    col = toCol;
    position = geometry.cellCenter(toRow, toCol);
  }

  void placeInSlot(int toCol) {
    row = -1;
    col = toCol;
    position = geometry.slotCenter(toCol);
  }

  /// Fall from the slot to [toRow] with an accelerating curve and bounce twice.
  Future<void> dropTo(int toRow, {void Function()? onLand}) async {
    if (moving) return;
    moving = true;
    final target = geometry.cellCenter(toRow, col);
    final distance = (target.y - position.y).abs();
    final cell = geometry.cell;
    // Fall time scales with sqrt(distance) like real gravity.
    final fallTime = (0.16 + 0.11 * math.sqrt(distance / cell)).clamp(0.2, 0.75).toDouble();
    final c = Completer<void>();
    final bounce1 = math.min(cell * 0.22, distance * 0.12 + cell * 0.08);
    add(SequenceEffect([
      MoveToEffect(target, EffectController(duration: fallTime, curve: Curves.easeInQuad), onComplete: () {
        onLand?.call();
        _squash = 1;
      }),
      MoveByEffect(Vector2(0, -bounce1), EffectController(duration: 0.12, curve: Curves.easeOutQuad)),
      MoveByEffect(Vector2(0, bounce1), EffectController(duration: 0.12, curve: Curves.easeInQuad)),
      MoveByEffect(Vector2(0, -bounce1 * 0.35), EffectController(duration: 0.08, curve: Curves.easeOutQuad)),
      MoveByEffect(Vector2(0, bounce1 * 0.35), EffectController(duration: 0.08, curve: Curves.easeInQuad)),
    ], onComplete: c.complete));
    await c.future;
    position = target;
    row = toRow;
    moving = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse = (_pulse + dt * (winning ? 4.5 : 1.6)) % (math.pi * 2);
    if (_squash > 0) _squash = math.max(0, _squash - dt * 5);
  }

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final center = Offset(r, r);
    final light = GalaxyPalette.seatLight(seat);
    final glow = 0.5 + 0.5 * math.sin(_pulse);
    canvas.save();
    if (_squash > 0) {
      final k = math.sin(_squash * math.pi) * 0.14;
      canvas.translate(center.dx, center.dy);
      canvas.scale(1 + k, 1 - k);
      canvas.translate(-center.dx, -center.dy);
    }
    // Outer energy halo.
    canvas.drawCircle(center, r * (winning ? 1.45 + 0.15 * glow : 1.15), Paint()..color = color.withValues(alpha: winning ? 0.35 + 0.3 * glow : 0.22 + 0.08 * glow)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45));
    final sp = sprite;
    if (sp != null) {
      sp.render(canvas, size: size, overridePaint: Paint()..filterQuality = FilterQuality.medium);
    } else {
      _procedural(canvas, center, r, light, glow);
    }
    if (winning) {
      canvas.drawCircle(center, r * 1.02, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.12..color = Colors.white.withValues(alpha: 0.5 + 0.5 * glow));
    }
    canvas.restore();
  }

  void _procedural(Canvas canvas, Offset center, double r, Color light, double glow) {
    final deep = GalaxyPalette.seatDeep(seat);
    // Body: deep rim to bright core.
    canvas.drawCircle(center, r, Paint()..shader = ui.Gradient.radial(center.translate(-r * 0.25, -r * 0.3), r * 1.25, [light, color, deep], [0, 0.55, 1]));
    // Rim bevel.
    canvas.drawCircle(center, r - r * 0.05, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.1..shader = ui.Gradient.linear(center.translate(0, -r), center.translate(0, r), [Colors.white.withValues(alpha: 0.75), color.withValues(alpha: 0.2), deep.withValues(alpha: 0.9)], [0, 0.5, 1]));
    // Inner energy core ring.
    canvas.drawCircle(center, r * 0.58, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.07..color = light.withValues(alpha: 0.55 + 0.3 * glow));
    canvas.drawCircle(center, r * 0.3, Paint()..shader = ui.Gradient.radial(center, r * 0.32, [Colors.white.withValues(alpha: 0.95), light.withValues(alpha: 0.6), color.withValues(alpha: 0)], [0, 0.5, 1]));
    if (plasma) {
      // Plasma skin: swirling arcs orbiting the core.
      for (var i = 0; i < 3; i++) {
        final a = _pulse * 1.3 + i * math.pi * 2 / 3;
        canvas.drawArc(Rect.fromCircle(center: center, radius: r * 0.78), a, 1.1, false, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.06..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.45 + 0.3 * glow));
      }
    } else {
      // Classic skin: six crystal spokes.
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + _pulse * 0.15;
        final p1 = center + Offset(math.cos(a), math.sin(a)) * r * 0.36;
        final p2 = center + Offset(math.cos(a), math.sin(a)) * r * 0.82;
        canvas.drawLine(p1, p2, Paint()..strokeWidth = r * 0.05..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.22));
      }
    }
    // Specular highlight.
    canvas.drawOval(Rect.fromCenter(center: center.translate(-r * 0.3, -r * 0.45), width: r * 0.7, height: r * 0.3), Paint()..color = Colors.white.withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08));
  }
}
