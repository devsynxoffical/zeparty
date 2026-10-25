import 'dart:async' show StreamSubscription, unawaited;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import 'air_hockey_assets.dart';
import 'air_hockey_audio.dart';
import 'components/arena_component.dart';
import 'components/fx.dart';
import 'components/paddle_component.dart';
import 'components/puck_component.dart';
import 'model/air_hockey_state.dart';
import 'model/netcode.dart';
import 'model/physics.dart';

/// UI-facing notifications the HUD renders.
class AirHockeyNotice {
  const AirHockeyNotice(this.text, {this.icon, this.color, this.big = false});
  final String text;
  final IconData? icon;
  final Color? color;
  /// Large centre banner (GOAL, GO, SUDDEN DEATH) instead of a toast.
  final bool big;
}

/// Result summary for the finished overlay.
class AirHockeyFinish {
  const AirHockeyFinish({required this.winnerSeat, required this.reason, required this.score});
  final int? winnerSeat;
  final String reason;
  final List<int> score;
}

/// The Flame scene for Neon Air Hockey.
///
/// World space is the table (100 x 180 units) scaled by [unit]; the bottom of the
/// view is always the local player (seat 1 sees the table rotated 180 degrees,
/// spectators see seat 0 at the bottom). Netcode:
///
/// * the local paddle is predicted with [LocalPaddlePredictor] and inputs are
///   sent at 30 Hz through `channel.sendRealtime` (no version);
/// * the puck and the opponent paddle are interpolated 100 ms in the past between
///   the two surrounding `state_tick` samples ([SnapshotBuffer]);
/// * every server update carries `lastAckSeq`, used to drop acknowledged inputs,
///   replay the rest on top of the server paddle and measure round-trip latency.
class AirHockeyGame extends FlameGame with DragCallbacks {
  AirHockeyGame({required this.session, required this.channel});

  final GameSessionContext session;
  final GameChannel channel;

  static const double unit = 10;
  static final Vector2 worldSize = Vector2(AirHockeyPhysics.tableWidth * unit, AirHockeyPhysics.tableHeight * unit);

  late ArenaComponent arena;
  late PuckComponent puck;
  late Fx fx;
  final Map<int, PaddleComponent> paddles = {};

  final ValueNotifier<AirHockeyState?> latestState = ValueNotifier(null);
  final ValueNotifier<int?> latencyMs = ValueNotifier(null);
  final ValueNotifier<AirHockeyNotice?> notice = ValueNotifier(null);
  final ValueNotifier<int?> faceoffMs = ValueNotifier(null);
  final ValueNotifier<int> clockMs = ValueNotifier(0);
  final ValueNotifier<AirHockeyFinish?> finish = ValueNotifier(null);

  LocalPaddlePredictor? predictor;
  final SnapshotBuffer buffer = SnapshotBuffer(delayMs: 100);
  final List<StreamSubscription<dynamic>> _subs = [];

  double _clockMs = 0;
  double _latestArrivalMs = 0;
  double _shake = 0;
  final math.Random _rng = math.Random();
  bool _realtimeUnsupported = false;
  int _version = 0;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  /// Seat 1 plays on a table rotated 180 degrees so it also defends the bottom.
  bool get flipped => mySeat == 1;
  /// The seat shown at the bottom of the view.
  int get bottomSeat => flipped ? 1 : 0;
  int get version => _version;
  double get localClockMs => _clockMs;

  Color colorOfSeat(int seat) => seat == bottomSeat ? NeonPalette.cyan : NeonPalette.magenta;

