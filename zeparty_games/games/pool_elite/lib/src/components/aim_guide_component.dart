import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/aim.dart';

/// Trajectory guide: dashed cue ball line to the first contact, a ghost ball and
/// short direction stubs for both balls. Computed client-side for feel only.
class AimGuideComponent extends Component {
  AimGuideComponent({required this.scale, required this.ballRadius}) : super(priority: 25);

  final double scale;
  final double ballRadius;

  AimPreview? preview;
  double power = 0.5;
  bool visible = false;
  double _dashPhase = 0;

  @override
  void update(double dt) {
    _dashPhase = (_dashPhase + dt * 40) % 24;
  }

  @override
  void render(Canvas canvas) {
    final p = preview;
    if (!visible || p == null) return;
    final r = ballRadius * scale;
    final start = Offset(p.start.x * scale, p.start.y * scale);
    final end = Offset(p.end.x * scale, p.end.y * scale);
    final lineColor = p.legalTarget ? ZpColors.champagne : ZpColors.danger;

    // Dashed main line.
    final dir = end - start;
    final len = dir.distance;
    if (len > 0.01) {
      final u = dir / len;
      final dash = Paint()
        ..color = lineColor.withValues(alpha: 0.85)
        ..strokeWidth = math.max(1.5, r * 0.16)
        ..strokeCap = StrokeCap.round;
      var d = _dashPhase - 24 + r * 1.1;
      while (d < len - r) {
        final a = math.max(d, r * 1.1);
        final b = math.min(d + 12, len - r);
        if (b > a) canvas.drawLine(start + u * a, start + u * b, dash);
        d += 24;
      }
    }

    // Ghost ball at the contact point and the two direction stubs.
    final ghost = p.ghost;
    if (ghost != null) {
      final g = Offset(ghost.x * scale, ghost.y * scale);
      canvas.drawCircle(g, r, Paint()..color = Colors.white.withValues(alpha: 0.18));
      canvas.drawCircle(g, r, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.2, r * 0.12)..color = lineColor.withValues(alpha: 0.9));
      final od = p.objectDir!;
      final stub = (r * 3) + power * r * 6;
      final objStart = g + Offset(od.x, od.y) * (2 * r);
      _arrow(canvas, objStart, objStart + Offset(od.x, od.y) * stub, lineColor, r);
      final cd = p.cueDir;
      final cueStub = r * (1.5 + power * 3) * math.sin(p.cutAngle).abs();
      if (cueStub > r * 0.6) _arrow(canvas, g, g + Offset(cd.x, cd.y) * cueStub, Colors.white.withValues(alpha: 0.75), r);
    } else {
      // Cushion bounce stub.
      final cd = p.cueDir;
      canvas.drawCircle(end, r, Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.2, r * 0.12)..color = lineColor.withValues(alpha: 0.6));
      _arrow(canvas, end, end + Offset(cd.x, cd.y) * (r * 2 + power * r * 4), Colors.white.withValues(alpha: 0.6), r);
    }
  }

  void _arrow(Canvas canvas, Offset a, Offset b, Color color, double r) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(1.5, r * 0.18)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, paint);
    final d = b - a;
    if (d.distance < 0.01) return;
    final u = d / d.distance;
    final n = Offset(-u.dy, u.dx);
    final head = r * 0.6;
    canvas.drawLine(b, b - u * head + n * head * 0.6, paint);
    canvas.drawLine(b, b - u * head - n * head * 0.6, paint);
  }
}
