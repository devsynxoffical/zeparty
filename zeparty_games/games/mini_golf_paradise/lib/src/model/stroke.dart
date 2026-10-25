import 'course.dart';

/// One 1/30 s sample of a server-simulated stroke.
class Keyframe {
  const Keyframe({required this.t, required this.position, required this.obstacles});
  final double t;
  final Vec position;

  /// Scalar obstacle state (bar angle / block offset), one entry per course obstacle.
  final List<double> obstacles;

  factory Keyframe.fromJson(Map<String, dynamic> j) => Keyframe(
        t: (j['t'] as num).toDouble(),
        position: Vec((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        obstacles: (j['obs'] as List<dynamic>? ?? const []).map((e) => (e as num).toDouble()).toList(),
      );
}

enum BounceKind { wall, obstacle }

class Bounce {
  const Bounce({required this.t, required this.position, required this.kind});
  final double t;
  final Vec position;
  final BounceKind kind;

  factory Bounce.fromJson(Map<String, dynamic> j) => Bounce(
        t: (j['t'] as num).toDouble(),
        position: Vec((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        kind: j['kind'] == 'obstacle' ? BounceKind.obstacle : BounceKind.wall,
      );
}

/// Payload of the `stroke_resolved` event.
class StrokeResolved {
  const StrokeResolved({required this.seat, required this.frames, required this.holed, required this.water, required this.bounces, required this.finalPosition, required this.strokes});
  final int seat;
  final List<Keyframe> frames;
  final bool holed;
  final bool water;
  final List<Bounce> bounces;
  final Vec finalPosition;
  final int strokes;

  double get duration => frames.isEmpty ? 0 : frames.last.t;

  factory StrokeResolved.fromJson(Map<String, dynamic> j) => StrokeResolved(
        seat: (j['seat'] as num).toInt(),
        frames: (j['frames'] as List<dynamic>? ?? const []).map((f) => Keyframe.fromJson(f as Map<String, dynamic>)).toList(),
        holed: j['holed'] as bool? ?? false,
        water: j['water'] as bool? ?? false,
        bounces: (j['bounces'] as List<dynamic>? ?? const []).map((b) => Bounce.fromJson(b as Map<String, dynamic>)).toList(),
        finalPosition: Vec.fromJson(j['final'] as Map<String, dynamic>),
        strokes: (j['strokes'] as num?)?.toInt() ?? 0,
      );

  /// Interpolated ball position and obstacle values at replay time [t].
  (Vec, List<double>) sample(double t) {
    if (frames.isEmpty) return (finalPosition, const []);
    if (t <= frames.first.t) return (frames.first.position, frames.first.obstacles);
    if (t >= frames.last.t) return (frames.last.position, frames.last.obstacles);
    var lo = 0;
    var hi = frames.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (frames[mid].t <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = frames[lo];
    final b = frames[hi];
    final span = b.t - a.t;
    final k = span <= 0 ? 1.0 : ((t - a.t) / span).clamp(0.0, 1.0);
    final p = Vec(a.position.x + (b.position.x - a.position.x) * k, a.position.y + (b.position.y - a.position.y) * k);
    final obs = <double>[for (var i = 0; i < a.obstacles.length && i < b.obstacles.length; i++) a.obstacles[i] + (b.obstacles[i] - a.obstacles[i]) * k];
    return (p, obs);
  }
}
