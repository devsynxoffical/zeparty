import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/board_component.dart';
import 'components/dice_component.dart';
import 'components/fx.dart';
import 'components/token_component.dart';
import 'ludo_audio.dart';
import 'model/board.dart';
import 'model/ludo_state.dart';

/// Visual configuration chosen from equipped cosmetics.
class LudoCosmetics {
  const LudoCosmetics({this.board = 'imperial_palace', this.tokens = 'classic', this.dice = 'crystal'});
  final String board;
  final String tokens;
  final String dice;
}

/// UI-facing notifications the HUD renders (toasts, banners).
class LudoNotice {
  const LudoNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// The Flame scene for Ludo Royale. World is 15 cells x 100 units.
///
/// Authority model: this class never decides the outcome of anything. It sends
/// actions through [GameChannel], queues incoming server updates and animates
/// them in order. [displayState] is the last fully animated state; [latestState]
/// is the newest known server state (used by the HUD for timers).
class LudoGame extends FlameGame {
  LudoGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final LudoCosmetics cosmetics;

  static const double cellSize = 100;
  static const double boardSize = cellSize * 15;

  late final BoardComponent board;
  late final DiceComponent dice;
  late final Fx fx;
  final Map<int, Map<int, TokenComponent>> tokens = {}; // seat -> index -> token
  final ValueNotifier<LudoState?> displayState = ValueNotifier(null);
  final ValueNotifier<LudoState?> latestState = ValueNotifier(null);
  final ValueNotifier<LudoNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<int> rollsThisTurn = ValueNotifier(0);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingRollTimeout;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: boardSize, height: boardSize);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = LudoState.fromJson(session.initialState);
    _version = session.initialVersion;
    final q = GraphicsSettings.instance.current;

    Future<ui.Image> img(String logical) => images.load(ZpAssets.key(logical, quality: q));
    final results = await Future.wait([
      img(LudoAssets.surfaces[cosmetics.board] ?? LudoAssets.surfaces['imperial_palace']!),
      img(LudoAssets.goldTrim),
      img(LudoAssets.centerCrest),
      img(LudoAssets.safeStar),
      img(LudoAssets.particles),
      for (var i = 1; i <= 6; i++) img(LudoAssets.dice(cosmetics.dice, i)),
      for (final c in LudoColor.values) img(LudoAssets.token(cosmetics.tokens, c.name)),
    ]);
    final skin = BoardSkin(
      id: cosmetics.board,
      surface: results[0],
      trim: results[1],
      crest: results[2],
      star: results[3],
      trackTint: switch (cosmetics.board) { 'midnight_gold' => const Color(0x33F1E3B8), 'crystal_kingdom' => const Color(0x55FFFFFF), _ => const Color(0x66FFFFFF) },
      lineColor: switch (cosmetics.board) { 'midnight_gold' => ZpColors.gold.withValues(alpha: 0.7), _ => ZpColors.goldDeep.withValues(alpha: 0.8) },
      baseAlpha: cosmetics.board == 'crystal_kingdom' ? 0.55 : 0.7,
      glowColor: ZpColors.goldLight,
    );
    fx = Fx(sheet: SpriteSheet(image: results[4], srcSize: Vector2(results[4].width / 3, results[4].height / 2)), cellSize: cellSize);

    board = BoardComponent(skin: skin, cell: cellSize, activeColors: initial.seats.map((s) => s.color).toList(), safeMode: initial.rules.safeSquares);
    world.add(board);
    world.add(fx.ambientDust(Vector2.all(boardSize)));

    final diceFaces = [for (var i = 0; i < 6; i++) Sprite(results[5 + i])];
    dice = DiceComponent(
      faces: diceFaces,
      cellSize: cellSize,
      onTap: requestRoll,
      seatColorOf: () => BoardComponent.colorOf(displayState.value?.current.color ?? LudoColor.red),
    )..position = Vector2.all(boardSize / 2);
    world.add(dice);

