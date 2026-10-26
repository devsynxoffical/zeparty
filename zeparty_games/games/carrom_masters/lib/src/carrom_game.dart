import 'dart:async' as async;
import 'dart:async' show StreamSubscription, unawaited;
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'carrom_assets.dart';
import 'carrom_audio.dart';
import 'components/aim_component.dart';
import 'components/board_component.dart';
import 'components/fx.dart';
import 'components/piece_component.dart';
import 'components/shot_replayer.dart';
import 'model/carrom_state.dart';
import 'model/geometry.dart' as g;
import 'model/shot_frames.dart';

/// Visual configuration chosen from equipped cosmetics.
class CarromCosmetics {
  const CarromCosmetics({this.strikerSkin = 'classic'});
  /// `classic` or `gold` (from `carrom_masters.striker.gold`).
  final String strikerSkin;
  Color? get strikerRingTint => strikerSkin == 'gold' ? ZpColors.goldLight : null;
}

/// UI-facing notification the HUD renders as a toast.
class CarromNotice {
  const CarromNotice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

enum AimMode { none, place, aim }

/// Live aim readout for the HUD.
class AimInfo {
  const AimInfo({required this.mode, required this.power, required this.strikerX, required this.valid});
  final AimMode mode;
  final double power;
  final double strikerX;
  final bool valid;
}

/// The Flame scene for Carrom Masters.
///
/// Authority model: the server simulates every shot and sends keyframes; this
/// class only renders state, replays keyframes and submits aim gestures. The
/// board is drawn in the viewer's frame so each player sees their baseline at
/// the bottom; board coordinates from the server pass through [toWorld].
class CarromGame extends FlameGame {
  CarromGame({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final CarromCosmetics cosmetics;

  /// World pixels per board unit.
  static const double unit = 10;
  static const double playfieldPx = g.boardSize * unit;
  /// Frame border derived from the walnut frame art (opening is 76.5% of the image).
  static const double border = 154;
  static const double worldSize = playfieldPx + border * 2;

  late final BoardComponent board;
  late final AimComponent aim;
  late final Fx fx;
  final Map<String, PieceComponent> pieces = {};
  final Map<PieceKind, Sprite?> _sprites = {};

  final ValueNotifier<CarromState?> displayState = ValueNotifier(null);
  final ValueNotifier<CarromState?> latestState = ValueNotifier(null);
  final ValueNotifier<CarromNotice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<AimInfo?> aimInfo = ValueNotifier(null);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingTimeout;
  ShotReplayer? _replayer;

  /// Striker x on my baseline (frame units) while placing.
  double strikerX = 50;
  AimMode _mode = AimMode.none;
  double _placeOffset = 0;
  g.BPoint? _aimDir;
  double _aimPower = 0;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  /// Edge whose baseline the viewer sees at the bottom.
  int get viewerEdge => displayState.value?.seatOrNull(mySeat)?.edge ?? 0;

  /// Board coordinates -> world pixels in the viewer's frame.
  Vector2 toWorld(g.BPoint boardPoint) {
    final f = g.toFrame(viewerEdge, boardPoint);
    return Vector2(border + f.x * unit, border + f.y * unit);
  }

  /// Viewer frame units -> world pixels.
  Vector2 frameToWorld(g.BPoint framePoint) => Vector2(border + framePoint.x * unit, border + framePoint.y * unit);
  Offset frameToWorldOffset(g.BPoint framePoint) => Offset(border + framePoint.x * unit, border + framePoint.y * unit);

  /// World pixels -> viewer frame units.
  g.BPoint worldToFrame(Vector2 world) => g.BPoint((world.x - border) / unit, (world.y - border) / unit);

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    camera = CameraComponent.withFixedResolution(world: world, width: worldSize, height: worldSize);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final initial = CarromState.fromJson(session.initialState);
    _version = session.initialVersion;
    displayState.value = initial;
    latestState.value = initial;
    final q = GraphicsSettings.instance.current;

    final results = await Future.wait([
      _tryLoad(CarromAssets.frame, q),
      _tryLoad(CarromAssets.playfield, q),
      _tryLoad(CarromAssets.striker, q),
      _tryLoad(CarromAssets.coinWhite, q),
      _tryLoad(CarromAssets.coinBlack, q),
      _tryLoad(CarromAssets.coinQueen, q),
      _tryLoad(CarromAssets.particles, q),
    ]);
    _sprites[PieceKind.striker] = results[2] == null ? null : Sprite(results[2]!);
    _sprites[PieceKind.white] = results[3] == null ? null : Sprite(results[3]!);
    _sprites[PieceKind.black] = results[4] == null ? null : Sprite(results[4]!);
    _sprites[PieceKind.queen] = results[5] == null ? null : Sprite(results[5]!);
    final sheet = results[6];
    fx = Fx(sheet: sheet == null ? null : SpriteSheet(image: sheet, srcSize: Vector2(sheet.width / 3, sheet.height / 2)), unit: unit);

    board = BoardComponent(unit: unit, border: border, wood: results[1], frame: results[0]);
    world.add(board);
    world.add(fx.ambientDust(Vector2.all(worldSize)));
    aim = AimComponent(unit: unit, toWorld: frameToWorldOffset);
    world.add(aim);
    world.add(_InputLayer(game: this));

    for (final coin in initial.coins) {
      _pieceFor(coin.id, PieceKind.fromCoin(coin.kind));
    }
    _pieceFor('s', PieceKind.striker);
    _syncPieces(initial);
    _refreshInteractivity(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(CarromAudio.instance.init());
  }

  Future<ui.Image?> _tryLoad(String logical, GraphicsQuality q) async {
    try {
      return await images.load(ZpAssets.key(logical, quality: q));
    } catch (e) {
      debugPrint('carrom_masters: $logical missing, using procedural art');
      return null;
    }
  }

  PieceComponent _pieceFor(String id, PieceKind kind) {
    final existing = pieces[id];
    if (existing != null) return existing;
    final radius = (kind == PieceKind.striker ? g.strikerRadius : g.coinRadius) * unit;
    final p = PieceComponent(id: id, kind: kind, radius: radius, sprite: _sprites[kind], ringTint: kind == PieceKind.striker ? cosmetics.strikerRingTint : null);
    pieces[id] = p;
    world.add(p);
    return p;
  }

  PieceComponent get striker => pieces['s']!;

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
    return s != null && !isSpectator && !busy.value && !awaitingServer.value && s.phase == CarromPhase.aim && s.turnSeat == mySeat;
  }

  /// Coin positions in the viewer frame (for placement validation).
  Iterable<g.BPoint> _frameCoins(CarromState s) => s.onBoard.map((c) => g.toFrame(viewerEdge, c.position));

  g.BPoint get _strikerFrame => g.BPoint(strikerX, g.baselineY);

  bool get placementValid {
    final s = displayState.value;
    if (s == null) return false;
    return !g.strikerOverlaps(_strikerFrame, _frameCoins(s));
  }

  void onDragStartWorld(Vector2 world) {
    if (!canAct) return;
    final p = worldToFrame(world);
    if (p.distanceTo(_strikerFrame) <= g.strikerRadius * 2.4) {
      _mode = AimMode.place;
      _placeOffset = strikerX - p.x;
    } else {
      _mode = AimMode.aim;
      _updateAim(p);
    }
    _publishAim();
  }

  void onDragUpdateWorld(Vector2 world) {
    if (_mode == AimMode.none || !canAct) return;
    final p = worldToFrame(world);
    if (_mode == AimMode.place) {
      strikerX = (p.x + _placeOffset).clamp(g.baselineXMin, g.baselineXMax);
      striker.position = frameToWorld(_strikerFrame);
      striker.invalid = !placementValid;
      if ((p.y - g.baselineY).abs() > 7 && placementValid) {
        _mode = AimMode.aim;
        _updateAim(p);
      }
    } else {
      _updateAim(p);
    }
    _publishAim();
  }

  void _updateAim(g.BPoint finger) {
    final pull = _strikerFrame - finger;
    final len = pull.length;
    _aimPower = ((len - 2) / 30).clamp(0.0, 1.0);
    _aimDir = len < 0.5 ? null : pull.normalized;
    aim.origin = _strikerFrame;
    aim.direction = _aimDir;
    aim.power = _aimPower;
    aim.handle = finger;
    aim.visible = _aimDir != null && _aimPower > 0.02;
  }

  Future<void> onDragEndWorld() async {
    final mode = _mode;
    final dir = _aimDir;
    final power = _aimPower;
    _mode = AimMode.none;
    aim.visible = false;
    aim.handle = null;
    _aimDir = null;
    _aimPower = 0;
    _publishAim();
    if (mode == AimMode.aim && dir != null && power >= 0.08 && canAct && placementValid) {
      await submitShot(x: strikerX, angle: g.angleForDirection(dir), power: power);
    }
  }

  void onDragCancelWorld() {
    _mode = AimMode.none;
    aim.visible = false;
    aim.handle = null;
    _aimDir = null;
    _aimPower = 0;
    _publishAim();
  }

  void _publishAim() {
    aimInfo.value = _mode == AimMode.none ? null : AimInfo(mode: _mode, power: _aimPower, strikerX: strikerX, valid: placementValid);
  }

  /// Submit a shot in the shooter frame. Public so the HUD and tests can drive it.
  Future<void> submitShot({required double x, required double angle, required double power}) async {
    if (!canAct) return;
    awaitingServer.value = true;
    striker.interactive = false;
    _pendingTimeout?.cancel();
    _pendingTimeout = async.Timer(const Duration(seconds: 6), () {
      if (awaitingServer.value) {
        awaitingServer.value = false;
        channel.resync();
        final s = displayState.value;
        if (s != null) _refreshInteractivity(s);
      }
    });
    try {
      await channel.submit({'type': 'shot', 'x': x, 'angle': angle, 'power': power}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      _notify(CarromNotice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
      CarromAudio.instance.play('foul', volume: 0.5);
      final s = displayState.value;
      if (s != null) _refreshInteractivity(s);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('striker_overlap')) return 'Striker overlaps a coin';
    if (s.contains('version_mismatch')) return 'Syncing with the table';
    if (s.contains('bad_x')) return 'Place the striker on the baseline';
    if (s.contains('bad_power')) return 'Pull back to strike';
    return 'Shot rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = CarromState.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    _replayer?.finish();
    _replayer = null;
    final s = CarromState.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    awaitingServer.value = false;
    busy.value = false;
    _pendingTimeout?.cancel();
    _syncPieces(s);
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
    final next = CarromState.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'shot_resolved':
          _pendingTimeout?.cancel();
          awaitingServer.value = false;
          await _replayShot(ShotResolved.fromJson(e.payload), e.seat, prev);
        case 'coins_returned':
          final coins = ReturnedCoin.listFromPayload(e.payload);
          for (final c in coins) {
            final kind = c.id == 'q' ? PieceKind.queen : (c.id.startsWith('w') ? PieceKind.white : PieceKind.black);
            final piece = _pieceFor(c.id, kind);
            piece.position = toWorld(c.position);
            piece.visible = true;
            piece.visualScale = 1;
            piece.speed = 0;
            world.add(fx.ringPulse(piece.position.clone(), color: c.id == 'q' ? ZpColors.ruby : ZpColors.champagne));
          }
          if (coins.any((c) => c.reason == 'queen_uncovered')) {
            _notify(const CarromNotice('Queen not covered, back to the centre', icon: Icons.replay_rounded, color: ZpColors.ruby));
          } else if (coins.any((c) => c.reason == 'striker_penalty')) {
            _notify(const CarromNotice('Penalty: a coin returns to the board', icon: Icons.undo_rounded, color: ZpColors.danger));
          } else if (coins.any((c) => c.reason == 'due_paid')) {
            _notify(const CarromNotice('Due paid: a coin returns to the board', icon: Icons.undo_rounded, color: ZpColors.amber));
          }
          await Future<void>.delayed(const Duration(milliseconds: 350));
        case 'foul':
          CarromAudio.instance.play('foul');
        case 'extra_strike':
          if (e.seat == mySeat) {
            final pending = e.payload['queenPending'] == true;
            _notify(CarromNotice(pending ? 'Cover the queen' : 'Extra strike', icon: pending ? Icons.workspace_premium_rounded : Icons.replay_rounded, color: ZpColors.goldLight));
          }
        case 'turn_changed':
          if (e.seat == mySeat) {
            CarromAudio.instance.play('ui_tap', volume: 0.6);
            _notify(const CarromNotice('Your strike', icon: Icons.sports_esports_rounded, color: ZpColors.goldLight));
          }
        case 'turn_timeout':
          _notify(CarromNotice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          _notify(CarromNotice('${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'board_finished':
          final winner = CarromSide.parse(e.payload['winnerSide'] as String? ?? 'white');
          final n = e.payload['boardNumber'];
          _notify(CarromNotice('${_sideName(winner)} takes board $n', icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
          await Future<void>.delayed(const Duration(milliseconds: 600));
        case 'board_started':
          _notify(CarromNotice('Board ${e.payload['boardNumber']}', icon: Icons.refresh_rounded));
        case 'match_finished':
          final winner = next.winnerSide;
          final mine = winner != null && next.seatOrNull(mySeat)?.side == winner;
          world.add(fx.confetti(Vector2.all(worldSize), accent: winner == CarromSide.black ? ZpColors.obsidian : ZpColors.ivory));
          CarromAudio.instance.play('victory');
          _notify(CarromNotice(isSpectator || winner == null ? '${_sideName(winner)} wins' : (mine ? 'Victory' : '${_sideName(winner)} wins'), icon: Icons.emoji_events_rounded, color: ZpColors.goldLight));
      }
    }
    _version = u.version;
    displayState.value = next;
    _syncPieces(next);
    _refreshInteractivity(next);
  }

  Future<void> _replayShot(ShotResolved shot, int? seat, CarromState? prev) async {
    // Place the striker where the shooter put it, then play the strike.
    striker.visible = true;
    striker.invalid = false;
    striker.interactive = false;
    striker.position = toWorld(shot.placement);
    CarromAudio.instance.play('strike', volume: 0.5 + 0.5 * (shot.collisions.isEmpty ? 0.5 : 1));
    final replayer = ShotReplayer(
      shot: shot,
      pieces: pieces,
      toWorld: toWorld,
      speed: shot.duration > 7 ? 1.5 : 1,
      onCollision: (c, at) {
        switch (c.kind) {
          case CollisionKind.coin:
            final k = (c.speed / 60).clamp(0.15, 1.0);
            CarromAudio.instance.play('coin_hit', volume: 0.3 + 0.7 * k, minGapMs: 45);
            if (k > 0.2) world.add(fx.impact(at, intensity: k));
          case CollisionKind.cushion:
            final k = (c.speed / 80).clamp(0.1, 1.0);
            CarromAudio.instance.play('coin_hit', volume: 0.15 + 0.35 * k, minGapMs: 60);
            final f = worldToFrame(at);
            final normal = f.x < 5 ? Vector2(1, 0) : f.x > 95 ? Vector2(-1, 0) : f.y < 5 ? Vector2(0, 1) : Vector2(0, -1);
            if (k > 0.3) world.add(fx.cushionPuff(at, normal, intensity: k));
          case CollisionKind.pocket:
            break;
        }
      },
      onPocketed: (p, at) {
        CarromAudio.instance.play('pocket', minGapMs: 80);
        final accent = p.id == 's' ? ZpColors.danger : p.id == 'q' ? ZpColors.ruby : (p.by == CarromSide.black ? ZpColors.champagne : ZpColors.goldLight);
        world.add(fx.pocketSwirl(at, accent: accent));
      },
    );
    _replayer = replayer;
    world.add(replayer);
    await replayer.done;
    _replayer = null;
    // The striker is lifted off the board between strikes.
    striker.visible = false;
    if (shot.fouls.isNotEmpty) {
      final text = shot.strikerPocketed ? 'Foul: striker pocketed' : 'Foul: opponent coin pocketed';
      _notify(CarromNotice(text, icon: Icons.warning_amber_rounded, color: ZpColors.danger));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } else if (shot.queenCovered) {
      _notify(CarromNotice('${_sideName(shot.side)} covered the queen', icon: Icons.workspace_premium_rounded, color: ZpColors.ruby));
    }
  }

  String _name(CarromState? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  String _sideName(CarromSide? side) => side == CarromSide.black ? 'Black' : 'White';

  void _notify(CarromNotice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  void _syncPieces(CarromState s) {
    if (_replayer != null) return;
    for (final coin in s.coins) {
      final piece = _pieceFor(coin.id, PieceKind.fromCoin(coin.kind));
      piece.speed = 0;
      piece.visualScale = 1;
      if (coin.pocketed) {
        piece.visible = false;
      } else {
        piece.visible = true;
        piece.position = toWorld(coin.position);
      }
    }
    // Striker: on the current shooter's baseline while aiming, hidden otherwise.
    if (s.phase != CarromPhase.aim) {
      striker.visible = false;
      return;
    }
    final shooter = s.seatOrNull(s.turnSeat);
    if (shooter == null) {
      striker.visible = false;
      return;
    }
    if (shooter.seat == mySeat) {
      final free = g.nearestFreeBaselineX(strikerX, _frameCoins(s));
      if (free != null) strikerX = free;
      striker.position = frameToWorld(_strikerFrame);
      striker.invalid = !placementValid;
    } else {
      striker.position = toWorld(g.toBoard(shooter.edge, const g.BPoint(50, g.baselineY)));
      striker.invalid = false;
    }
    striker.visible = true;
    striker.visualScale = 1;
    striker.speed = 0;
  }

  void _refreshInteractivity(CarromState s) {
    striker.interactive = canAct;
    if (!canAct && _mode != AimMode.none) onDragCancelWorld();
  }
}

/// Transparent full-world layer that turns pointer drags into aim gestures.
class _InputLayer extends PositionComponent with DragCallbacks {
  _InputLayer({required this.game}) : super(size: Vector2.all(CarromGame.worldSize), priority: 50);
  final CarromGame game;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.onDragStartWorld(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    game.onDragUpdateWorld(event.localEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    unawaited(game.onDragEndWorld());
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game.onDragCancelWorld();
  }
}
