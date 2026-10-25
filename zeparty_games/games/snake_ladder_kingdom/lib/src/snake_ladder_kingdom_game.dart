import 'dart:async' as async;
import 'dart:async' show Completer, StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/ambient_component.dart';
import 'components/board_component.dart';
import 'components/board_geometry.dart';
import 'components/character_component.dart';
import 'components/dice_component.dart';
import 'components/dragon_component.dart';
import 'components/fx.dart';
import 'components/ladder_component.dart';
import 'kingdom_assets.dart';
import 'kingdom_audio.dart';
import 'model/kingdom_state.dart';
import 'model/layouts.dart';

/// UI-facing notifications the HUD renders as toasts.
class KingdomNotice {
  const KingdomNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// The Flame scene for Snake & Ladder Kingdom.
///
/// Authority model: this class never decides an outcome. It submits `roll`
/// through [GameChannel], queues server updates and animates their events in
/// order, then snaps every visual to the update's state. [displayState] is the
/// last fully animated state; [latestState] the newest known server state.
class SnakeLadderKingdomGame extends FlameGame {
  SnakeLadderKingdomGame({required this.session, required this.channel});

  final GameSessionContext session;
  final GameChannel channel;

  static const double cellSize = 100;

  late final BoardGeometry geo;
  late final KingdomBoardComponent board;
  late final DiceComponent dice;
  late final Fx fx;
  final Map<int, CharacterComponent> characters = {}; // seat -> character
  final Map<Link, LadderComponent> ladders = {};
  final Map<Link, DragonComponent> dragons = {};

  final ValueNotifier<KingdomState?> displayState = ValueNotifier(null);
  final ValueNotifier<KingdomState?> latestState = ValueNotifier(null);
  final ValueNotifier<KingdomNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingRollTimeout;

  /// Images that were actually loaded (null entries fell back to procedural art).
  final Map<String, ui.Image?> loadedImages = {};

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final initial = KingdomState.fromJson(session.initialState);
    _version = session.initialVersion;
    geo = BoardGeometry(layout: initial.layout, cell: cellSize);

    camera = CameraComponent.withFixedResolution(world: world, width: geo.worldSize, height: geo.worldSize);
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = geo.worldCenter;

    final q = GraphicsSettings.instance.current;
    Future<ui.Image?> img(String logical) async {
      try {
        final i = await images.load(ZpAssets.key(logical, quality: q));
        loadedImages[logical] = i;
        return i;
      } catch (_) {
        loadedImages[logical] = null;
        return null;
      }
    }

    final results = await Future.wait<ui.Image?>([
      img(KingdomAssets.islandTile),
      img(KingdomAssets.ladder),
      img(KingdomAssets.dragonHead),
      img(KingdomAssets.dragonTail),
      img(KingdomAssets.particles),
      for (var i = 1; i <= 6; i++) img(KingdomAssets.dice(i)),
      for (final c in KingdomColor.values) img(KingdomAssets.knight(c.name)),
    ]);
    final tile = results[0];
    final ladderImg = results[1];
    final headImg = results[2];
    final tailImg = results[3];
    final particles = results[4];
    final diceImgs = results.sublist(5, 11);
    final knightImgs = results.sublist(11, 15);

    fx = Fx(sheet: particles == null ? null : SpriteSheet(image: particles, srcSize: Vector2(particles.width / 3, particles.height / 2)), cellSize: cellSize);

    world.add(AmbientComponent(geo: geo));
    board = KingdomBoardComponent(geo: geo, tileTexture: tile);
    world.add(board);
    world.add(fx.ambientMotes(Vector2.all(geo.worldSize)));

    for (final l in initial.layout.ladders) {
      final comp = LadderComponent(geo: geo, link: l, image: ladderImg);
      ladders[l] = comp;
      world.add(comp);
    }
    for (final (i, s) in initial.layout.snakes.indexed) {
      final comp = DragonComponent(geo: geo, link: s, headImage: headImg, tailImage: tailImg, index: i);
      dragons[s] = comp;
      world.add(comp);
    }

    final faces = diceImgs.every((i) => i != null) ? [for (final i in diceImgs) Sprite(i!)] : null;
    dice = DiceComponent(
      faces: faces,
      cellSize: cellSize * 0.8,
      onTap: requestRoll,
      seatColorOf: () => KingdomBoardComponent.colorOf(displayState.value?.current.color ?? KingdomColor.red),
    )..position = Vector2(geo.worldSize - geo.margin * 0.5, geo.margin + geo.gridSize + geo.margin * 0.5);
    world.add(dice);

