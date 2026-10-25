import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart' hide PointerMoveEvent;

import 'galaxy_palette.dart';

/// Geometry of the playfield. Everything the renderer and the hit testing need
/// is derived from here so server (row, col) pairs map to exact world positions.
class GridGeometry {
  const GridGeometry({required this.columns, required this.rows, required this.cell, required this.topSlot});

  final int columns;
  final int rows;
  final double cell;

  /// Height reserved above the grid for the ghost disc / drop start.
  final double topSlot;

  double get width => columns * cell;
  double get gridHeight => rows * cell;
  double get height => topSlot + gridHeight + cell * 0.35;
  Rect get gridRect => Rect.fromLTWH(0, topSlot, width, gridHeight);

  /// World centre of a cell. Row 0 is the bottom row.
  Vector2 cellCenter(int row, int col) => Vector2((col + 0.5) * cell, topSlot + (rows - 1 - row + 0.5) * cell);

  /// Where a disc waits before dropping into [col].
  Vector2 slotCenter(int col) => Vector2((col + 0.5) * cell, topSlot * 0.5);

  int? columnAt(double x) {
    if (x < 0 || x >= width) return null;
    return (x / cell).floor().clamp(0, columns - 1);
  }
}

/// The floating crystal grid: metallic frame, translucent crystal body, cell
/// wells, column hover/selection illumination and the ghost disc preview.
/// Discs themselves are separate components layered on top.
class GridComponent extends PositionComponent with TapCallbacks, PointerMoveCallbacks {
  GridComponent({required this.geometry, required this.onColumnTap, required this.onHover, this.frameImage}) : super(size: Vector2(geometry.width, geometry.height), priority: 10);

  final GridGeometry geometry;
  final void Function(int column) onColumnTap;
  final void Function(int? column) onHover;
  final ui.Image? frameImage;

  ui.Picture? _static;
  double _time = 0;

  /// Column currently previewed by the local player (ghost disc), or null.
  int? selectedColumn;

  /// Column under the pointer (desktop / web hover), or null.
  int? hoverColumn;

  /// Row the ghost disc would land on, or -1.
  int ghostRow = -1;

  /// Seat colour used for the illumination.
  int highlightSeat = 0;

  /// Legal columns from the server state; illegal columns render dimmed.
  Set<int> legalColumns = const {};

  /// Interaction enabled only on the local player's turn.
  bool enabled = false;

  @override
  Future<void> onLoad() async {
    _static = _recordStatic();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  ui.Picture _recordStatic() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final g = geometry;
    final cell = g.cell;
    final rect = g.gridRect;
    final outer = rect.inflate(cell * 0.22);
    final rr = RRect.fromRectAndRadius(outer, Radius.circular(cell * 0.3));

    // Shadow / halo the grid casts into space.
    c.drawRRect(rr.inflate(cell * 0.1), Paint()..color = GalaxyPalette.blue.withValues(alpha: 0.18)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.5));

    // Metallic frame: layered strokes with a brushed linear gradient.
    final metal = ui.Gradient.linear(outer.topLeft, outer.bottomRight, [GalaxyPalette.metalLight, GalaxyPalette.metalMid, GalaxyPalette.metalDark, GalaxyPalette.metalMid, GalaxyPalette.metalLight], [0, 0.25, 0.5, 0.75, 1]);
    c.drawRRect(rr, Paint()..shader = metal);
    final inner = RRect.fromRectAndRadius(outer.deflate(cell * 0.11), Radius.circular(cell * 0.22));
    c.drawRRect(inner, Paint()..color = GalaxyPalette.metalDark.withValues(alpha: 0.9));
    c.drawRRect(inner.deflate(1.5), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = GalaxyPalette.crystalEdge.withValues(alpha: 0.5));

