import 'air_hockey_state.dart';
import 'physics.dart';

/// One unacknowledged paddle input kept for reconciliation.
class PendingInput {
  const PendingInput({required this.seq, required this.target, required this.sentAtMs});
  final int seq;
  final TablePoint target;
  final double sentAtMs;
}

/// Client-side prediction for the local paddle.
///
/// The player drags anywhere on their half; the drag delta moves a *target*. Every
/// frame the predicted paddle moves toward the target under the same travel budget
/// the server enforces (`PADDLE_MAX_SPEED`, banked up to `MOVE_BUDGET_CAP_MS`), so a
/// legal prediction is never rejected. Inputs go out at most [sendHz] times a second
/// and are remembered until the server acknowledges them via `lastAckSeq`; on every
/// `state_tick` the unacknowledged inputs are re-applied on top of the server paddle
/// and the prediction is nudged toward the result.
class LocalPaddlePredictor {
  LocalPaddlePredictor({required this.seat, this.sendHz = 30, TablePoint? start})
      : predicted = start ?? AirHockeyPhysics.paddleHome(seat),
        target = start ?? AirHockeyPhysics.paddleHome(seat);

  final int seat;
  final double sendHz;

  TablePoint predicted;
  TablePoint target;
  double _budget = AirHockeyPhysics.moveBudgetCap;
  final List<PendingInput> pending = [];
  int _seq = 0;
  double _lastSentAtMs = -1e9;
  TablePoint? _lastSentTarget;

  /// Smoothed round-trip estimate in ms (null until the first ack).
  double? latencyMs;

  int get lastSeq => _seq;
  double get sendIntervalMs => 1000 / sendHz;

  /// Relative drag: shift the target by a table-space delta and clamp to the half.
  void moveTargetBy(double dx, double dy) {
    target = AirHockeyPhysics.clampToHalf(seat, target.x + dx, target.y + dy);
  }

  void setTarget(TablePoint p) {
    target = AirHockeyPhysics.clampToHalf(seat, p.x, p.y);
  }

  /// Advance the prediction by [dtSeconds].
  void update(double dtSeconds) {
    _budget = (_budget + AirHockeyPhysics.paddleMaxSpeed * dtSeconds).clamp(0.0, AirHockeyPhysics.moveBudgetCap);
    final next = AirHockeyPhysics.limitStep(predicted, target, _budget);
    _budget -= predicted.distanceTo(next);
    predicted = next;
  }

  /// Returns the paddle action to send now, or null when throttled or unchanged.
  Map<String, dynamic>? maybeSend(double clockMs) {
    if (clockMs - _lastSentAtMs < sendIntervalMs) return null;
    final last = _lastSentTarget;
    if (last != null && last.distanceTo(target) < 0.01) return null;
    _lastSentAtMs = clockMs;
    _lastSentTarget = target;
    _seq += 1;
    pending.add(PendingInput(seq: _seq, target: target, sentAtMs: clockMs));
    if (pending.length > 64) pending.removeRange(0, pending.length - 64);
    return {'type': 'paddle', 'x': _round(target.x), 'y': _round(target.y), 'seq': _seq};
  }

