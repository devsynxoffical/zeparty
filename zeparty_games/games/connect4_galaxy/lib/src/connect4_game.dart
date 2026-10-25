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

import 'components/disc_component.dart';
import 'components/fx.dart';
import 'components/galaxy_palette.dart';
import 'components/grid_component.dart';
import 'components/starfield_component.dart';
import 'components/win_line_component.dart';
import 'connect4_assets.dart';
import 'connect4_audio.dart';
import 'model/connect4_state.dart';
import 'model/win_detection.dart';

/// Visual and interaction configuration chosen from cosmetics and settings.
class Connect4Cosmetics {
  const Connect4Cosmetics({this.discSkin = 'classic', this.confirmDrop = true});

  /// 'classic' or 'plasma' (cosmetic id `connect4_galaxy.disc.plasma`).
  final String discSkin;

  /// First tap previews the column, second tap drops. False = single tap drops.
  final bool confirmDrop;
}

/// UI-facing notifications the HUD renders (toasts, banners).
class Connect4Notice {
  const Connect4Notice(this.text, {this.icon, this.color});
  final String text;
  final IconData? icon;
  final Color? color;
}

/// The Flame scene for Connect 4 Galaxy.
///
/// Authority model: this class never decides an outcome. It submits `drop`
/// actions through [GameChannel], queues server updates and animates their
/// events in order, then snaps every disc to the authoritative grid.
/// [displayState] is the last fully animated state; [latestState] the newest
/// known server state (used by the HUD for timers).
class Connect4Game extends FlameGame {
  Connect4Game({required this.session, required this.channel, required this.cosmetics});

  final GameSessionContext session;
  final GameChannel channel;
  final Connect4Cosmetics cosmetics;

  static const double cellSize = 100;

  late final GridGeometry geometry;
  late final GridComponent grid;
  late final Fx fx;
  final Map<int, Sprite?> _discSprites = {};
  final Map<String, DiscComponent> discs = {}; // "row:col" -> disc
  WinLineComponent? winLine;

  final ValueNotifier<Connect4State?> displayState = ValueNotifier(null);
  final ValueNotifier<Connect4State?> latestState = ValueNotifier(null);
  final ValueNotifier<Connect4Notice?> notice = ValueNotifier(null);
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<bool> awaitingServer = ValueNotifier(false);
  final ValueNotifier<int?> selectedColumn = ValueNotifier(null);

  final Queue<GameUpdate> _queue = Queue();
  bool _draining = false;
  int _version = 0;
  final List<StreamSubscription<dynamic>> _subs = [];
  async.Timer? _pendingTimeout;

  int? get mySeat => session.mySeat;
  bool get isSpectator => session.isSpectator;
  int get version => _version;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    final initial = Connect4State.fromJson(session.initialState);
    _version = session.initialVersion;
    geometry = GridGeometry(columns: initial.columns, rows: initial.rows, cell: cellSize, topSlot: cellSize * 1.4);
    camera = CameraComponent.withFixedResolution(world: world, width: geometry.width, height: geometry.height);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    final q = GraphicsSettings.instance.current;
    final results = await Future.wait([
      _tryLoad(Connect4Assets.frame, q),
      _tryLoad(Connect4Assets.particles, q),
      _tryLoad(Connect4Assets.disc(cosmetics.discSkin, 0), q),
      _tryLoad(Connect4Assets.disc(cosmetics.discSkin, 1), q),
    ]);
    final sheetImg = results[1];
    fx = Fx(sheet: sheetImg == null ? null : SpriteSheet(image: sheetImg, srcSize: Vector2(sheetImg.width / 3, sheetImg.height / 2)), cellSize: cellSize);
    _discSprites[0] = results[2] == null ? null : Sprite(results[2]!);
    _discSprites[1] = results[3] == null ? null : Sprite(results[3]!);

    world.add(StarfieldComponent(size: Vector2(geometry.width, geometry.height)));
    grid = GridComponent(geometry: geometry, onColumnTap: onColumnTap, onHover: _onHover, frameImage: results[0]);
    world.add(grid);

    _syncDiscs(initial);
    displayState.value = initial;
    latestState.value = initial;
    _refreshInteractivity(initial);
    if (initial.finished) _showFinished(initial);

