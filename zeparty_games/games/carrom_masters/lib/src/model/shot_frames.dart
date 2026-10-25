import 'carrom_state.dart';
import 'geometry.dart';

/// One body position inside a keyframe (board coordinates).
class FrameBody {
  const FrameBody(this.id, this.position);
  final String id;
  final BPoint position;

  factory FrameBody.fromJson(Map<String, dynamic> j) => FrameBody(j['id'] as String, BPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble()));
}

/// Keyframe sampled by the server every 1/30 s. Bodies that did not move since
/// the previous keyframe are omitted; the first frame lists every body.
class ShotFrame {
  const ShotFrame(this.t, this.bodies);
  final double t;
  final List<FrameBody> bodies;

  factory ShotFrame.fromJson(Map<String, dynamic> j) => ShotFrame((j['t'] as num).toDouble(), (j['bodies'] as List<dynamic>).map((b) => FrameBody.fromJson(b as Map<String, dynamic>)).toList());
}

class PocketedCoin {
  const PocketedCoin({required this.id, required this.by, required this.t, required this.pocket});
  final String id;
  final CarromSide? by;
  final double t;
  /// Pocket index 0..3, or -1 when the body left the board without a pocket.
  final int pocket;

  factory PocketedCoin.fromJson(Map<String, dynamic> j) => PocketedCoin(
        id: j['id'] as String,
        by: j['by'] == null ? null : CarromSide.parse(j['by'] as String),
        t: (j['t'] as num?)?.toDouble() ?? 0,
        pocket: (j['pocket'] as num?)?.toInt() ?? -1,
      );
}

enum CollisionKind {
  coin,
  cushion,
  pocket;

  static CollisionKind parse(String s) => switch (s) { 'cushion' => CollisionKind.cushion, 'pocket' => CollisionKind.pocket, _ => CollisionKind.coin };
}

class ShotCollision {
  const ShotCollision({required this.t, required this.kind, required this.speed, required this.ids});
  final double t;
  final CollisionKind kind;
  final double speed;
  final List<String> ids;

  factory ShotCollision.fromJson(Map<String, dynamic> j) => ShotCollision(
        t: (j['t'] as num).toDouble(),
        kind: CollisionKind.parse(j['kind'] as String),
        speed: (j['speed'] as num?)?.toDouble() ?? 0,
        ids: (j['ids'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

/// Payload of the `shot_resolved` event.
class ShotResolved {
  const ShotResolved({
    required this.side,
    required this.placement,
    required this.frames,
    required this.pocketed,
    required this.fouls,
    required this.strikerPocketed,
    required this.queenPocketed,
    required this.queenCovered,
    required this.queenPending,
    required this.collisions,
    required this.finalPositions,
    required this.duration,
    required this.extraStrike,
  });
  final CarromSide side;
  /// Striker start position in board coordinates.
  final BPoint placement;
  final List<ShotFrame> frames;
  final List<PocketedCoin> pocketed;
  final List<String> fouls;
  final bool strikerPocketed;
  final bool queenPocketed;
  final bool queenCovered;
  final bool queenPending;
  final List<ShotCollision> collisions;
  final Map<String, BPoint> finalPositions;
  final double duration;
  final bool extraStrike;

  bool get foul => fouls.isNotEmpty;

  factory ShotResolved.fromJson(Map<String, dynamic> j) {
    final placement = (j['placement'] as Map<String, dynamic>?) ?? const {'x': 50, 'y': 88};
    final frames = (j['frames'] as List<dynamic>? ?? const []).map((f) => ShotFrame.fromJson(f as Map<String, dynamic>)).toList();
    final finals = <String, BPoint>{};
    for (final f in (j['final'] as List<dynamic>? ?? const [])) {
      final fb = FrameBody.fromJson(f as Map<String, dynamic>);
      finals[fb.id] = fb.position;
    }
    return ShotResolved(
      side: CarromSide.parse(j['side'] as String? ?? 'white'),
      placement: BPoint((placement['x'] as num).toDouble(), (placement['y'] as num).toDouble()),
      frames: frames,
      pocketed: (j['pocketed'] as List<dynamic>? ?? const []).map((p) => PocketedCoin.fromJson(p as Map<String, dynamic>)).toList(),
      fouls: (j['fouls'] as List<dynamic>? ?? const []).cast<String>(),
      strikerPocketed: j['strikerPocketed'] as bool? ?? false,
      queenPocketed: j['queenPocketed'] as bool? ?? false,
      queenCovered: j['queenCovered'] as bool? ?? false,
      queenPending: j['queenPending'] as bool? ?? false,
      collisions: (j['collisions'] as List<dynamic>? ?? const []).map((c) => ShotCollision.fromJson(c as Map<String, dynamic>)).toList(),
      finalPositions: finals,
      duration: (j['duration'] as num?)?.toDouble() ?? (frames.isEmpty ? 0 : frames.last.t),
      extraStrike: j['extraStrike'] as bool? ?? false,
    );
  }

  /// Per-body keyframe tracks built from the sparse frames (absolute positions).
  Map<String, List<(double, BPoint)>> tracks() {
    final out = <String, List<(double, BPoint)>>{};
    for (final f in frames) {
      for (final b in f.bodies) {
        out.putIfAbsent(b.id, () => []).add((f.t, b.position));
      }
    }
    return out;
  }
}

class ReturnedCoin {
  const ReturnedCoin({required this.id, required this.position, required this.reason});
  final String id;
  final BPoint position;
  final String reason;

  factory ReturnedCoin.fromJson(Map<String, dynamic> j) => ReturnedCoin(id: j['id'] as String, position: BPoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble()), reason: j['reason'] as String? ?? '');

  static List<ReturnedCoin> listFromPayload(Map<String, dynamic> payload) => (payload['coins'] as List<dynamic>? ?? const []).map((c) => ReturnedCoin.fromJson(c as Map<String, dynamic>)).toList();
}
