import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/aim_component.dart';
import 'components/ball_component.dart';
import 'components/course_component.dart';
import 'components/fx.dart';
import 'mini_golf_assets.dart';
import 'mini_golf_audio.dart';
import 'model/mini_golf_state.dart';
import 'model/stroke.dart';

/// Visual configuration chosen from equipped cosmetics.
class MiniGolfCosmetics {
  const MiniGolfCosmetics({this.ballSkin = 'white'});

  /// 'white' or 'gold' (cosmetic id `mini_golf_paradise.ball.gold`), applied to the local player's ball.
  final String ballSkin;
}

/// UI-facing notifications the HUD renders as toasts.
class MiniGolfNotice {
  const MiniGolfNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

enum BannerKind { holeIntro, holeInOne, matchOver }

/// Full-width banner the screen animates (hole transitions, hole in one, match over).
class MiniGolfBanner {
  const MiniGolfBanner({required this.kind, required this.title, this.subtitle});
  final BannerKind kind;
  final String title;
  final String? subtitle;
}

/// The Flame scene for Mini Golf Paradise. World units are course units x [unit].
///
/// Authority model: this class never decides an outcome. It submits `putt` actions
/// through [GameChannel]; the server simulates and returns keyframes, which this
/// class replays before snapping every ball to the authoritative state.
class MiniGolfGame extends FlameGame {
  MiniGolfGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final MiniGolfCosmetics cosmetics;

  /// World pixels per course unit.
  static const double unit = 10;

  late CourseComponent courseView;
  late AimComponent aim;
  late Fx fx;
  final Map<int, BallComponent> balls = {};

  final ValueNotifier<MiniGolfState?> displayState = ValueNotifier(null);
  final ValueNotifier<MiniGolfState?> latestState = ValueNotifier(null);
  final ValueNotifier<MiniGolfNotice?> notice = ValueNotifier(null);
  final ValueNotifier<MiniGolfBanner?> banner = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<bool> replaying = ValueNotifier(false);
  final ValueNotifier<bool> scorecardVisible = ValueNotifier(false);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingTimeout;
  async.Timer? _scorecardTimer;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final initial = MiniGolfState.fromJson(session.initialState);
    _version = session.initialVersion;
    final q = GraphicsSettings.instance.current;

    final results = await Future.wait([
      _tryLoad(MiniGolfAssets.turf, q),
      _tryLoad(MiniGolfAssets.sand, q),
      _tryLoad(MiniGolfAssets.water, q),
      _tryLoad(MiniGolfAssets.rockWall, q),
      _tryLoad(MiniGolfAssets.flag, q),
      _tryLoad(MiniGolfAssets.particles, q),
      _tryLoad(MiniGolfAssets.ballWhite, q),
      if (cosmetics.ballSkin != 'white') _tryLoad(MiniGolfAssets.ball(cosmetics.ballSkin), q),
    ]);
    final skin = CourseSkin(turf: results[0], sand: results[1], water: results[2], rock: results[3], flag: results[4]);
    final sheet = results[5];
    fx = Fx(sheet: sheet == null ? null : SpriteSheet(image: sheet, srcSize: Vector2(sheet.width / 3, sheet.height / 2)), unit: unit);
    final whiteSprite = results[6] == null ? null : Sprite(results[6]!);
    final skinImg = results.length > 7 ? results[7] : null;
    final mySprite = skinImg == null ? whiteSprite : Sprite(skinImg);

    camera = CameraComponent.withFixedResolution(world: world, width: initial.course.width * unit, height: initial.course.height * unit);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    courseView = CourseComponent(course: initial.course, skin: skin, unit: unit);
    world.add(courseView);
    world.add(fx.ambient(courseView.size));

    for (final seat in initial.seats) {
      final b = BallComponent(seat: seat.seat, ringColor: ZpColors.seat(seat.seat), sprite: seat.seat == mySeat ? mySprite : whiteSprite, unit: unit);
      balls[seat.seat] = b;
      world.add(b);
    }

    aim = AimComponent(
      unit: unit,
      ballPosition: () => displayState.value?.seatOrNull(mySeat)?.position ?? initial.course.tee,
      course: () => courseView.course,
      obstacleValues: () => courseView.obstacleValues,
      onPutt: (angle, power) => unawaited(requestPutt(angle, power)),
      seatColor: ZpColors.seat(mySeat ?? 0),
    )
      ..priority = 40
      ..size = courseView.size.clone();
    world.add(aim);

    _applyCourse(initial);
    _syncBalls(initial);
    displayState.value = initial;
    latestState.value = initial;
    _refreshInteractivity(initial);
    if (initial.finished) _showMatchOver(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(MiniGolfAudio.instance.init());
  }

