import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/zp_colors.dart';

/// Countdown ring driven by an absolute server deadline (epoch ms) so every
/// client shows the same remaining time regardless of when it joined.
class TurnTimerRing extends StatefulWidget {
  const TurnTimerRing({super.key, required this.deadlineMs, required this.totalMs, this.size = 64, this.color = ZpColors.gold, this.child, this.onWarning});
  final int? deadlineMs;
  final int totalMs;
  final double size;
  final Color color;
  final Widget? child;
  /// Fires once when fewer than 5 seconds remain.
  final VoidCallback? onWarning;

  @override
  State<TurnTimerRing> createState() => _TurnTimerRingState();
}

class _TurnTimerRingState extends State<TurnTimerRing> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));
  bool _warned = false;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant TurnTimerRing old) {
    super.didUpdateWidget(old);
    if (old.deadlineMs != widget.deadlineMs) _warned = false;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dl = widget.deadlineMs;
    double frac = 1;
    int remaining = 0;
    if (dl != null) {
      remaining = math.max(0, dl - DateTime.now().millisecondsSinceEpoch);
      frac = widget.totalMs <= 0 ? 1 : (remaining / widget.totalMs).clamp(0.0, 1.0);
      if (remaining < 5000 && remaining > 0 && !_warned) {
        _warned = true;
        widget.onWarning?.call();
      }
    }
    final urgent = dl != null && remaining < 5000;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RingPainter(frac, urgent ? ZpColors.danger : widget.color, dl != null),
        child: Center(child: widget.child ?? (dl == null ? const SizedBox.shrink() : Text('${(remaining / 1000).ceil()}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: urgent ? ZpColors.danger : ZpColors.ivory)))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac, this.color, this.active);
  final double frac;
  final Color color;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.08;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect.deflate(stroke), 0, math.pi * 2, false, track);
    if (!active) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [color.withValues(alpha: 0.4), color], startAngle: -math.pi / 2, endAngle: math.pi * 1.5, transform: const GradientRotation(-math.pi / 2)).createShader(rect);
    canvas.drawArc(rect.deflate(stroke), -math.pi / 2, math.pi * 2 * frac, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.frac != frac || old.color != color || old.active != active;
}