    for (final (i, seat) in initial.seats.indexed) {
      final ch = CharacterComponent(seat: seat.seat, seatIndex: i, color: seat.color, image: knightImgs[seat.color.index], geo: geo);
      characters[seat.seat] = ch;
      world.add(ch);
    }
    _syncCharacters(initial);
    displayState.value = initial;
    latestState.value = initial;
    _refreshInteractivity(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(KingdomAudio.instance.init());
  }

  @override
  void onRemove() {
    for (final s in _subs) {
      s.cancel();
    }
    _pendingRollTimeout?.cancel();
    super.onRemove();
  }

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  Future<void> requestRoll() async {
    final s = displayState.value;
    if (s == null || isSpectator || busy.value || awaitingServer.value) return;
    if (s.turnSeat != mySeat || s.phase != KingdomPhase.roll) return;
    awaitingServer.value = true;
    dice.enabled = false;
    dice.startRolling();
    KingdomAudio.instance.play('dice_roll');
    _pendingRollTimeout?.cancel();
    _pendingRollTimeout = async.Timer(const Duration(seconds: 4), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        dice.settle(dice.face);
        channel.resync();
      }
    });
    try {
      await channel.submit({'type': 'roll'}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      dice.settle(dice.face);
      _notify(KingdomNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      KingdomAudio.instance.play('illegal_move');
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('version_mismatch')) return 'Syncing with the kingdom';
    if (s.contains('match_finished')) return 'The match is over';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = KingdomState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = KingdomState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    _syncCharacters(s);
    awaitingServer.value = false;
    busy.value = false;
    _resetCamera(immediate: true);
    if (dice.rolling) dice.settle(s.dice ?? dice.face);
    _refreshInteractivity(s);
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
    final next = KingdomState.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      final ch = characters[e.seat];
      switch (e.type) {
        case 'dice_rolled':
          final value = e.payload['value'] as int;
          _pendingRollTimeout?.cancel();
          awaitingServer.value = false;
          if (e.seat != mySeat) {
            dice.startRolling();
            KingdomAudio.instance.play('dice_roll');
          }
          await dice.settle(value);
          if (e.seat != mySeat) await Future<void>.delayed(const Duration(milliseconds: 150));
        case 'token_moved':
          if (ch == null) break;
          final path = (e.payload['path'] as List<dynamic>? ?? const []).cast<int>();
          final to = e.payload['to'] as int;
          final steps = path.isEmpty ? [to] : path;
          _clearHighlights();
          await ch.walkPath(steps, finalOffset: _offsetFor(next, e.seat!, to), onStep: (_) => KingdomAudio.instance.play('step'));
        case 'bounce_back':
          _notify(KingdomNotice('${_name(prev, e.seat)} needs an exact roll', icon: Icons.u_turn_left_rounded, color: ZpColors.champagne));
        case 'ladder_climbed':
          if (ch == null) break;
          final link = Link(e.payload['from'] as int, e.payload['to'] as int);
          final ladder = ladders[link];
          final from = geo.squareCenter(link.from);
          final to = geo.squareCenter(link.to);
          KingdomAudio.instance.play('ladder');
          _notify(KingdomNotice('${_name(prev, e.seat)} climbs to ${link.to}', icon: Icons.stairs_rounded, color: ZpColors.goldLight));
          unawaited(_focus((from + to) / 2, zoom: _zoomFor((to - from).length)));
          await ch.climbLadder(ladder?.pointAt(0) ?? from, ladder?.pointAt(1) ?? to, link.to, finalOffset: _offsetFor(next, e.seat!, link.to));
          world.add(fx.sparkleRise(ch.position.clone()));
          await _resetCamera();
        case 'snake_slid':
          if (ch == null) break;
          final link = Link(e.payload['from'] as int, e.payload['to'] as int);
          final dragon = dragons[link];
          final curve = dragon?.curve ?? geo.snakeCurve(link);
          KingdomAudio.instance.play('snake');
          _notify(KingdomNotice('${_name(prev, e.seat)} slides down to ${link.to}', icon: Icons.waves_rounded, color: ZpColors.danger));
          unawaited(_focus(curve.pointAt(0.5), zoom: _zoomFor((curve.p3 - curve.p0).length)));
          await ch.slideDragon(curve, link.to, finalOffset: _offsetFor(next, e.seat!, link.to));
          world.add(fx.dustPuff(ch.position.clone()));
          await _resetCamera();
        case 'no_move':
          if (e.seat == mySeat) _notify(KingdomNotice('Roll a ${next.rules.unlockRoll} to set out', icon: Icons.lock_outline_rounded));
        case 'extra_turn':
          if (e.seat == mySeat) {
            _notify(const KingdomNotice('Extra turn', icon: Icons.replay_rounded, color: ZpColors.goldLight));
            KingdomAudio.instance.play('extra_turn');
          }
        case 'turn_timeout':
          _notify(KingdomNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(KingdomNotice('${_name(prev, e.seat)} left the kingdom', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'player_finished':
          final p = e.payload['placement'] as int;
          _notify(KingdomNotice('${_name(prev, e.seat)} reached the castle ${_ordinal(p)}', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
          if (ch != null) {
            unawaited(_focus(geo.squareCenter(next.boardSize), zoom: 1.6));
            world.add(fx.sparkleRise(ch.position.clone(), count: 40));
            if (p == 1) {
              world.add(fx.confetti(Vector2.all(geo.worldSize), accent: KingdomBoardComponent.colorOf(next.seatAt(e.seat!).color)));
              KingdomAudio.instance.play('victory');
            }
            await ch.celebrate();
            await Future<void>.delayed(const Duration(milliseconds: 500));
            await _resetCamera();
          }
        case 'turn_changed':
          if (e.seat == mySeat) KingdomAudio.instance.play('turn_change');
        case 'match_finished':
          break;
      }
    }
    _version = u.version;
    displayState.value = next;
    _syncCharacters(next);
    _refreshInteractivity(next);
  }

  String _name(KingdomState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  static String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
  void _notify(KingdomNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  double _zoomFor(double spanWorld) {
    // Zoom so the span fills roughly 60% of the viewport, within sane bounds.
    final z = geo.worldSize * 0.6 / (spanWorld + geo.cell * 1.5);
    return z.clamp(1.15, 1.9);
  }

  void _clearCameraEffects() {
    for (final e in camera.viewfinder.children.whereType<Effect>().toList()) {
      e.removeFromParent();
    }
  }

  /// Gentle pan and zoom toward a point of interest.
  Future<void> _focus(Vector2 target, {required double zoom, double duration = 0.55}) async {
    if (GraphicsSettings.instance.reduceEffects) return;
    _clearCameraEffects();
    final c = Completer<void>();
    final vf = camera.viewfinder;
    vf.add(MoveToEffect(geo.clampFocus(target, zoom), EffectController(duration: duration, curve: Curves.easeInOutCubic), onComplete: c.complete));
    vf.add(ScaleEffect.to(Vector2.all(zoom), EffectController(duration: duration, curve: Curves.easeInOutCubic)));
    await c.future;
  }

  Future<void> _resetCamera({bool immediate = false, double duration = 0.6}) async {
    _clearCameraEffects();
    final vf = camera.viewfinder;
    if (immediate || GraphicsSettings.instance.reduceEffects) {
      vf.position = geo.worldCenter;
      vf.zoom = 1;
      return;
    }
    if ((vf.position - geo.worldCenter).length < 0.5 && (vf.zoom - 1).abs() < 0.001) return;
    final c = Completer<void>();
    vf.add(MoveToEffect(geo.worldCenter, EffectController(duration: duration, curve: Curves.easeInOutCubic), onComplete: c.complete));
    vf.add(ScaleEffect.to(Vector2.all(1), EffectController(duration: duration, curve: Curves.easeInOutCubic)));
    await c.future;
  }

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  static final List<Vector2> _stackOffsets = [Vector2(0, 0), Vector2(-16, -6), Vector2(16, -6), Vector2(0, -14)];

  /// Offset for a character standing on [square] so co-located knights stay readable.
  Vector2 _offsetFor(KingdomState s, int seat, int square) {
    if (square <= 0) return Vector2.zero();
    final group = s.seats.where((x) => x.position == square).map((x) => x.seat).toList()..sort();
    if (group.length < 2) return Vector2.zero();
    final k = group.indexOf(seat);
    return _stackOffsets[(k < 0 ? 0 : k) % _stackOffsets.length].clone();
  }

  void _syncCharacters(KingdomState s) {
    for (final seat in s.seats) {
      final ch = characters[seat.seat];
      if (ch == null || ch.moving) continue;
      final off = _offsetFor(s, seat.seat, seat.position);
      final target = geo.positionFor(seat.position, ch.seatIndex) + off;
      if (ch.square != seat.position || (ch.position - (target + Vector2(0, geo.cell * 0.22))).length > 2) {
        ch.snapTo(seat.position, offset: off);
      }
      ch.highlight = false;
    }
  }

  void _clearHighlights() {
    for (final ch in characters.values) {
      ch.highlight = false;
    }
  }

  void _refreshInteractivity(KingdomState s) {
    _clearHighlights();
    final myTurn = !isSpectator && s.turnSeat == mySeat && s.phase != KingdomPhase.finished;
    dice.enabled = myTurn && s.phase == KingdomPhase.roll && !awaitingServer.value;
    if (s.phase != KingdomPhase.finished) characters[s.turnSeat]?.highlight = true;
  }
}
