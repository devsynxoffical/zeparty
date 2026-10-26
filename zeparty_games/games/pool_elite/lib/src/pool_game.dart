import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/aim_guide_component.dart';
import 'components/ball_component.dart';
import 'components/cue_component.dart';
import 'components/fx.dart';
import 'components/input_layer.dart';
import 'components/table_component.dart';
import 'model/aim.dart';
import 'model/pool_state.dart';
import 'model/shot_replay.dart';
import 'pool_assets.dart';
import 'pool_audio.dart';

/// Visual configuration chosen from equipped cosmetics.
class PoolCosmetics {
  const PoolCosmetics({this.cue = 'classic', this.table = 'classic'});

  /// 'classic' or 'ebony' (cosmetic id `pool_elite.cue.ebony`).
  final String cue;

  /// 'classic' or 'ruby' (cosmetic id `pool_elite.table.ruby`).
  final String table;
}

/// UI-facing notifications the HUD renders (toasts, banners).
class PoolNotice {
  const PoolNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// Match end summary for the victory presentation.
class PoolFinish {
  const PoolFinish({required this.winnerSeat, required this.reason, required this.placements});
  final int winnerSeat;
  final String reason;
  final List<int> placements;
}

enum _DragMode { none, aim, place }

/// The Flame scene for 8 Ball Pool Elite. World units are table units x [unit]
/// (the cloth is 2000 x 1000 world pixels), origin at the top left of the cloth.
///
/// Authority model: this class never decides the outcome of anything. It sends
/// `shot` and `place_cue` actions through [GameChannel], queues incoming server
/// updates, replays the keyframes of every `shot_resolved` event, then snaps
/// each ball to the authoritative state.
class PoolGame extends FlameGame {
  PoolGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final PoolCosmetics cosmetics;

  /// World pixels per table unit.
  static const double unit = 10;

  /// Rail width in table units.
  static const double railUnits = 9;

  late PoolTable table;
  late TableComponent tableComponent;
  late CueComponent cue;
  late AimGuideComponent guide;
  late Fx fx;
  final Map<int, BallComponent> balls = {};

  final ValueNotifier<PoolState?> displayState = ValueNotifier(null);
  final ValueNotifier<PoolState?> latestState = ValueNotifier(null);
  final ValueNotifier<PoolNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<bool> replaying = ValueNotifier(false);
  final ValueNotifier<PoolFinish?> finish = ValueNotifier(null);

  /// Aim angle in radians (table coordinates, y down).
  final ValueNotifier<double> aimAngle = ValueNotifier(0);

  /// Loaded power 0..1.
  final ValueNotifier<double> power = ValueNotifier(0.5);

  /// Spin: x = english (-1..1), y = follow (+) / draw (-).
  final ValueNotifier<Offset> spin = ValueNotifier(Offset.zero);

  /// Client-side legality of the cue ball placement being dragged (feedback only).
  final ValueNotifier<bool?> placementValid = ValueNotifier(null);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _snapshotGen = 0;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingTimeout;

  // Replay state
  ShotReplay? _replay;
  double _replayT = 0;
  int _collisionIdx = 0;
  final Set<int> _dropped = {};
  async.Completer<void>? _replayDone;
  double _zoomFactor = 1;
  double? _baseZoom;
  Vector2? _zoomTarget;

  // Input state
  _DragMode _drag = _DragMode.none;
  double _lastDragAngle = 0;
  Vector2? _placement;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  Vector2 get worldCenter => Vector2(table.width * unit / 2, table.height * unit / 2);
  Vector2 toWorld(double x, double y) => Vector2(x * unit, y * unit);

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final initial = PoolState.fromJson(session.initialState);
    table = initial.table;
    _version = session.initialVersion;

    camera = CameraComponent.withFixedResolution(world: world, width: (table.width + 2 * railUnits) * unit, height: (table.height + 2 * railUnits) * unit);
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = worldCenter;