    _subs.add(channel.updates.listen(_onUpdate));
    _subs.add(channel.snapshots.listen(_onSnapshot));
    unawaited(Connect4Audio.instance.init());
  }

  /// Loads an image, returning null (procedural fallback) when it is not bundled.
  /// Goes through rootBundle directly (not Flame's image cache) so a missing
  /// file surfaces as a caught error instead of an unhandled async failure.
  Future<ui.Image?> _tryLoad(String logical, GraphicsQuality q) async {
    try {
      final key = ZpAssets.key(logical, quality: q);
      final img = await ZpAssets.loadUiImage(logical, quality: q);
      images.add(key, img);
      return img;
    } catch (e) {
      debugPrint('connect4_galaxy: $logical missing, using procedural art');
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

  bool get _canAct {
    final s = displayState.value;
    return s != null && !isSpectator && !busy.value && !awaitingServer.value && !s.finished && s.turnSeat == mySeat;
  }

  void _onHover(int? column) {
    if (!_canAct) return;
    final s = displayState.value!;
    grid.hoverColumn = column;
    if (selectedColumn.value == null) grid.ghostRow = column == null ? -1 : s.landingRowFor(column);
  }

  /// Column tap from the grid (or HUD). First tap previews, second drops, unless
  /// `confirmDrop` is off.
  void onColumnTap(int column) {
    if (!_canAct) {
      if (!isSpectator && displayState.value?.turnSeat != mySeat && displayState.value?.finished == false) {
        _notify(const Connect4Notice('Not your turn', icon: Icons.hourglass_top_rounded));
      }
      return;
    }
    final s = displayState.value!;
    if (!s.legalColumns.contains(column)) {
      _notify(const Connect4Notice('That column is full', icon: Icons.block_rounded, color: ZpColors.danger));
      Connect4Audio.instance.play('ui_tap');
      return;
    }
    if (cosmetics.confirmDrop && selectedColumn.value != column) {
      selectColumn(column);
      return;
    }
    requestDrop(column);
  }

  void selectColumn(int? column) {
    final s = displayState.value;
    selectedColumn.value = column;
    grid.selectedColumn = column;
    grid.ghostRow = column == null || s == null ? -1 : s.landingRowFor(column);
    if (column != null) Connect4Audio.instance.play('ui_tap');
  }

  Future<void> requestDrop(int column) async {
    if (!_canAct) return;
    final s = displayState.value!;
    if (!s.legalColumns.contains(column)) return;
    awaitingServer.value = true;
    selectColumn(column);
    _pendingTimeout?.cancel();
    _pendingTimeout = async.Timer(const Duration(seconds: 4), () {
      // Server never answered: release the input and resync rather than hang.
      if (awaitingServer.value) {
        awaitingServer.value = false;
        channel.resync();
      }
    });
    try {
      await channel.submit({'type': 'drop', 'column': column}, version: _version);
    } catch (e) {
      awaitingServer.value = false;
      selectColumn(null);
      _notify(Connect4Notice(_friendly(e), icon: Icons.error_outline_rounded, color: ZpColors.danger));
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('not_your_turn')) return 'Not your turn';
    if (s.contains('column_full')) return 'That column is full';
    if (s.contains('version_mismatch')) return 'Syncing with the chamber';
    if (s.contains('match_finished')) return 'The match is over';
    return 'Action rejected';
  }

  // ---------------------------------------------------------------------------
  // Server updates
  // ---------------------------------------------------------------------------

  void _onUpdate(GameUpdate u) {
    latestState.value = Connect4State.fromJson(u.state);
    _queue.add(u);
    _drain();
  }

  void _onSnapshot(GameUpdate u) {
    _queue.clear();
    final s = Connect4State.fromJson(u.state);
    _version = u.version;
    latestState.value = s;
    displayState.value = s;
    _pendingTimeout?.cancel();
    awaitingServer.value = false;
    busy.value = false;
    _clearWinLine();
    _syncDiscs(s);
    selectColumn(null);
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
    final next = Connect4State.fromJson(u.state);
    final prev = displayState.value;
    for (final e in u.events) {
      switch (e.type) {
        case 'disc_dropped':
          final column = e.payload['column'] as int;
          final row = e.payload['row'] as int;
          final seat = (e.payload['seat'] as int?) ?? e.seat ?? 0;
          _pendingTimeout?.cancel();
          awaitingServer.value = false;
          selectColumn(null);
          grid.enabled = false;
          final disc = _spawnDisc(seat, column);
          Connect4Audio.instance.play('disc_drop');
          await disc.dropTo(row, onLand: () {
            Connect4Audio.instance.play('disc_land');
            world.add(fx.landingBurst(geometry.cellCenter(row, column), color: GalaxyPalette.seat(seat)));
          });
          discs['$row:$column'] = disc;
        case 'win':
          final seat = (e.payload['seat'] as int?) ?? e.seat ?? 0;
          final line = ((e.payload['line'] as List<dynamic>?) ?? const []).map((c) => GridCell.fromJson(c as Map<String, dynamic>)).toList();
          await _activateWin(seat, line, next);
        case 'draw':
          _notify(const Connect4Notice('The grid is full. Draw.', icon: Icons.balance_rounded, color: ZpColors.champagne));
        case 'turn_timeout':
          _notify(Connect4Notice('${_name(prev, e.seat)} ran out of time', icon: Icons.timer_off_rounded, color: ZpColors.danger));
        case 'player_forfeited':
          final reason = e.payload['reason'] as String?;
          _notify(Connect4Notice(reason == 'timeouts' ? '${_name(prev, e.seat)} forfeited' : '${_name(prev, e.seat)} left the match', icon: Icons.logout_rounded, color: ZpColors.danger));
        case 'turn_changed':
          if (e.seat == mySeat) Connect4Audio.instance.play('ui_tap');
        case 'match_finished':
          if (next.winnerSeat != null && (next.winLine == null || next.winLine!.isEmpty)) {
            // Win by forfeit: no line to light, still celebrate.
            _celebrate(next.winnerSeat!);
          }
      }
    }
    _version = u.version;
    displayState.value = next;
    _syncDiscs(next);
    _refreshInteractivity(next);
  }

  Future<void> _activateWin(int seat, List<GridCell> line, Connect4State next) async {
    _clearWinLine();
    for (final c in line) {
      discs['${c.row}:${c.col}']?.winning = true;
    }
    final wl = WinLineComponent(cells: line.map((c) => geometry.cellCenter(c.row, c.col)).toList(), seat: seat, cell: cellSize);
    winLine = wl;
    world.add(wl);
    Connect4Audio.instance.play('win_line');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _celebrate(seat);
    _notify(Connect4Notice(seat == mySeat ? 'You win!' : '${_name(next, seat)} wins', icon: Icons.emoji_events_rounded, color: GalaxyPalette.seatLight(seat)));
  }

  void _celebrate(int seat) {
    world.add(fx.confetti(Vector2(geometry.width, geometry.height), accent: GalaxyPalette.seat(seat)));
    Connect4Audio.instance.play('victory');
  }

  /// Finished state reached without events (reconnect into a finished match).
  void _showFinished(Connect4State s) {
    final line = s.winLine;
    if (s.winnerSeat != null && line != null && line.isNotEmpty && winLine == null) {
      for (final c in line) {
        discs['${c.row}:${c.col}']?.winning = true;
      }
      final wl = WinLineComponent(cells: line.map((c) => geometry.cellCenter(c.row, c.col)).toList(), seat: s.winnerSeat!, cell: cellSize);
      winLine = wl;
      world.add(wl);
    }
  }

  void _clearWinLine() {
    winLine?.removeFromParent();
    winLine = null;
    for (final d in discs.values) {
      d.winning = false;
    }
  }

  String _name(Connect4State? s, int? seat) => s?.seatOrNull(seat)?.displayName ?? 'Player';
  void _notify(Connect4Notice n) => notice.value = n;

  // ---------------------------------------------------------------------------
  // Presentation sync
  // ---------------------------------------------------------------------------

  DiscComponent _spawnDisc(int seat, int column) {
    final d = DiscComponent(seat: seat, geometry: geometry, sprite: _discSprites[seat], plasma: cosmetics.discSkin == 'plasma');
    d.placeInSlot(column);
    world.add(d);
    return d;
  }

  /// Make the disc components match the authoritative grid exactly.
  void _syncDiscs(Connect4State s) {
    final wanted = <String>{};
    for (var row = 0; row < s.rows; row++) {
      for (var col = 0; col < s.columns; col++) {
        final seat = s.cellAt(row, col);
        if (seat == emptyCell) continue;
        final key = '$row:$col';
        wanted.add(key);
        final existing = discs[key];
        if (existing != null && existing.seat == seat) {
          if (!existing.moving) existing.snapTo(row, col);
          continue;
        }
        existing?.removeFromParent();
        final d = DiscComponent(seat: seat, geometry: geometry, sprite: _discSprites[seat], plasma: cosmetics.discSkin == 'plasma');
        d.snapTo(row, col);
        discs[key] = d;
        world.add(d);
      }
    }
    for (final key in discs.keys.where((k) => !wanted.contains(k)).toList()) {
      discs.remove(key)?.removeFromParent();
    }
    // Drop any stray in-flight disc that never got a key (should not happen).
    for (final c in world.children.whereType<DiscComponent>().toList()) {
      if (!discs.containsValue(c) && !c.moving) c.removeFromParent();
    }
  }

  void _refreshInteractivity(Connect4State s) {
    final myTurn = !isSpectator && s.turnSeat == mySeat && !s.finished;
    grid.enabled = myTurn && !awaitingServer.value;
    grid.highlightSeat = mySeat ?? s.turnSeat;
    grid.legalColumns = s.legalColumns.toSet();
    if (!myTurn) {
      grid.hoverColumn = null;
      grid.ghostRow = -1;
      selectedColumn.value = null;
      grid.selectedColumn = null;
    }
  }
}
