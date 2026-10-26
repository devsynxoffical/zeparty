import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/aim_reticle_component.dart';
import 'components/board_component.dart';
import 'components/dart_component.dart';
import 'components/fx.dart';
import 'components/score_popup_component.dart';
import 'components/skill_meter_component.dart';
import 'darts_assets.dart';
import 'darts_audio.dart';
import 'model/darts_state.dart';
import 'model/scoring.dart';

/// Visual configuration chosen from equipped cosmetics.
class DartsCosmetics {
  const DartsCosmetics({this.dartSkin = 'steel'});

  /// 'steel' (default) or 'gold' (cosmetic id `darts_arena.dart.gold`).
  final String dartSkin;
}

/// UI-facing notifications the HUD renders (toasts, banners).
class DartsNotice {
  const DartsNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// Where the local player is in the two-phase throw gesture.
enum ThrowPhase {
  /// Nothing in progress (or not my turn).
  idle,

  /// Finger down: the reticle follows the finger with growing sway.
  aiming,

  /// Aim locked, the release meter is sweeping; tap to stop it.
  meter,

  /// Throw submitted, waiting for the server's `dart_thrown`.
  waiting,
}

/// The Flame scene for Darts Arena. World is 1000 x 1000 units with the board
/// centred at (500, 500) and a playable radius of 360 units (board units x 360).
///
/// Authority model: the client never decides where a dart lands. It submits an
/// aim point plus a release quality, queues server updates and animates their
/// events in order, then snaps the visible darts to the authoritative state.
class DartsGame extends FlameGame {
  DartsGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final DartsCosmetics cosmetics;

  static const double worldSize = 1000;
  static const double boardRadius = 360;
  static final Vector2 boardCenter = Vector2(500, 500);

  /// Maximum sway amplitude in board units, reached after a few seconds of holding.
  static const double maxSway = 0.055;

  /// The meter auto-stops after this long so a distracted player still throws.
  static const double meterTimeoutSeconds = 3.0;

  late final PositionComponent stage;
  late final BoardComponent board;
  late final AimReticleComponent reticle;
  late final SkillMeterComponent meter;
  late final Fx fx;
  Sprite? dartSprite;
  final List<DartComponent> darts = [];

  final ValueNotifier<DartsState?> displayState = ValueNotifier(null);
  final ValueNotifier<DartsState?> latestState = ValueNotifier(null);
  final ValueNotifier<DartsNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<ThrowPhase> phase = ValueNotifier(ThrowPhase.idle);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingThrowTimeout;
  final math.Random _rand = math.Random();

  // Aim gesture state (board units).
  Vector2 _aimBase = Vector2.zero();
  Vector2 _aimPoint = Vector2.zero();
  Vector2? lockedAim;
  double _holdTime = 0;
  double _meterTime = 0;

  // Camera-inspired zoom toward the last landing point.
  Vector2? _zoomPoint;
  double _zoomT = 0;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  /// Current aim in board units (base plus sway), the value sent on release.
  Vector2 get aimPoint => _aimPoint.clone();

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: worldSize, height: worldSize);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = DartsState.fromJson(session.initialState);
    _version = session.initialVersion;
    final q = GraphicsSettings.instance.current;
    final results = await Future.wait([
      _tryLoad(DartsAssets.board, q),
      _tryLoad(DartsAssets.dart(cosmetics.dartSkin), q),
      _tryLoad(DartsAssets.particles, q),
    ]);
    dartSprite = results[1] == null ? null : Sprite(results[1]!);
    final sheet = results[2];
    fx = Fx(sheet: sheet == null ? null : SpriteSheet(image: sheet, srcSize: Vector2(sheet.width / 3, sheet.height / 2)), unit: boardRadius);

    stage = PositionComponent(size: Vector2.all(worldSize), priority: 10);
    world.add(stage);
    board = BoardComponent(worldSize: Vector2.all(worldSize), boardCenter: boardCenter, radius: boardRadius, image: results[0]);
    stage.add(board);
    stage.add(fx.ambientDust(Vector2.all(worldSize)));
    reticle = AimReticleComponent(boardRadius: boardRadius)
      ..sigmaBest = sigmaFor(initial.rules.baseSigma, 1) * boardRadius
      ..sigmaWorst = sigmaFor(initial.rules.baseSigma, 0) * boardRadius
      ..position = boardCenter.clone();
    stage.add(reticle);
    meter = SkillMeterComponent(position: Vector2(worldSize - 70, 170), size: Vector2(34, 660));
    world.add(meter);
    world.add(_InputLayer(size: Vector2.all(worldSize), game: this));