  /// Loads an image, returning null (procedural fallback) when it is not bundled.
  Future<ui.Image?> _tryLoad(String logical, GraphicsQuality q) async {
    try {
      final key = ZpAssets.key(logical, quality: q);
      final img = await ZpAssets.loadUiImage(logical, quality: q);
      images.add(key, img);
      return img;
    } catch (e) {
      debugPrint('mini_golf_paradise: $logical missing, using procedural art');
      return null;
    }
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    _pendingTimeout?.cancel();
    _scorecardTimer?.cancel();
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  bool get canAct {
    final s = displayState.value;
    if (s == null || isSpectator || busy.value || awaitingServer.value || s.finished) return false;
    final me = s.seatOrNull(mySeat);
    return me != null && s.turnSeat == mySeat && !me.holed && !me.forfeited;
  }

  /// Submit a putt. [angle] in radians (y down), [power] in (0, 1].
  Future<void> requestPutt(double angle, double power) async {
    if (!canAct) return;
    final p = power.clamp(0.01, 1.0);
    awaitingServer.value = true;
    aim.enabled = false;
    MiniGolfAudio.instance.play('putt', volume: 0.4 + 0.6 * p);
    _pendingTimeout?.cancel();
    _pendingTimeout = async.Timer(const Duration(seconds: 5), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        _refreshInteractivity(displayState.value);
        channel.resync();
      }
    });
    try {
      await channel.submit({'type': 'putt', 'angle': angle, 'power': p}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _refreshInteractivity(displayState.value);
      _notify(MiniGolfNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('version_mismatch')) return 'Syncing with the course';
    if (s.contains('bad_power') || s.contains('bad_angle')) return 'Drag back from your ball to putt';
    if (s.contains('inactive_seat')) return 'You have finished this hole';
    return 'Action rejected';
  }

  void toggleScorecard() {
    _scorecardTimer?.cancel();
    scorecardVisible.value = !scorecardVisible.value;
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = MiniGolfState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = MiniGolfState.fromJson(u.state);
    _version = u.version;
    _pendingTimeout?.cancel();
    latestState.value = s;
    displayState.value = s;
    _applyCourse(s);
    _syncBalls(s);
    awaitingServer.value = false;
    busy.value = false;
    replaying.value = false;
    aim.cancel();
    _refreshInteractivity(s);
    if (s.finished) _showMatchOver(s);
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
      _refreshInteractivity(displayState.value);
    }
  }

  Future<void> _animate(GameUpdate u) async {
    final next = MiniGolfState.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'stroke_resolved':
          _pendingTimeout?.cancel();
          awaitingServer.value = false;
          await _playStroke(StrokeResolved.fromJson(e.payload), prev);
        case 'hole_in_one':
          final name = e.seat == mySeat ? 'You' : _name(prev, e.seat);
          banner.value = MiniGolfBanner(kind: BannerKind.holeInOne, title: 'HOLE IN ONE', subtitle: name);
          world.add(fx.confetti(courseView.size, accent: ZpColors.seat(e.seat ?? 0)));
          MiniGolfAudio.instance.play('victory');
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          banner.value = null;
        case 'penalty':
          final reason = e.payload['reason'];
          final who = e.seat == mySeat ? 'You' : _name(prev, e.seat);
          if (reason == 'water') {
            _notify(MiniGolfNotice('$who: water, +1 penalty stroke', icon: Icons.water_drop_rounded, color: const Color(0xFF3FC2E8)));
          } else {
            _notify(MiniGolfNotice('$who picked up at max strokes', icon: Icons.flag_rounded, color: ZpColors.danger));
          }
        case 'hole_completed':
          _scorecardTimer?.cancel();
          scorecardVisible.value = true;
          await Future<void>.delayed(const Duration(seconds: 3));
          scorecardVisible.value = false;
        case 'next_hole':
          _applyCourse(next);
          for (final s in next.seats) {
            balls[s.seat]?.snapTo(next.course.tee);
          }
          _syncBalls(next);
          banner.value = MiniGolfBanner(kind: BannerKind.holeIntro, title: 'Hole ${next.holeIndex + 1}: ${next.course.name}', subtitle: 'Par ${next.course.par}');
          await Future<void>.delayed(const Duration(milliseconds: 1600));
          banner.value = null;
        case 'turn_changed':
          if (e.seat == mySeat && !next.finished) MiniGolfAudio.instance.play('ui_tap');
        case 'turn_timeout':
          _notify(MiniGolfNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(MiniGolfNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'match_finished':
          _showMatchOver(next);
      }
    }
    _version = u.version;
    displayState.value = next;
    _applyCourse(next);
    _syncBalls(next);
    _refreshInteractivity(next);
  }