  /// Table units to world pixels, applying the viewer rotation.
  Vector2 toView(double tx, double ty) => flipped ? Vector2((AirHockeyPhysics.tableWidth - tx) * unit, (AirHockeyPhysics.tableHeight - ty) * unit) : Vector2(tx * unit, ty * unit);

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: worldSize.x, height: worldSize.y);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = AirHockeyState.fromJson(session.initialState);
    _version = session.initialVersion;
    final q = GraphicsSettings.instance.current;

    Future<ui.Image?> img(String logical) async {
      try {
        return await images.load(ZpAssets.key(logical, quality: q));
      } catch (_) {
        return null; // procedural fallback
      }
    }

    final results = await Future.wait([img(AirHockeyAssets.surface), img(AirHockeyAssets.puck), img(AirHockeyAssets.paddleCyan), img(AirHockeyAssets.paddleMagenta), img(AirHockeyAssets.particles)]);
    final sheetImg = results[4];
    fx = Fx(sheet: sheetImg == null ? null : SpriteSheet(image: sheetImg, srcSize: Vector2(sheetImg.width / 3, sheetImg.height / 2)), unit: unit);

    arena = ArenaComponent(unit: unit, glass: results[0], bottomColor: colorOfSeat(bottomSeat), topColor: colorOfSeat(1 - bottomSeat));
    world.add(arena);
    world.add(fx.ambient(worldSize));

    puck = PuckComponent(unit: unit, radiusUnits: initial.table.puckRadius, sprite: results[1] == null ? null : Sprite(results[1]!));
    puck.position = toView(initial.puck.x, initial.puck.y);
    world.add(PuckTrailComponent(puck: puck, unit: unit));
    world.add(puck);

    for (final seat in [0, 1]) {
      final mine = seat == bottomSeat;
      final sprite = mine ? results[2] : results[3];
      final p = PaddleComponent(unit: unit, radiusUnits: initial.table.paddleRadius, color: colorOfSeat(seat), sprite: sprite == null ? null : Sprite(sprite), isLocal: seat == mySeat);
      final ps = initial.paddles[seat];
      p.position = toView(ps.x, ps.y);
      paddles[seat] = p;
      world.add(p);
    }

    final seat = mySeat;
    if (seat != null && !initial.finished) {
      final ps = initial.paddles[seat];
      predictor = LocalPaddlePredictor(seat: seat, start: TablePoint(ps.x, ps.y));
    }

    _applyState(initial, isTick: true);
    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(AirHockeyAudio.instance.init());
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input: relative drag anywhere on the viewer's half
  // ---------------------------------------------------------------------------

  bool get canControl => predictor != null && !isSpectator && !(latestState.value?.finished ?? false);

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!canControl) return;
    final a = camera.globalToLocal(event.canvasStartPosition);
    final b = camera.globalToLocal(event.canvasEndPosition);
    dragBy(b.x - a.x, b.y - a.y);
  }

  /// Apply a drag delta in world pixels (view space). Exposed for tests.
  void dragBy(double worldDx, double worldDy) {
    final p = predictor;
    if (p == null || !canControl) return;
    final sign = flipped ? -1.0 : 1.0;
    p.moveTargetBy(sign * worldDx / unit, sign * worldDy / unit);
  }

  // ---------------------------------------------------------------------------
  // Frame update: prediction, send throttle, interpolation, shake
  // ---------------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    _clockMs += dt * 1000;
    final s = latestState.value;

    final p = predictor;
    if (p != null && canControl) {
      p.update(dt);
      final action = p.maybeSend(_clockMs);
      if (action != null) _send(action);
      paddles[p.seat]?.position = toView(p.predicted.x, p.predicted.y);
    }

    final sample = buffer.sample(_clockMs);
    if (sample != null) {
      puck.position = toView(sample.puck.x, sample.puck.y);
      for (var seat = 0; seat < 2 && seat < sample.paddles.length; seat++) {
        if (seat == p?.seat && canControl) continue;
        paddles[seat]?.position = toView(sample.paddles[seat].x, sample.paddles[seat].y);
      }
    }

    if (_shake > 0) {
      _shake = math.max(0, _shake - dt * 2.2);
      final amp = unit * 1.6 * _shake * _shake;
      camera.viewfinder.position = Vector2((_rng.nextDouble() - 0.5) * amp, (_rng.nextDouble() - 0.5) * amp);
    } else if (camera.viewfinder.position.length2 > 0) {
      camera.viewfinder.position = Vector2.zero();
    }

    if (s != null) {
      final sinceArrival = _clockMs - _latestArrivalMs;
      final fo = s.faceoffAt;
      final remaining = fo == null || s.finished ? null : (fo - s.elapsedMs - sinceArrival).round();
      final shown = remaining == null || remaining <= 0 ? null : remaining;
      if (shown != faceoffMs.value && (shown == null || faceoffMs.value == null || (shown - faceoffMs.value!).abs() >= 40)) faceoffMs.value = shown;
      puck.frozen = shown != null;
      final clock = s.rules.matchSeconds == 0 ? 0 : math.max(0, (s.clockMs - (s.finished ? 0 : sinceArrival)).round());
      if ((clock - clockMs.value).abs() >= 100 || clock == 0) clockMs.value = clock;
    }
  }

  void _send(Map<String, dynamic> action) {
    if (_realtimeUnsupported) return;
    try {
      channel.sendRealtime(action);
    } on UnsupportedError {
      _realtimeUnsupported = true;
      _notify(const AirHockeyNotice('This channel cannot send real-time input', icon: Icons.error_outline_rounded, color: Colors.redAccent));
    } catch (_) {
      // Transport errors surface through the socket; keep predicting.
    }
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    final s = AirHockeyState.fromJson(u.state);
    final isTick = u.events.any((e) => e.type == 'state_tick');
    _version = u.version;
    for (final e in u.events) {
      _onEvent(e, s);
    }
    _applyState(s, isTick: isTick);
  }

  void _onSnapshot(GameUpdate u) {
    final s = AirHockeyState.fromJson(u.state);
    _version = u.version;
    buffer.clear();
    puck.clearTrail();
    final p = predictor;
    if (p != null) {
      final ps = s.paddles[p.seat];
      p.pending.clear();
      p.predicted = TablePoint(ps.x, ps.y);
      p.setTarget(p.predicted);
    }
    _applyState(s, isTick: true);
  }

  void _applyState(AirHockeyState s, {required bool isTick}) {
    latestState.value = s;
    _latestArrivalMs = _clockMs;
    if (s.finished && finish.value == null) _finish(s);
    if (isTick) {
      buffer.add(TickSample(atMs: _clockMs, puck: s.puck, paddles: s.paddles, elapsedMs: s.elapsedMs));
    }
    final p = predictor;
    if (p != null && p.seat < s.paddles.length) {
      final acked = p.reconcile(s.paddles[p.seat], _clockMs);
      if (acked && p.latencyMs != null) {
        final ms = p.latencyMs!.round();
        if (latencyMs.value == null || (latencyMs.value! - ms).abs() >= 3) latencyMs.value = ms;
      }
    }
  }

  void _onEvent(SequencedEvent e, AirHockeyState next) {
    switch (e.type) {
      case 'puck_hit':
        final seat = e.seat ?? 0;
        final speed = (e.payload['speed'] as num?)?.toDouble() ?? 60;
        final at = toView((e.payload['x'] as num?)?.toDouble() ?? next.puck.x, (e.payload['y'] as num?)?.toDouble() ?? next.puck.y);
        paddles[seat]?.hit();
        puck.flash();
        puck.trailColor = colorOfSeat(seat);
        final paddlePos = paddles[seat]?.position ?? at;
        world.add(fx.sparks(at, color: colorOfSeat(seat), direction: at - paddlePos, speed: (0.5 + speed / AirHockeyPhysics.puckMaxSpeed).clamp(0.5, 1.6)));
        world.add(fx.ringPulse(at, color: colorOfSeat(seat), scale: 0.6));
        AirHockeyAudio.instance.play('hit', volumeScale: (0.35 + speed / AirHockeyPhysics.puckMaxSpeed).clamp(0.35, 1.0), clock: _clockMs / 1000);
      case 'wall_bounce':
        final at = toView((e.payload['x'] as num?)?.toDouble() ?? next.puck.x, (e.payload['y'] as num?)?.toDouble() ?? next.puck.y);
        world.add(fx.sparks(at, color: NeonPalette.white, count: 8, speed: 0.6));
        AirHockeyAudio.instance.play('wall', volumeScale: 0.6, clock: _clockMs / 1000);
      case 'goal':
        final scorer = e.seat ?? 0;
        final conceder = 1 - scorer;
        final mouth = toView(AirHockeyPhysics.tableWidth / 2, conceder == 1 ? 0 : AirHockeyPhysics.tableHeight);
        final upward = mouth.y < worldSize.y / 2;
        final color = colorOfSeat(scorer);
        world.add(fx.goalExplosion(mouth, color: color, upward: !upward));
        world.add(fx.ringPulse(mouth, color: color, scale: 2.2));
        if (!GraphicsSettings.instance.reduceEffects) {
          world.add(ScreenFlash(size: worldSize, color: color));
          _shake = 1;
        }
        arena.flashGoal(color);
        puck.clearTrail();
        final score = (e.payload['score'] as List<dynamic>?)?.map((x) => (x as num).toInt()).toList() ?? [next.seats[0].score, next.seats[1].score];
        final who = scorer == mySeat ? 'GOAL' : (isSpectator ? '${next.seatAt(scorer).displayName} scores' : 'GOAL AGAINST');
        _notify(AirHockeyNotice(who, color: color, big: true, icon: Icons.sports_hockey_rounded));
        AirHockeyAudio.instance.play('goal');
        if (isSpectator) _notify(AirHockeyNotice('${score[0]} : ${score[1]}', icon: Icons.scoreboard_rounded, color: color));
      case 'faceoff':
        _notify(const AirHockeyNotice('GO', color: NeonPalette.white, big: true));
      case 'sudden_death':
        _notify(const AirHockeyNotice('SUDDEN DEATH', color: Colors.amberAccent, big: true, icon: Icons.bolt_rounded));
      case 'player_forfeited':
        _notify(AirHockeyNotice('${next.seatOrNull(e.seat)?.displayName ?? 'Player'} left the match', icon: Icons.logout_rounded, color: Colors.redAccent));
      case 'match_finished':
        _finish(next);
      case 'state_tick':
        break;
    }
  }

  void _finish(AirHockeyState s) {
    if (finish.value != null) return;
    final winner = s.winnerSeat;
    finish.value = AirHockeyFinish(winnerSeat: winner, reason: s.finishReason ?? 'goals', score: [s.seats[0].score, s.seats[1].score]);
    puck.frozen = true;
    faceoffMs.value = null;
    final iWon = winner != null && winner == mySeat;
    if (winner != null && (iWon || isSpectator)) {
      world.add(fx.confetti(worldSize, accent: colorOfSeat(winner)));
    }
    if (winner != null) arena.flashGoal(colorOfSeat(winner));
    AirHockeyAudio.instance.play(iWon || isSpectator ? 'victory' : 'goal');
  }

  void _notify(AirHockeyNotice n) => notice.value = n;
}