    // Translucent crystal body.
    final body = RRect.fromRectAndRadius(rect.inflate(cell * 0.06), Radius.circular(cell * 0.18));
    c.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(rect.topLeft, rect.bottomRight, [GalaxyPalette.crystal.withValues(alpha: 0.16), GalaxyPalette.blue.withValues(alpha: 0.08), GalaxyPalette.crystal.withValues(alpha: 0.12)], [0, 0.55, 1]),
    );
    // Diagonal crystal facets.
    c.save();
    c.clipRRect(body);
    for (var i = -2; i < 6; i++) {
      final x0 = rect.left + i * cell * 1.6;
      final facet = Path()
        ..moveTo(x0, rect.top)
        ..lineTo(x0 + cell * 0.9, rect.top)
        ..lineTo(x0 + cell * 0.9 + rect.height * 0.35, rect.bottom)
        ..lineTo(x0 + rect.height * 0.35, rect.bottom)
        ..close();
      c.drawPath(facet, Paint()..color = Colors.white.withValues(alpha: i.isEven ? 0.035 : 0.02));
    }
    c.restore();

    // Cell wells.
    final hole = cell * 0.42;
    for (var row = 0; row < g.rows; row++) {
      for (var col = 0; col < g.columns; col++) {
        final p = g.cellCenter(row, col).toOffset();
        c.drawCircle(p, hole, Paint()..color = const Color(0xCC03040B));
        c.drawCircle(p, hole, Paint()..shader = ui.Gradient.radial(p.translate(-hole * 0.3, -hole * 0.3), hole * 1.3, [Colors.transparent, GalaxyPalette.blueDeep.withValues(alpha: 0.25)]));
        c.drawCircle(p, hole, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.025..color = GalaxyPalette.crystalEdge.withValues(alpha: 0.45));
        c.drawArc(Rect.fromCircle(center: p, radius: hole * 0.94), math.pi * 1.1, math.pi * 0.5, false, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.02..color = Colors.white.withValues(alpha: 0.35));
      }
    }

    // Column dividers (very faint) so the lanes read on hover.
    for (var col = 1; col < g.columns; col++) {
      final x = col * cell;
      c.drawLine(Offset(x, rect.top + cell * 0.1), Offset(x, rect.bottom - cell * 0.1), Paint()..color = Colors.white.withValues(alpha: 0.04));
    }

    // Four corner rivets on the frame.
    for (final corner in [outer.topLeft, outer.topRight, outer.bottomLeft, outer.bottomRight]) {
      final o = Offset(corner.dx + (corner.dx < rect.center.dx ? cell * 0.18 : -cell * 0.18), corner.dy + (corner.dy < rect.center.dy ? cell * 0.18 : -cell * 0.18));
      c.drawCircle(o, cell * 0.06, Paint()..shader = ui.Gradient.radial(o.translate(-cell * 0.02, -cell * 0.02), cell * 0.07, [GalaxyPalette.metalLight, GalaxyPalette.metalDark]));
    }
    return rec.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final g = geometry;
    final cell = g.cell;
    final pic = _static;
    if (pic != null) canvas.drawPicture(pic);
    final frame = frameImage;
    if (frame != null) {
      final dst = g.gridRect.inflate(cell * 0.32);
      canvas.drawImageRect(frame, Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);
    }

    // Column illumination.
    final hl = selectedColumn ?? hoverColumn;
    if (hl != null && enabled) {
      final color = GalaxyPalette.seat(highlightSeat);
      final strong = selectedColumn != null;
      final pulse = 0.5 + 0.5 * math.sin(_time * (strong ? 5 : 3));
      final lane = Rect.fromLTWH(hl * cell + cell * 0.06, g.gridRect.top + cell * 0.04, cell * 0.88, g.gridHeight - cell * 0.08);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lane, Radius.circular(cell * 0.3)),
        Paint()..shader = ui.Gradient.linear(lane.topCenter, lane.bottomCenter, [color.withValues(alpha: (strong ? 0.32 : 0.18) + pulse * 0.08), color.withValues(alpha: 0.04)]),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(lane, Radius.circular(cell * 0.3)), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color.withValues(alpha: strong ? 0.6 : 0.3));
      // Cells in the lane glow a little brighter, strongest at the landing row.
      for (var row = 0; row < g.rows; row++) {
        final p = g.cellCenter(row, hl).toOffset();
        final land = row == ghostRow;
        canvas.drawCircle(p, cell * 0.4, Paint()..color = color.withValues(alpha: land ? 0.22 + pulse * 0.12 : 0.07)..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08));
      }
      if (ghostRow >= 0) {
        final target = g.cellCenter(ghostRow, hl).toOffset();
        canvas.drawCircle(target, cell * 0.36, Paint()..style = PaintingStyle.stroke..strokeWidth = cell * 0.03..color = GalaxyPalette.seatLight(highlightSeat).withValues(alpha: 0.45 + pulse * 0.4));
      }
      // Ghost disc hovering in the slot above the column.
      if (strong) {
        final s = g.slotCenter(hl).toOffset().translate(0, math.sin(_time * 4) * cell * 0.04);
        _ghostDisc(canvas, s, cell * 0.38, color);
      }
    }

    // Illegal (full) columns: faint cap on top so players read the lane is closed.
    if (enabled) {
      for (var col = 0; col < g.columns; col++) {
        if (legalColumns.contains(col)) continue;
        final r = Rect.fromCenter(center: g.slotCenter(col).toOffset(), width: cell * 0.5, height: cell * 0.08);
        canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = Colors.white.withValues(alpha: 0.12));
      }
    }
  }

  void _ghostDisc(Canvas canvas, Offset p, double r, Color color) {
    canvas.drawCircle(p, r * 1.25, Paint()..color = color.withValues(alpha: 0.25)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5));
    canvas.drawCircle(p, r, Paint()..shader = ui.Gradient.radial(p.translate(-r * 0.3, -r * 0.3), r * 1.2, [Colors.white.withValues(alpha: 0.55), color.withValues(alpha: 0.5), color.withValues(alpha: 0.25)], [0, 0.5, 1]));
    canvas.drawCircle(p, r, Paint()..style = PaintingStyle.stroke..strokeWidth = r * 0.08..color = Colors.white.withValues(alpha: 0.6));
  }

  @override
  void onTapDown(TapDownEvent event) {
    final col = geometry.columnAt(event.localPosition.x);
    if (col == null) return;
    onColumnTap(col);
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    final local = event.localPosition;
    final inside = local.y >= 0 && local.y <= size.y;
    final col = inside ? geometry.columnAt(local.x) : null;
    if (col != hoverColumn) {
      hoverColumn = col;
      onHover(col);
    }
  }

  @override
  void onPointerMoveStop(PointerMoveEvent event) {
    if (hoverColumn != null) {
      hoverColumn = null;
      onHover(null);
    }
  }
}