  /// Replay the keyframes, then land the ball at the authoritative final position.
  Future<void> _playStroke(StrokeResolved sr, MiniGolfState? prev) async {
    final ball = balls[sr.seat];
    if (ball == null) return;
    replaying.value = true;
    ball.visible = true;
    ball.scale = Vector2.all(1);
    final rep = _StrokeReplayer(stroke: sr, ball: ball, course: courseView, fx: fx, unit: unit);
    world.add(rep);
    await rep.done;
    rep.removeFromParent();
    if (sr.water) {
      final last = sr.frames.isEmpty ? sr.finalPosition : sr.frames.last.position;
      world.add(fx.splash(Vector2(last.x * unit, last.y * unit)));
      MiniGolfAudio.instance.play('water');
      ball.visible = false;
      await Future<void>.delayed(const Duration(milliseconds: 650));
      ball.snapTo(sr.finalPosition);
    } else if (sr.holed) {
      final hole = courseView.course.hole;
      world.add(fx.ringPulse(Vector2(hole.x * unit, hole.y * unit), color: ZpColors.goldLight));
      world.add(fx.holeSparkle(Vector2(hole.x * unit, hole.y * unit)));
      MiniGolfAudio.instance.play('hole');
      await ball.dropIntoCup();
    } else {
      ball.snapTo(sr.finalPosition);
    }
    replaying.value = false;
  }

  void _showMatchOver(MiniGolfState s) {
    if (s.placements.isEmpty) return;
    final winner = s.seatOrNull(s.placements.first);
    final mine = winner?.seat == mySeat;
    banner.value = MiniGolfBanner(kind: BannerKind.matchOver, title: mine ? 'You win!' : '${winner?.displayName ?? 'Player'} wins', subtitle: 'Match over');
    world.add(fx.confetti(courseView.size, accent: ZpColors.seat(winner?.seat ?? 0)));
    MiniGolfAudio.instance.play('victory');
    scorecardVisible.value = true;
  }

  String _name(MiniGolfState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  void _notify(MiniGolfNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  void _applyCourse(MiniGolfState s) {
    final c = s.course;
    if (courseView.course.id != c.id || courseView.size.x != c.width * unit || courseView.size.y != c.height * unit) {
      courseView.course = c;
      aim.size = courseView.size.clone();
      camera.viewport = FixedResolutionViewport(resolution: Vector2(c.width * unit, c.height * unit));
      camera.viewfinder.anchor = Anchor.topLeft;
      camera.viewfinder.position = Vector2.zero();
    }
    // Obstacles rest at the state's clock between strokes so the aim guide is exact.
    courseView.obstacleValues = c.obstacleValuesAt(s.obstaclePhase);
  }

  void _syncBalls(MiniGolfState s) {
    for (final seat in s.seats) {
      final b = balls[seat.seat];
      if (b == null) continue;
      if (seat.forfeited || seat.holed) {
        b.visible = false;
        continue;
      }
      b.snapTo(seat.position);
      b.highlighted = s.turnSeat == seat.seat && !s.finished;
    }
  }

  void _refreshInteractivity(MiniGolfState? s) {
    if (s == null) return;
    aim.enabled = canAct;
    if (!aim.enabled) aim.cancel();
  }
}

/// Drives one ball and the course obstacles through server keyframes in real time,
/// firing bounce effects at their recorded times.
class _StrokeReplayer extends Component {
  _StrokeReplayer({required this.stroke, required this.ball, required this.course, required this.fx, required this.unit});

  final StrokeResolved stroke;
  final BallComponent ball;
  final CourseComponent course;
  final Fx fx;
  final double unit;
  final _done = async.Completer<void>();
  double _t = 0;
  int _bounceIdx = 0;

  Future<void> get done => _done.future;

  @override
  void update(double dt) {
    super.update(dt);
    if (_done.isCompleted) return;
    _t += dt;
    final (p, obs) = stroke.sample(_t);
    ball.showAt(p);
    if (obs.isNotEmpty) course.obstacleValues = obs;
    while (_bounceIdx < stroke.bounces.length && stroke.bounces[_bounceIdx].t <= _t) {
      final b = stroke.bounces[_bounceIdx++];
      parent?.add(fx.impactPuff(Vector2(b.position.x * unit, b.position.y * unit), color: b.kind == BounceKind.obstacle ? const Color(0xFFE2B97A) : const Color(0xFFE9E2CC)));
      MiniGolfAudio.instance.play('bounce', volume: 0.7);
    }
    if (_t >= stroke.duration) {
      if (stroke.frames.isNotEmpty) ball.showAt(stroke.frames.last.position);
      _done.complete();
    }
  }
}