  /// Reconcile against the authoritative paddle. Returns true when a new input was
  /// acknowledged by this snapshot.
  bool reconcile(PaddleSnapshot server, double clockMs) {
    var acked = false;
    while (pending.isNotEmpty && pending.first.seq <= server.lastAckSeq) {
      final p = pending.removeAt(0);
      if (p.seq == server.lastAckSeq) {
        final rtt = clockMs - p.sentAtMs;
        latencyMs = latencyMs == null ? rtt : latencyMs! * 0.7 + rtt * 0.3;
      }
      acked = true;
    }
    // Replay unacknowledged inputs on top of the server position.
    var pos = TablePoint(server.x, server.y);
    var budget = server.moveBudget.clamp(0.0, AirHockeyPhysics.moveBudgetCap);
    final perInput = AirHockeyPhysics.paddleMaxSpeed * sendIntervalMs / 1000;
    for (final p in pending) {
      budget = (budget + perInput).clamp(0.0, AirHockeyPhysics.moveBudgetCap);
      final next = AirHockeyPhysics.limitStep(pos, p.target, budget);
      budget -= pos.distanceTo(next);
      pos = next;
    }
    final err = predicted.distanceTo(pos);
    if (err > 12) {
      predicted = pos;
    } else if (err > 0.05) {
      predicted = predicted.lerp(pos, 0.35);
    }
    return acked;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}

/// One server tick as seen by the client, stamped with the local clock.
class TickSample {
  const TickSample({required this.atMs, required this.puck, required this.paddles, required this.elapsedMs});
  final double atMs;
  final Body puck;
  final List<PaddleSnapshot> paddles;
  final int elapsedMs;
}

/// Interpolated render state for the remote bodies.
class InterpolatedBodies {
  const InterpolatedBodies({required this.puck, required this.paddles, required this.extrapolated});
  final TablePoint puck;
  final List<TablePoint> paddles;
  final bool extrapolated;
}

/// Keeps the last few server ticks and renders the puck and the opponent paddle
/// [delayMs] in the past, interpolating between the two surrounding ticks. When the
/// buffer runs dry (a late packet) the puck is extrapolated along its last velocity
/// for at most [maxExtrapolationMs], then held.
class SnapshotBuffer {
  SnapshotBuffer({this.delayMs = 100, this.maxExtrapolationMs = 60});

  final double delayMs;
  final double maxExtrapolationMs;
  final List<TickSample> _samples = [];

  int get length => _samples.length;
  TickSample? get latest => _samples.isEmpty ? null : _samples.last;

  void add(TickSample s) {
    if (_samples.isNotEmpty && s.atMs <= _samples.last.atMs) {
      _samples[_samples.length - 1] = s;
    } else {
      _samples.add(s);
    }
    // Keep roughly half a second of history.
    while (_samples.length > 2 && _samples.first.atMs < s.atMs - 600) {
      _samples.removeAt(0);
    }
  }

  void clear() => _samples.clear();

  InterpolatedBodies? sample(double nowMs) {
    if (_samples.isEmpty) return null;
    final t = nowMs - delayMs;
    if (_samples.length == 1 || t <= _samples.first.atMs) {
      final s = _samples.first;
      return InterpolatedBodies(puck: TablePoint(s.puck.x, s.puck.y), paddles: s.paddles.map((p) => TablePoint(p.x, p.y)).toList(), extrapolated: false);
    }
    for (var i = 0; i < _samples.length - 1; i++) {
      final a = _samples[i];
      final b = _samples[i + 1];
      if (t >= a.atMs && t <= b.atMs) {
        final span = b.atMs - a.atMs;
        final f = span <= 0 ? 1.0 : ((t - a.atMs) / span).clamp(0.0, 1.0);
        return InterpolatedBodies(
          puck: TablePoint(a.puck.x + (b.puck.x - a.puck.x) * f, a.puck.y + (b.puck.y - a.puck.y) * f),
          paddles: [
            for (var k = 0; k < a.paddles.length && k < b.paddles.length; k++) TablePoint(a.paddles[k].x + (b.paddles[k].x - a.paddles[k].x) * f, a.paddles[k].y + (b.paddles[k].y - a.paddles[k].y) * f),
          ],
          extrapolated: false,
        );
      }
    }
    // Past the newest sample: extrapolate the puck briefly, hold the paddles.
    final s = _samples.last;
    final over = (t - s.atMs).clamp(0.0, maxExtrapolationMs) / 1000;
    return InterpolatedBodies(
      puck: TablePoint(s.puck.x + s.puck.vx * over, s.puck.y + s.puck.vy * over),
      paddles: s.paddles.map((p) => TablePoint(p.x, p.y)).toList(),
      extrapolated: over > 0,
    );
  }
}