    final q = GraphicsSettings.instance.current;
    final results = await Future.wait([
      _tryLoad(PoolAssets.felt, q),
      _tryLoad(PoolAssets.railWood, q),
      _tryLoad(PoolAssets.particles, q),
      _tryLoad(PoolAssets.cue(cosmetics.cue), q),
      for (var i = 0; i <= 15; i++) _tryLoad(PoolAssets.ball(i), q),
    ]);
    final sheetImg = results[2];
    fx = Fx(sheet: sheetImg == null ? null : SpriteSheet(image: sheetImg, srcSize: Vector2(sheetImg.width / 3, sheetImg.height / 2)), unit: unit);

    tableComponent = TableComponent(table: table, skin: TableSkin.forCosmetic(cosmetics.table, felt: results[0], railWood: results[1]), unit: unit, rail: railUnits);
    world.add(tableComponent);
    world.add(fx.ambientDust(Vector2(table.width * unit, table.height * unit)));

    final r = table.ballRadius * unit;
    for (var i = 0; i <= 15; i++) {
      final b = BallComponent(id: i, radius: r, image: results[4 + i]);
      balls[i] = b;
      world.add(b);
    }
    guide = AimGuideComponent(scale: unit, ballRadius: table.ballRadius);
    world.add(guide);
    cue = CueComponent(image: results[3], ballRadius: r, skin: cosmetics.cue);
    cue.onStrikeImpact = _onStrikeImpact;
    world.add(cue);
    world.add(InputLayer(
      origin: Vector2(-railUnits * unit, -railUnits * unit),
      extent: Vector2((table.width + 2 * railUnits) * unit, (table.height + 2 * railUnits) * unit),
      onDragStarted: _onDragStart,
      onDragMoved: _onDragMove,
      onDragFinished: _onDragEnd,
      onTapped: _onTap,
    ));

    _syncBalls(initial);
    displayState.value = initial;
    latestState.value = initial;
    _resetAim(initial);
    _refreshInteractivity(initial);
    if (initial.finished) _showFinished(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(PoolAudio.instance.init());
  }