    _snapDarts(initial);
    displayState.value = initial;
    latestState.value = initial;

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(DartsAudio.instance.init());
  }

  /// Loads an image, returning null (procedural fallback) when it is not bundled.
  Future<ui.Image?> _tryLoad(String logical, GraphicsQuality q) async {
    try {
      final key = ZpAssets.key(logical, quality: q);
      final img = await ZpAssets.loadUiImage(logical, quality: q);
      images.add(key, img);
      return img;
    } catch (e) {
      debugPrint('darts_arena: $logical missing, using procedural art');
      return null;
    }
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    _pendingThrowTimeout?.cancel();
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input: two-phase throw gesture
  // ---------------------------------------------------------------------------

  bool get canThrow {
    final s = displayState.value;
    if (s == null || isSpectator || busy.value || awaitingServer.value) return false;
    return s.turnSeat == mySeat && !s.finished && phase.value == ThrowPhase.idle;
  }

  /// Finger down over the scene: start positioning the reticle.
  void beginAim(Vector2 world) {
    if (!canThrow) return;
    phase.value = ThrowPhase.aiming;
    _holdTime = 0;
    _aimBase = _clampAim(board.toBoard(world));
    _aimPoint = _aimBase.clone();
    reticle
      ..visible = true
      ..locked = false
      ..fatigue = 0
      ..position = board.toWorld(_aimPoint.x, _aimPoint.y);
  }

  void updateAim(Vector2 world) {
    if (phase.value != ThrowPhase.aiming) return;
    _aimBase = _clampAim(board.toBoard(world));
  }

  /// Finger up: the sway position at this instant is the true aim. Starts the meter.
  void releaseAim() {
    if (phase.value != ThrowPhase.aiming) return;
    lockedAim = _clampAim(_aimPoint);
    reticle
      ..locked = true
      ..position = board.toWorld(lockedAim!.x, lockedAim!.y);
    phase.value = ThrowPhase.meter;
    _meterTime = 0;
    meter.start();
  }

  /// Tap during the sweep: freeze the meter and submit the throw.
  Future<void> stopMeter() async {
    if (phase.value != ThrowPhase.meter) return;
    final release = meter.stop();
    await submitThrow(lockedAim ?? Vector2.zero(), release);
  }

  /// Abort an in-progress gesture (turn change, snapshot, pause).
  void cancelAim() {
    phase.value = ThrowPhase.idle;
    lockedAim = null;
    reticle.visible = false;
    meter.hide();
  }

  Vector2 _clampAim(Vector2 p) {
    final r = p.length;
    if (r > BoardGeometry.maxAimRadius) return p * (BoardGeometry.maxAimRadius / r);
    return p;
  }

  Future<void> submitThrow(Vector2 aim, double release) async {
    final s = displayState.value;
    if (s == null || isSpectator || s.turnSeat != mySeat || s.finished) {
      cancelAim();
      return;
    }
    phase.value = ThrowPhase.waiting;
    awaitingServer.value = true;
    DartsAudio.instance.play('throw');
    _pendingThrowTimeout?.cancel();
    _pendingThrowTimeout = async.Timer(const Duration(seconds: 5), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        cancelAim();
        channel.resync();
      }
    });
    try {
      await channel.submit({
        'type': 'throw',
        'aimX': _round(aim.x),
        'aimY': _round(aim.y),
        'release': _round(release.clamp(0.0, 1.0)),
      }, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      cancelAim();
      _notify(DartsNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  static double _round(double v) => (v * 1e4).round() / 1e4;

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('version_mismatch')) return 'Syncing with the table';
    if (s.contains('bad_aim')) return 'Aim at the board';
    if (s.contains('match_finished')) return 'The match is over';
    return 'Throw rejected';
  }

  @override
  void update(double dt) {
    super.update(dt);
    switch (phase.value) {
      case ThrowPhase.aiming:
        _holdTime += dt;
        // Arm fatigue: the longer you hold, the larger the idle sway.
        final amp = math.min(maxSway, 0.006 + _holdTime * 0.012);
        final sway = Vector2(math.sin(_holdTime * 2.4) * amp, math.cos(_holdTime * 1.9) * amp * 0.8);
        _aimPoint = _aimBase + sway;
        reticle
          ..position = board.toWorld(_aimPoint.x, _aimPoint.y)
          ..fatigue = amp / maxSway;
      case ThrowPhase.meter:
        _meterTime += dt;
        if (_meterTime >= meterTimeoutSeconds) unawaited(stopMeter());
      case ThrowPhase.idle:
      case ThrowPhase.waiting:
        break;
    }
    final zp = _zoomPoint;
    if (zp != null) {
      _zoomT += dt;
      const inDur = 0.4;
      const outDur = 0.4;
      double s;
      if (_zoomT < inDur) {
        s = 1 + 0.1 * Curves.easeOut.transform(_zoomT / inDur);
      } else if (_zoomT < inDur + outDur) {
        s = 1 + 0.1 * (1 - Curves.easeInOut.transform((_zoomT - inDur) / outDur));
      } else {
        s = 1;
        _zoomPoint = null;
      }
      stage.scale = Vector2.all(s);
      stage.position = zp * (1 - s);
    }
  }

  void _zoomToward(Vector2 worldPoint) {
    if (GraphicsSettings.instance.reduceEffects) return;
    _zoomPoint = worldPoint;
    _zoomT = 0;
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = DartsState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = DartsState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    _pendingThrowTimeout?.cancel();
    awaitingServer.value = false;
    busy.value = false;
    cancelAim();
    _snapDarts(s);
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
    final next = DartsState.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'dart_thrown':
          await _animateDart(e, prev);
        case 'visit_ended':
          final score = e.payload['visitScore'] as int? ?? 0;
          final who = e.seat == mySeat ? 'You' : _name(prev, e.seat);
          if (prev != null && prev.format.isX01) {
            _notify(DartsNotice('$who scored $score', icon: Icons.sports_score_rounded, color: score >= 100 ? ZpColors.goldLight : null));
          }
          await Future<void>.delayed(const Duration(milliseconds: 450));
        case 'bust':
          _notify(DartsNotice('${e.seat == mySeat ? 'You' : _name(prev, e.seat)} bust', icon: Icons.block_rounded, color: ZpColors.danger));
        case 'leg_won':
          final legsWon = e.payload['legsWon'] as int? ?? 1;
          final toWin = e.payload['legsToWin'] as int? ?? 1;
          final color = ZpColors.seat(e.seat ?? 0);
          stage.add(fx.confetti(Vector2.all(worldSize), accent: color, count: toWin > 1 ? 70 : 120));
          _notify(DartsNotice('${_name(prev, e.seat)} wins the leg${toWin > 1 ? ' ($legsWon of $toWin)' : ''}', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
          await Future<void>.delayed(const Duration(milliseconds: 900));
        case 'leg_started':
          await _clearDarts();
          _notify(DartsNotice('Leg ${e.payload['leg']}', icon: Icons.flag_rounded));
        case 'turn_changed':
          await _clearDarts();
          cancelAim();
          if (e.seat == mySeat) {
            DartsAudio.instance.play('ui_tap');
            _notify(const DartsNotice('Your visit', icon: Icons.touch_app_rounded, color: ZpColors.goldLight));
          }
        case 'turn_timeout':
          _notify(DartsNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(DartsNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'match_finished':
          final placements = (e.payload['placements'] as List<dynamic>? ?? const []).cast<int>();
          final winner = placements.isEmpty ? null : placements.first;
          stage.add(fx.confetti(Vector2.all(worldSize), accent: ZpColors.seat(winner ?? 0)));
          DartsAudio.instance.play('victory');
          _notify(DartsNotice(winner == mySeat ? 'You win the match' : '${_name(prev, winner)} wins the match', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
      }
    }
    _version = u.version;
    displayState.value = next;
    if (next.finished) cancelAim();
    _syncDarts(next);
  }

  Future<void> _animateDart(SequencedEvent e, DartsState? prev) async {
    final landedJson = e.payload['landed'] as Map<String, dynamic>?;
    if (landedJson == null) return;
    final dart = ThrownDart.fromJson({...e.payload, 'landed': landedJson});
    final target = board.toWorld(dart.landed.x, dart.landed.y);
    final seatColor = ZpColors.seat(e.seat ?? 0);
    final comp = DartComponent(sprite: dartSprite, gold: cosmetics.dartSkin == 'gold', length: boardRadius * 0.42, seatColor: seatColor);
    darts.add(comp);
    stage.add(comp);
    if (e.seat == mySeat) {
      _pendingThrowTimeout?.cancel();
      awaitingServer.value = false;
      cancelAim();
    } else {
      DartsAudio.instance.play('throw');
    }
    final from = Vector2(boardCenter.x + (_rand.nextDouble() - 0.5) * 160, worldSize + 180);
    await comp.flyTo(target, from: from, duration: 0.5);

    if (dart.isInnerBull) {
      DartsAudio.instance.play('bullseye');
      stage.add(fx.bullseyeBurst(target));
      stage.add(fx.ringPulse(target, color: ZpColors.goldLight));
    } else if (!dart.miss) {
      DartsAudio.instance.play('hit_board');
      stage.add(fx.impact(target, color: dart.multiplier > 1 ? ZpColors.goldLight : Colors.white));
    }
    _zoomToward(target);
    final popAt = target + Vector2(0, -boardRadius * 0.22);
    if (dart.miss) {
      stage.add(ScorePopupComponent(at: popAt, text: 'MISS', color: ZpColors.textSecondary, fontSize: 44));
    } else {
      stage.add(ScorePopupComponent(at: popAt, text: dart.label, color: dart.isInnerBull ? ZpColors.goldLight : (dart.multiplier > 1 ? ZpColors.champagne : ZpColors.ivory), fontSize: dart.isInnerBull ? 64 : 52));
    }
    if (dart.bust) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      stage.add(ScorePopupComponent(at: boardCenter + Vector2(0, -boardRadius * 0.5), text: 'BUST', color: ZpColors.danger, fontSize: 72, lifespan: 1.4));
    }
    await Future<void>.delayed(const Duration(milliseconds: 420));
  }

  Future<void> _clearDarts() async {
    if (darts.isEmpty) return;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final gone = List<DartComponent>.from(darts);
    darts.clear();
    await Future.wait(gone.map((d) => d.fadeOut()));
  }

  /// Make the visible darts match the authoritative visit after animations.
  void _syncDarts(DartsState s) {
    if (darts.length == s.visit.length && !darts.any((d) => d.flying)) {
      for (var i = 0; i < darts.length; i++) {
        final target = board.toWorld(s.visit[i].landed.x, s.visit[i].landed.y);
        if ((darts[i].position - target).length > 1) darts[i].stickAt(target);
      }
      return;
    }
    _snapDarts(s);
  }

  void _snapDarts(DartsState s) {
    for (final d in darts) {
      d.removeFromParent();
    }
    darts.clear();
    for (final t in s.visit) {
      final comp = DartComponent(sprite: dartSprite, gold: cosmetics.dartSkin == 'gold', length: boardRadius * 0.42, seatColor: ZpColors.seat(s.turnSeat));
      comp.stickAt(board.toWorld(t.landed.x, t.landed.y));
      darts.add(comp);
      stage.add(comp);
    }
  }

  String _name(DartsState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';

  void _notify(DartsNotice n) => notice.value = n;
}

/// Full-scene input surface. A press starts aiming, dragging moves the reticle,
/// lifting the finger locks the aim and starts the meter, and the next tap stops it.
class _InputLayer extends PositionComponent with DragCallbacks, TapCallbacks {
  _InputLayer({required Vector2 size, required this.game}) : super(size: size, priority: 100);
  final DartsGame game;

  @override
  void onTapDown(TapDownEvent event) {
    if (game.phase.value == ThrowPhase.meter) {
      game.stopMeter();
      return;
    }
    game.beginAim(event.localPosition);
  }

  @override
  void onTapUp(TapUpEvent event) => game.releaseAim();

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (game.phase.value == ThrowPhase.idle) game.beginAim(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => game.updateAim(event.localEndPosition);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.releaseAim();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game.releaseAim();
  }
}
