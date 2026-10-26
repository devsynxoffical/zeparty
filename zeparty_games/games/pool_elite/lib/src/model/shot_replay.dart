import 'dart:math' as math;

/// One keyframe body sample.
class BodySample {
  const BodySample(this.t, this.x, this.y);
  final double t;
  final double x;
  final double y;
}

class ShotCollision {
  const ShotCollision({required this.t, required this.type, this.a, this.b, this.ball, this.pocket, this.speed = 0});
  final double t;

  /// 'ball', 'cushion' or 'pocket'.
  final String type;
  final int? a;
  final int? b;
  final int? ball;
  final int? pocket;
  final double speed;

  factory ShotCollision.fromJson(Map<String, dynamic> j) => ShotCollision(
        t: (j['t'] as num).toDouble(),
        type: j['type'] as String,
        a: (j['a'] as num?)?.toInt(),
        b: (j['b'] as num?)?.toInt(),
        ball: (j['ball'] as num?)?.toInt(),
        pocket: (j['pocket'] as num?)?.toInt(),
        speed: (j['speed'] as num?)?.toDouble() ?? 0,
      );
}

class PocketedBall {
  const PocketedBall({required this.id, required this.by, required this.pocket, required this.t});
  final int id;
  final int by;
  final int pocket;
  final double t;

  factory PocketedBall.fromJson(Map<String, dynamic> j) => PocketedBall(
        id: (j['id'] as num).toInt(),
        by: (j['by'] as num?)?.toInt() ?? -1,
        pocket: (j['pocket'] as num?)?.toInt() ?? 0,
        t: (j['t'] as num?)?.toDouble() ?? 0,
      );
}

class FinalBody {
  const FinalBody(this.id, this.x, this.y);
  final int id;
  final double x;
  final double y;
}

/// Parsed `shot_resolved` payload with per-body sample tracks for interpolation.
///
/// The server omits bodies that did not move in a keyframe, so each body gets its
/// own track; [positionAt] interpolates linearly between the two surrounding
/// samples of that track and holds the last sample afterwards.
class ShotReplay {
  ShotReplay({
    required this.frames,
    required this.collisions,
    required this.pocketed,
    required this.fouls,
    required this.firstContact,
    required this.railContacted,
    required this.cueScratched,
    required this.isBreak,
    required this.duration,
    required this.finalBodies,
  }) {
    for (final f in frames) {
      for (final b in f.bodies) {
        (_tracks[b.id] ??= []).add(BodySample(f.t, b.x, b.y));
      }
    }
    for (final p in pocketed) {
      _pocketTime[p.id] = p.t;
    }
  }

  final List<ReplayFrame> frames;
  final List<ShotCollision> collisions;
  final List<PocketedBall> pocketed;
  final List<String> fouls;
  final int? firstContact;
  final bool railContacted;
  final bool cueScratched;
  final bool isBreak;
  final double duration;
  final List<FinalBody> finalBodies;

  final Map<int, List<BodySample>> _tracks = {};
  final Map<int, double> _pocketTime = {};

  Iterable<int> get bodyIds => _tracks.keys;
  bool isPocketed(int id) => _pocketTime.containsKey(id);
  double? pocketTimeOf(int id) => _pocketTime[id];
  PocketedBall? pocketedEntry(int id) => pocketed.where((p) => p.id == id).firstOrNull;

  /// Time of the 8 ball drop, if any (drives the slow-motion beat).
  double? get eightDropTime => _pocketTime[8];

  /// Interpolated position of [id] at [t] seconds, or null when it has no track.
  math.Point<double>? positionAt(int id, double t) {
    final track = _tracks[id];
    if (track == null || track.isEmpty) return null;
    if (t <= track.first.t) return math.Point(track.first.x, track.first.y);
    final last = track.last;
    if (t >= last.t) return math.Point(last.x, last.y);
    // Binary search for the segment containing t.
    var lo = 0;
    var hi = track.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (track[mid].t <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = track[lo];
    final b = track[hi];
    final span = b.t - a.t;
    final k = span <= 0 ? 1.0 : ((t - a.t) / span).clamp(0.0, 1.0);
    return math.Point(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k);
  }

  factory ShotReplay.fromJson(Map<String, dynamic> j) {
    final frames = (j['frames'] as List<dynamic>? ?? const []).map((f) => ReplayFrame.fromJson(f as Map<String, dynamic>)).toList();
    final finals = (j['final'] as List<dynamic>? ?? const [])
        .map((b) => b as Map<String, dynamic>)
        .map((b) => FinalBody((b['id'] as num).toInt(), (b['x'] as num).toDouble(), (b['y'] as num).toDouble()))
        .toList();
    final duration = (j['duration'] as num?)?.toDouble() ?? (frames.isEmpty ? 0.0 : frames.last.t);
    return ShotReplay(
      frames: frames,
      collisions: (j['collisions'] as List<dynamic>? ?? const []).map((c) => ShotCollision.fromJson(c as Map<String, dynamic>)).toList(),
      pocketed: (j['pocketed'] as List<dynamic>? ?? const []).map((p) => PocketedBall.fromJson(p as Map<String, dynamic>)).toList(),
      fouls: (j['fouls'] as List<dynamic>? ?? const []).cast<String>(),
      firstContact: (j['firstContact'] as num?)?.toInt(),
      railContacted: j['railContacted'] as bool? ?? false,
      cueScratched: j['cueScratched'] as bool? ?? false,
      isBreak: j['isBreak'] as bool? ?? false,
      duration: duration,
      finalBodies: finals,
    );
  }
}

class ReplayFrame {
  const ReplayFrame({required this.t, required this.bodies});
  final double t;
  final List<FinalBody> bodies;

  factory ReplayFrame.fromJson(Map<String, dynamic> j) => ReplayFrame(
        t: (j['t'] as num).toDouble(),
        bodies: (j['bodies'] as List<dynamic>? ?? const [])
            .map((b) => b as Map<String, dynamic>)
            .map((b) => FinalBody((b['id'] as num).toInt(), (b['x'] as num).toDouble(), (b['y'] as num).toDouble()))
            .toList(),
      );
}