    for (final seat in initial.seats) {
      final sprite = Sprite(results[11 + seat.color.index]);
      tokens[seat.seat] = {};
      for (var i = 0; i < seat.tokens.length; i++) {
        final t = TokenComponent(seat: seat.seat, color: seat.color, index: i, sprite: sprite, board: board, cellSize: cellSize, onTap: _onTokenTap);
        tokens[seat.seat]![i] = t;
        world.add(t);
      }
    }
    _syncTokens(initial, animateNone: true);
    displayState.value = initial;
    latestState.value = initial;
    _refreshInteractivity(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(LudoAudio.instance.init().then((_) => LudoAudio.instance.play('match_start')));
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
    if (s.turnSeat != mySeat || s.phase != LudoPhase.roll) return;
    awaitingServer.value = true;
    dice.enabled = false;
    dice.startRolling();
    LudoAudio.instance.play('dice_roll');
    _pendingRollTimeout?.cancel();
    _pendingRollTimeout = async.Timer(const Duration(seconds: 4), () {
      // Server never answered: stop the visual and resync rather than spin forever.
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
      _notify(LudoNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      LudoAudio.instance.play('illegal_move');
    }
  }

  void _onTokenTap(TokenComponent t) {
    final s = displayState.value;
    if (s == null || isSpectator || busy.value || awaitingServer.value) return;
    if (s.turnSeat != mySeat || s.phase != LudoPhase.move || t.seat != mySeat) return;
    if (!s.legalTokens.contains(t.index)) {
      LudoAudio.instance.play('illegal_move');
      return;
    }
    requestMove(t.index);
  }

  Future<void> requestMove(int tokenIndex) async {
    awaitingServer.value = true;
    for (final t in tokens[mySeat]!.values) {
      t.selected = t.index == tokenIndex;
    }
    try {
      await channel.submit({'type': 'move', 'token': tokenIndex}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _notify(LudoNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      LudoAudio.instance.play('illegal_move');
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('illegal_move')) return 'That token cannot move';
    if (s.contains('version_mismatch')) return 'Syncing with the table';
    if (s.contains('wrong_phase')) return 'Wait for the dice';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = LudoState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    // Full state after a resync: drop pending animations and snap everything.
    _queue.clear();
    final s = LudoState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    _syncTokens(s, animateNone: true);
    awaitingServer.value = false;
    busy.value = false;
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
    final next = LudoState.fromJson(u.state);
    final prev = displayState.value;
    final anyEvent = u.events.isNotEmpty;
    for (final e in u.events) {
      switch (e.type) {
        case 'dice_rolled':
          final value = e.payload['value'] as int;
          _pendingRollTimeout?.cancel();
          awaitingServer.value = false;
          if (e.seat == mySeat) {
            rollsThisTurn.value += 1;
          } else {
            dice.startRolling();
            LudoAudio.instance.play('dice_roll');
          }
          await dice.settle(value);
          if (e.seat != mySeat) await Future<void>.delayed(const Duration(milliseconds: 200));
        case 'token_moved':
          final seat = e.seat!;
          final idx = e.payload['token'] as int;
          final to = e.payload['to'] as int;
          final t = tokens[seat]?[idx];
          if (t == null) break;
          awaitingServer.value = false;
          _clearHighlights();
          await t.moveTo(to, onStep: (_) => LudoAudio.instance.play('token_place'));
          _restackCell(seat, idx, next);
        case 'token_captured':
          final victimSeat = e.payload['victimSeat'] as int;
          final idx = e.payload['token'] as int;
          final v = tokens[victimSeat]?[idx];
          if (v == null) break;
          world.add(fx.burst(v.position.clone(), color: BoardComponent.colorOf(v.color)));
          world.add(fx.ringPulse(v.position.clone(), color: ZpColors.goldLight));
          LudoAudio.instance.play('capture');
          _notify(LudoNotice('${_name(prev, e.seat)} captured ${_name(prev, victimSeat)}', icon: Icons.flash_on_rounded, color: ZpColors.ruby));
          await v.sendHome();
        case 'safe_square':
          final t = tokens[e.seat!]?[e.payload['token'] as int];
          if (t != null) world.add(fx.ringPulse(t.position.clone(), color: ZpColors.champagne));
        case 'token_home':
          final t = tokens[e.seat!]?[e.payload['token'] as int];
          if (t != null) {
            world.add(fx.homeSparkle(t.position.clone()));
            LudoAudio.instance.play('token_home');
            await t.celebrateHome();
          }
        case 'extra_turn':
          if (e.seat == mySeat) {
            _notify(const LudoNotice('Extra turn', icon: Icons.replay_rounded, color: ZpColors.goldLight));
            LudoAudio.instance.play('extra_turn');
          }
        case 'three_sixes':
          _notify(LudoNotice('${_name(prev, e.seat)} rolled three sixes', icon: Icons.block_rounded, color: ZpColors.danger));
        case 'no_legal_move':
          if (e.seat == mySeat) _notify(const LudoNotice('No legal move', icon: Icons.remove_circle_outline_rounded));
        case 'turn_timeout':
          _notify(LudoNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(LudoNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'player_finished':
          final p = e.payload['placement'] as int;
          _notify(LudoNotice('${_name(prev, e.seat)} finished ${_ordinal(p)}', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
          if (p == 1) {
            world.add(fx.confetti(Vector2.all(boardSize), accent: BoardComponent.colorOf(next.seatAt(e.seat!).color)));
            LudoAudio.instance.play('victory_fanfare');
          }
        case 'turn_changed':
          rollsThisTurn.value = 0;
          if (e.seat == mySeat) LudoAudio.instance.play('turn_change');
        case 'match_finished':
          break;
      }
    }
    _version = u.version;
    displayState.value = next;
    _syncTokens(next, animateNone: !anyEvent);
    _refreshInteractivity(next);
  }

  String _name(LudoState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  static String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };

  void _notify(LudoNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  /// Offsets for tokens sharing a cell so stacks stay readable.
  static final List<Vector2> _stackOffsets = [Vector2(0, 0), Vector2(-14, -12), Vector2(14, -12), Vector2(-14, 12), Vector2(14, 12), Vector2(0, -18), Vector2(0, 18), Vector2(-20, 0)];

  Map<String, List<TokenComponent>> _occupancy(LudoState s) {
    final map = <String, List<TokenComponent>>{};
    for (final seat in s.seats) {
      for (var i = 0; i < seat.tokens.length; i++) {
        final step = seat.tokens[i];
        final t = tokens[seat.seat]?[i];
        if (t == null) continue;
        final key = step < 0 ? 'b${seat.seat}:$i' : step == homeStep ? 'h${seat.seat}' : 'c${absoluteIndex(seat.color, step) ?? 'hc${seat.seat}:$step'}';
        map.putIfAbsent(key, () => []).add(t);
      }
    }
    return map;
  }

  void _syncTokens(LudoState s, {required bool animateNone}) {
    final occ = _occupancy(s);
    for (final group in occ.values) {
      final n = group.length;
      for (var k = 0; k < n; k++) {
        final t = group[k];
        final seat = s.seatAt(t.seat);
        final step = seat.tokens[t.index];
        final off = n > 1 ? _stackOffsets[k % _stackOffsets.length] * (n > 4 ? 0.7 : 1) : Vector2.zero();
        final target = board.cellCenter(cellForStep(t.color, step, t.index)) + off;
        if (t.moving) continue;
        if (t.step != step || (t.position - target).length > 2) {
          t.snapTo(step, offset: off);
        }
      }
    }
  }

  void _restackCell(int seat, int idx, LudoState next) {
    // After a move, nudge co-located tokens into their stack offsets.
    final occ = _occupancy(next);
    for (final group in occ.values) {
      if (!group.any((t) => t.seat == seat && t.index == idx) || group.length < 2) continue;
      for (var k = 0; k < group.length; k++) {
        final t = group[k];
        final step = next.seatAt(t.seat).tokens[t.index];
        if (!t.moving) t.snapTo(step, offset: _stackOffsets[k % _stackOffsets.length]);
      }
    }
  }

  void _clearHighlights() {
    for (final m in tokens.values) {
      for (final t in m.values) {
        t.legal = false;
      }
    }
  }

  void _refreshInteractivity(LudoState s) {
    _clearHighlights();
    final myTurn = !isSpectator && s.turnSeat == mySeat && s.phase != LudoPhase.finished;
    dice.enabled = myTurn && s.phase == LudoPhase.roll && !awaitingServer.value;
    if (myTurn && s.phase == LudoPhase.move) {
      for (final i in s.legalTokens) {
        tokens[mySeat]?[i]?.legal = true;
      }
    }
    if (s.phase == LudoPhase.finished) dice.enabled = false;
  }
}