  /// Loads an image, returning null (procedural fallback) when it is not bundled.
  Future<ui.Image?> _tryLoad(String logical, GraphicsQuality q) async {
    try {
      return await images.load(ZpAssets.key(logical, quality: q));
    } catch (e) {
      debugPrint('pool_elite: $logical missing, using procedural art');
      return null;
    }
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    _pendingTimeout?.cancel();
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  bool get canAct {
    final s = displayState.value;
    return s != null && !isSpectator && !busy.value && !awaitingServer.value && !s.finished && s.turnSeat == mySeat && _replay == null;
  }

  Vector2 _cueWorld() {
    final s = displayState.value!;
    final c = s.cueBall;
    return toWorld(c.x, c.y);
  }

  void _onDragStart(Vector2 w) {
    if (!canAct) return;
    final s = displayState.value!;
    final cw = _placement ?? _cueWorld();
    final r = table.ballRadius * unit;
    if (s.ballInHand && (w - cw).length < r * 3.2) {
      _drag = _DragMode.place;
      _updatePlacement(w);
      return;
    }
    _drag = _DragMode.aim;
    _lastDragAngle = math.atan2(w.y - cw.y, w.x - cw.x);
  }

  void _onDragMove(Vector2 w) {
    if (_drag == _DragMode.none) return;
    if (_drag == _DragMode.place) {
      _updatePlacement(w);
      return;
    }
    final cw = _placement ?? _cueWorld();
    final a = math.atan2(w.y - cw.y, w.x - cw.x);
    var delta = a - _lastDragAngle;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    // Far from the ball a finger travels many pixels per degree: fine control for free.
    _lastDragAngle = a;
    setAimAngle(aimAngle.value + delta);
  }

  void _onDragEnd() {
    final mode = _drag;
    _drag = _DragMode.none;
    if (mode == _DragMode.place) {
      final p = _placement;
      final valid = placementValid.value ?? false;
      if (p != null && valid) {
        unawaited(requestPlaceCue(p.x / unit, p.y / unit));
      } else {
        _placement = null;
        placementValid.value = null;
        final s = displayState.value;
        if (s != null) _syncBalls(s);
      }
    }
  }

  void _onTap(Vector2 w) {
    if (!canAct) return;
    final cw = _cueWorld();
    if ((w - cw).length < table.ballRadius * unit * 2) return;
    setAimAngle(math.atan2(w.y - cw.y, w.x - cw.x));
    PoolAudio.instance.play('ui_tap', intensity: 0.4);
  }

  void _updatePlacement(Vector2 w) {
    final s = displayState.value!;
    final r = table.ballRadius;
    var x = (w.x / unit).clamp(r, table.width - r);
    final y = (w.y / unit).clamp(r, table.height - r);
    if (s.cueBehindHeadString) x = math.min(x, table.headStringX);
    _placement = Vector2(x * unit, y * unit);
    final valid = !table.placementBlocked(x, y, s.balls);
    placementValid.value = valid;
    final b = balls[0]!;
    b.position.setFrom(_placement!);
    b.highlight = true;
    _updateGuide();
  }

  /// Sets the aim angle (radians) and refreshes the guide and cue.
  void setAimAngle(double a) {
    aimAngle.value = a;
    cue.angle = a;
    _updateGuide();
  }

  void setPower(double p) {
    power.value = p.clamp(0.0, 1.0);
    cue.power = power.value;
    guide.power = power.value;
  }

  void setSpin(Offset s) {
    spin.value = Offset(s.dx.clamp(-1.0, 1.0), s.dy.clamp(-1.0, 1.0));
  }

  void _updateGuide() {
    final s = displayState.value;
    if (s == null) return;
    final c = _placement;
    final state = c == null ? s : _withCueAt(s, c.x / unit, c.y / unit);
    guide.preview = computeAim(state, aimAngle.value, seat: mySeat);
    guide.power = power.value;
    cue.position = c ?? _cueWorld();
  }

  PoolState _withCueAt(PoolState s, double x, double y) => PoolState(
        rules: s.rules,
        table: s.table,
        seats: s.seats,
        balls: [for (final b in s.balls) b.id == 0 ? PoolBall(id: 0, x: x, y: y, pocketed: false) : b],
        turnSeat: s.turnSeat,
        phase: s.phase,
        openTable: s.openTable,
        ballInHand: s.ballInHand,
        cueBehindHeadString: s.cueBehindHeadString,
        shotCount: s.shotCount,
        lastShot: s.lastShot,
        winnerSeat: s.winnerSeat,
        finishReason: s.finishReason,
        placements: s.placements,
        version: s.version,
        turnDeadline: s.turnDeadline,
      );

  /// Submits the shot with the current aim, power and spin.
  Future<void> shoot() async {
    if (!canAct) return;
    final p = power.value;
    if (p < 0.02) return;
    awaitingServer.value = true;
    guide.visible = false;
    balls[0]!.highlight = false;
    cue.strike(p);
    _pendingTimeout?.cancel();
    _pendingTimeout = async.Timer(const Duration(seconds: 5), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        channel.resync();
      }
    });
    try {
      await channel.submit({
        'type': 'shot',
        'angle': aimAngle.value,
        'power': p,
        'spin': {'x': spin.value.dx, 'y': spin.value.dy},
      }, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _notify(PoolNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      final s = displayState.value;
      if (s != null) _refreshInteractivity(s);
    }
  }

  void _onStrikeImpact() {
    PoolAudio.instance.play('cue_hit', intensity: 0.4 + cue.power * 0.6);
    final cw = _cueWorld();
    final a = aimAngle.value;
    world.add(fx.chalkPuff(cw - Vector2(math.cos(a), math.sin(a)) * table.ballRadius * unit, a));
  }

  /// Submits a cue ball placement (ball in hand). Coordinates in table units.
  Future<void> requestPlaceCue(double x, double y) async {
    final s = displayState.value;
    if (s == null || !canAct || !s.ballInHand) return;
    awaitingServer.value = true;
    try {
      await channel.submit({'type': 'place_cue', 'x': x, 'y': y}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _placement = null;
      placementValid.value = null;
      _syncBalls(s);
      _notify(PoolNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('bad_placement')) return 'The cue ball cannot go there';
    if (s.contains('behind_head_string')) return 'Place the cue ball behind the head string';
    if (s.contains('not_ball_in_hand')) return 'The cue ball is not in hand';
    if (s.contains('version_mismatch')) return 'Syncing with the table';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = PoolState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _snapshotGen++;
    _queue.clear();
    _abortReplay();
    final s = PoolState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    _placement = null;
    placementValid.value = null;
    _syncBalls(s);
    awaitingServer.value = false;
    busy.value = false;
    _resetAim(s);
    _refreshInteractivity(s);
    if (s.finished) _showFinished(s);
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    busy.value = true;
    try {
      while (_queue.isNotEmpty) {
        final u = _queue.removeFirst();
        await _animate(u);
      }
    } finally {
      busy.value = false;
      _draining = false;
    }
  }

  Future<void> _animate(GameUpdate u) async {
    final next = PoolState.fromJson(u.state);
    final prev = displayState.value;
    final gen = _snapshotGen;
    for (final e in u.events) {
      if (_snapshotGen != gen) return; // a snapshot replaced everything mid-animation
      switch (e.type) {
        case 'cue_placed':
          _pendingTimeout?.cancel();
          awaitingServer.value = false;
          _placement = null;
          placementValid.value = null;
          final x = (e.payload['x'] as num).toDouble();
          final y = (e.payload['y'] as num).toDouble();
          balls[0]!.moveTo(toWorld(x, y));
          balls[0]!.hidden = false;
          world.add(fx.ringPulse(toWorld(x, y), color: ZpColors.goldLight));
        case 'shot_resolved':
          _pendingTimeout?.cancel();
          awaitingServer.value = false;
          await _playShot(e, prev);
        case 'groups_assigned':
          final g = e.payload['group'] as String?;
          final to = (e.payload['assignedTo'] as num?)?.toInt() ?? e.seat;
          final mine = to == mySeat;
          final myGroup = mine ? g : (g == 'solids' ? 'stripes' : 'solids');
          if (!isSpectator && myGroup != null) {
            _notify(PoolNotice('You are ${myGroup == 'solids' ? 'solids' : 'stripes'}', icon: Icons.circle_rounded, color: ZpColors.goldLight));
          } else {
            _notify(PoolNotice('${_name(prev, to)} takes $g', icon: Icons.circle_rounded));
          }
        case 'ball_in_hand':
          final behind = e.payload['behindHeadString'] as bool? ?? false;
          final x = (e.payload['x'] as num?)?.toDouble();
          final y = (e.payload['y'] as num?)?.toDouble();
          if (x != null && y != null) {
            final b = balls[0]!;
            b.hidden = false;
            b.drop = 0;
            b.moveTo(toWorld(x, y));
            world.add(fx.ringPulse(toWorld(x, y), color: ZpColors.champagne));
          }
          if (e.seat == mySeat) {
            _notify(PoolNotice(behind ? 'Ball in hand behind the line' : 'Ball in hand', icon: Icons.back_hand_rounded, color: ZpColors.goldLight));
          }
        case 'eight_respotted':
          final x = (e.payload['x'] as num).toDouble();
          final y = (e.payload['y'] as num).toDouble();
          final b = balls[8]!;
          b.hidden = false;
          b.drop = 0;
          b.moveTo(toWorld(x, y));
          world.add(fx.ringPulse(toWorld(x, y), color: Colors.white));
          _notify(const PoolNotice('8 ball respotted', icon: Icons.replay_rounded));
          await Future<void>.delayed(const Duration(milliseconds: 350));
        case 'continue_turn':
          if (e.seat == mySeat) _notify(const PoolNotice('Shoot again', icon: Icons.replay_rounded, color: ZpColors.goldLight));
        case 'turn_changed':
          if (e.seat == mySeat && !(prev?.ballInHand ?? false) && !(next.ballInHand)) {
            _notify(const PoolNotice('Your shot', icon: Icons.sports_rounded, color: ZpColors.goldLight));
          }
        case 'turn_timeout':
          _notify(PoolNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(PoolNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'match_finished':
          break;
      }
    }
    if (_snapshotGen != gen) return;
    _version = u.version;
    displayState.value = next;
    _placement = null;
    placementValid.value = null;
    _syncBalls(next);
    if (next.turnSeat != prev?.turnSeat || next.ballInHand) _resetAim(next);
    _refreshInteractivity(next);
    if (next.finished) _showFinished(next);
  }

  Future<void> _playShot(SequencedEvent e, PoolState? prev) async {
    final replay = ShotReplay.fromJson(e.payload);
    // Opponent (or timeout) shots: swing the cue so the table reads as a real stroke.
    final shotJ = e.payload['shot'] as Map<String, dynamic>?;
    if (e.seat != mySeat || !cue.striking) {
      final angle = (shotJ?['angle'] as num?)?.toDouble() ?? aimAngle.value;
      final p = (shotJ?['power'] as num?)?.toDouble() ?? 0.5;
      // Snap the balls to the replay's first frame first (covers a cue placement we did not see).
      final first = replay.frames.isEmpty ? null : replay.frames.first;
      if (first != null) {
        for (final b in first.bodies) {
          balls[b.id]?.moveTo(toWorld(b.x, b.y));
          balls[b.id]?.hidden = false;
        }
      }
      cue.position = _cueWorldFromReplay(replay) ?? _cueWorld();
      cue.angle = angle;
      cue.visible = true;
      cue.strike(p);
    }
    guide.visible = false;
    balls[0]!.highlight = false;
    // Let the stroke land before the balls move.
    for (var i = 0; i < 40 && cue.striking; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    cue.visible = false;
    await _runReplay(replay);
    // Foul and pocket toasts after the balls settle.
    if (replay.fouls.isNotEmpty) {
      _notify(PoolNotice('Foul: ${_foulText(replay.fouls.first)}', icon: Icons.report_rounded, color: ZpColors.danger));
    } else if (replay.pocketed.isNotEmpty && e.seat != mySeat) {
      _notify(PoolNotice('${_name(prev, e.seat)} pocketed ${replay.pocketed.length == 1 ? 'a ball' : '${replay.pocketed.length} balls'}', icon: Icons.sports_rounded));
    }
  }

  Vector2? _cueWorldFromReplay(ShotReplay r) {
    final p = r.positionAt(0, 0);
    return p == null ? null : toWorld(p.x, p.y);
  }

  static String _foulText(String code) => switch (code) {
        'scratch' => 'scratch',
        'no_contact' => 'no ball hit',
        'wrong_first_contact' => 'wrong ball first',
        'no_rail' => 'no rail after contact',
        _ => code,
      };

  Future<void> _runReplay(ShotReplay replay) async {
    _replay = replay;
    _replayT = 0;
    _collisionIdx = 0;
    _dropped.clear();
    replaying.value = true;
    _replayDone = async.Completer<void>();
    if (replay.isBreak) {
      _zoomFactor = 1;
      _zoomTarget = toWorld(table.footSpot.x + table.ballRadius * 3, table.footSpot.y);
    }
    await _replayDone!.future;
  }

  void _abortReplay() {
    _replay = null;
    _zoomFactor = 1;
    _zoomTarget = null;
    replaying.value = false;
    final c = _replayDone;
    if (c != null && !c.isCompleted) c.complete();
    _replayDone = null;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final r = _replay;
    if (r != null) _stepReplay(r, dt);
    _stepCamera(dt);
  }

  void _stepReplay(ShotReplay r, double dt) {
    // Slow motion around the 8 ball drop; otherwise real time.
    var scale = 1.0;
    final t8 = r.eightDropTime;
    if (t8 != null && _replayT > t8 - 0.7 && _replayT < t8 + 0.25) scale = 0.35;
    if (GraphicsSettings.instance.reduceEffects) scale = math.max(scale, 0.7);
    _replayT += dt * scale;
    final t = _replayT;

    for (final id in r.bodyIds) {
      final b = balls[id];
      if (b == null) continue;
      final pt = r.pocketTimeOf(id);
      if (pt != null && t >= pt) {
        if (!_dropped.contains(id)) {
          _dropped.add(id);
          final entry = r.pocketedEntry(id);
          final pocket = entry == null ? null : table.pocketById(entry.pocket);
          final at = pocket == null ? b.position.clone() : toWorld(pocket.x, pocket.y);
          world.add(fx.pocketBurst(at, color: id == 0 ? ZpColors.danger : ballColor(id)));
          PoolAudio.instance.play('pocket');
        }
        final k = ((t - pt) / 0.18).clamp(0.0, 1.0);
        b.drop = k;
        if (k >= 1) b.hidden = true;
        // Slide the sprite towards the pocket centre while it shrinks.
        final entry = r.pocketedEntry(id);
        final pocket = entry == null ? null : table.pocketById(entry.pocket);
        if (pocket != null && k < 1) {
          final target = toWorld(pocket.x, pocket.y);
          b.position.setFrom(b.position + (target - b.position) * math.min(1, dt * 14));
        }
        continue;
      }
      final p = r.positionAt(id, t);
      if (p != null) b.moveTo(toWorld(p.x, p.y));
    }

    while (_collisionIdx < r.collisions.length && r.collisions[_collisionIdx].t <= t) {
      final c = r.collisions[_collisionIdx++];
      switch (c.type) {
        case 'ball':
          PoolAudio.instance.play('ball_hit', intensity: (c.speed / 120).clamp(0.2, 1.0));
        case 'cushion':
          PoolAudio.instance.play('cushion', intensity: (c.speed / 120).clamp(0.2, 1.0));
        case 'pocket':
          break; // handled with the drop animation above
      }
    }

    // Break: slow push towards the rack, then ease back as the balls spread.
    if (r.isBreak) {
      if (t < 0.6) {
        _zoomFactor = 1 + 0.14 * Curves.easeOut.transform(t / 0.6);
      } else {
        _zoomFactor = 1 + 0.14 * (1 - Curves.easeInOut.transform(((t - 0.6) / 1.4).clamp(0.0, 1.0)));
      }
    }

    if (t >= r.duration + 0.2) {
      _replay = null;
      _zoomFactor = 1;
      _zoomTarget = null;
      replaying.value = false;
      final c = _replayDone;
      _replayDone = null;
      if (c != null && !c.isCompleted) c.complete();
    }
  }

  void _stepCamera(double dt) {
    final vf = camera.viewfinder;
    if (_zoomFactor != 1 && _zoomTarget != null) {
      _baseZoom ??= vf.zoom;
      vf.zoom = _baseZoom! * _zoomFactor;
      final k = (_zoomFactor - 1) / 0.14;
      vf.position = worldCenter + (_zoomTarget! - worldCenter) * (k * 0.5);
    } else if (_baseZoom != null) {
      vf.zoom = _baseZoom!;
      vf.position = worldCenter;
      _baseZoom = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  void _syncBalls(PoolState s) {
    for (final b in s.balls) {
      final c = balls[b.id];
      if (c == null) continue;
      c.hidden = b.pocketed;
      c.drop = 0;
      if (!b.pocketed) c.position.setFrom(toWorld(b.x, b.y));
    }
  }

  void _resetAim(PoolState s) {
    if (s.finished) return;
    // Default aim: towards the nearest legal target so a fresh turn reads immediately.
    final seat = s.turnSeat;
    final c = s.cueBall;
    PoolBall? best;
    var bestD = double.infinity;
    for (final id in s.legalFirstContacts(seat)) {
      final b = s.ballById(id);
      if (b == null) continue;
      final d = (b.x - c.x) * (b.x - c.x) + (b.y - c.y) * (b.y - c.y);
      if (d < bestD) {
        bestD = d;
        best = b;
      }
    }
    aimAngle.value = best == null ? 0 : math.atan2(best.y - c.y, best.x - c.x);
    cue.angle = aimAngle.value;
    cue.position = toWorld(c.x, c.y);
  }

  void _refreshInteractivity(PoolState s) {
    final myTurn = !isSpectator && s.turnSeat == mySeat && !s.finished && _replay == null && !awaitingServer.value;
    cue.visible = myTurn && !cue.striking;
    cue.power = power.value;
    guide.visible = myTurn;
    balls[0]!.highlight = myTurn && s.ballInHand;
    if (myTurn) _updateGuide();
  }

  void _showFinished(PoolState s) {
    final w = s.winnerSeat;
    if (w == null || finish.value != null) return;
    finish.value = PoolFinish(winnerSeat: w, reason: s.finishReason ?? 'eight_ball', placements: s.placements);
    cue.visible = false;
    guide.visible = false;
    world.add(fx.confetti(Vector2(table.width * unit, table.height * unit), accent: w == mySeat ? ZpColors.goldLight : ZpColors.ruby));
    PoolAudio.instance.play('victory');
  }

  String _name(PoolState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  void _notify(PoolNotice n) => notice.value = n;
}
