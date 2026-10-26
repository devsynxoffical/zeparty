import 'dart:async';

import 'package:flame/components.dart';

import '../model/geometry.dart' as g;
import '../model/shot_frames.dart';
import 'piece_component.dart';

/// Replays the server's 30 fps keyframes at the display rate by tweening every
/// body between its surrounding keyframes. Fires collision and pocket callbacks
/// when the replay clock passes their timestamps, then snaps to the final rest
/// positions and completes [done].
class ShotReplayer extends Component {
  ShotReplayer({required this.shot, required this.pieces, required this.toWorld, required this.onCollision, required this.onPocketed, this.speed = 1});

  final ShotResolved shot;
  final Map<String, PieceComponent> pieces;
  /// Board coordinates -> world pixels (handles the viewer's rotation).
  final Vector2 Function(g.BPoint) toWorld;
  final void Function(ShotCollision collision, Vector2 at) onCollision;
  final void Function(PocketedCoin pocketed, Vector2 at) onPocketed;
  /// Playback rate (1 = real time).
  final double speed;

  final _done = Completer<void>();
  Future<void> get done => _done.future;

  late final Map<String, List<(double, g.BPoint)>> _tracks = shot.tracks();
  final Map<String, int> _cursor = {};
  final Map<String, g.BPoint> _last = {};
  final Set<String> _pocketedDone = {};
  final Map<String, double> _pocketShrink = {};
  int _collisionIdx = 0;
  double _t = 0;
  bool _finished = false;

  double get elapsed => _t;
  double get duration => shot.duration;

  @override
  void onMount() {
    super.onMount();
    for (final e in _tracks.entries) {
      final p = pieces[e.key];
      if (p == null) continue;
      _last[e.key] = e.value.first.$2;
      p.position = toWorld(e.value.first.$2);
      p.speed = 0;
      p.visible = true;
      p.visualScale = 1;
    }
  }

  /// Board position of a body at replay time [t] (null when it has no track).
  g.BPoint? positionAt(String id, double t) {
    final track = _tracks[id];
    if (track == null || track.isEmpty) return null;
    var i = _cursor[id] ?? 0;
    while (i + 1 < track.length && track[i + 1].$1 <= t) {
      i++;
    }
    _cursor[id] = i;
    if (i + 1 >= track.length) {
      final pocket = shot.pocketed.where((p) => p.id == id).firstOrNull;
      if (pocket != null && pocket.pocket >= 0 && t > track[i].$1) {
        // Glide into the pocket centre until the capture time.
        final span = pocket.t - track[i].$1;
        final k = span <= 1e-6 ? 1.0 : ((t - track[i].$1) / span).clamp(0.0, 1.0);
        return _lerp(track[i].$2, g.pockets[pocket.pocket], k);
      }
      return track[i].$2;
    }
    final (t0, p0) = track[i];
    final (t1, p1) = track[i + 1];
    final k = t1 <= t0 ? 1.0 : ((t - t0) / (t1 - t0)).clamp(0.0, 1.0);
    return _lerp(p0, p1, k);
  }

  static g.BPoint _lerp(g.BPoint a, g.BPoint b, double k) => g.BPoint(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k);

  @override
  void update(double dt) {
    if (_finished) return;
    final step = dt * speed;
    _t += step;

    for (final id in _tracks.keys) {
      final piece = pieces[id];
      if (piece == null) continue;
      if (_pocketedDone.contains(id)) {
        final s = (_pocketShrink[id] ?? 1) - step * 6;
        _pocketShrink[id] = s;
        piece.visualScale = s.clamp(0.0, 1.0);
        if (s <= 0) piece.visible = false;
        continue;
      }
      final p = positionAt(id, _t);
      if (p == null) continue;
      final prev = _last[id] ?? p;
      final world = toWorld(p);
      final moved = toWorld(prev);
      final v = step <= 0 ? 0.0 : (world - moved).length / step;
      piece.speed = v;
      if (v > 1) piece.velocityDir = (world - moved).normalized();
      piece.position = world;
      _last[id] = p;
    }

    // Pocket captures.
    for (final pk in shot.pocketed) {
      if (_pocketedDone.contains(pk.id) || pk.t > _t) continue;
      _pocketedDone.add(pk.id);
      _pocketShrink[pk.id] = 1;
      final at = pk.pocket >= 0 ? toWorld(g.pockets[pk.pocket]) : (pieces[pk.id]?.position ?? Vector2.zero());
      final piece = pieces[pk.id];
      if (piece != null) {
        piece.position = at;
        piece.speed = 0;
      }
      onPocketed(pk, at);
    }

    // Collisions in timestamp order.
    while (_collisionIdx < shot.collisions.length && shot.collisions[_collisionIdx].t <= _t) {
      final c = shot.collisions[_collisionIdx++];
      Vector2? at;
      for (final id in c.ids) {
        final p = positionAt(id, c.t);
        if (p != null) {
          at = at == null ? toWorld(p) : (at + toWorld(p)) / 2;
        }
      }
      onCollision(c, at ?? Vector2.zero());
    }

    if (_t >= shot.duration + 0.12) finish();
  }

  /// Snap every body to its final position and complete. Safe to call twice.
  void finish() {
    if (_finished) return;
    _finished = true;
    for (final id in _tracks.keys) {
      final piece = pieces[id];
      if (piece == null) continue;
      piece.speed = 0;
      final f = shot.finalPositions[id];
      if (f != null) {
        piece.position = toWorld(f);
        piece.visible = true;
        piece.visualScale = 1;
      } else {
        piece.visible = false;
        piece.visualScale = 1;
      }
    }
    for (final pk in shot.pocketed) {
      if (!_pocketedDone.contains(pk.id)) {
        _pocketedDone.add(pk.id);
        onPocketed(pk, pk.pocket >= 0 ? toWorld(g.pockets[pk.pocket]) : Vector2.zero());
      }
    }
    if (!_done.isCompleted) _done.complete();
    removeFromParent();
  }
}
