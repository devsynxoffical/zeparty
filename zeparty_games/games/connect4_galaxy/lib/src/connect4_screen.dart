import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/galaxy_palette.dart';
import 'components/starfield_component.dart';
import 'connect4_assets.dart';
import 'connect4_game.dart';
import 'model/connect4_state.dart';

/// Full-screen Connect 4 Galaxy scene: galaxy background, Flame grid in a
/// portrait viewport, Flutter HUD (player frames with turn timers, turn banner,
/// pause, drop button, toasts).
class Connect4Screen extends StatefulWidget {
  const Connect4Screen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final Connect4Cosmetics cosmetics;

  @override
  State<Connect4Screen> createState() => _Connect4ScreenState();
}

class _Connect4ScreenState extends State<Connect4Screen> with WidgetsBindingObserver {
  late final Connect4Game _game = Connect4Game(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  Connect4Notice? _toast;
  Timer? _toastTimer;
  final List<StreamSubscription<dynamic>> _subs = [];
  List<RoomPlayer> _players = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _players = widget.session.room.players;
    _game.notice.addListener(_onNotice);
    _subs.add(widget.channel.presence.listen((p) {
      setState(() => _players = [for (final x in _players) if (x.userId == p.userId) p else x]);
    }));
  }

  void _onNotice() {
    final n = _game.notice.value;
    if (n == null) return;
    _toastTimer?.cancel();
    setState(() => _toast = n);
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _game.pauseEngine();
    } else if (state == AppLifecycleState.resumed) {
      _game.resumeEngine();
      widget.channel.resync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _game.notice.removeListener(_onNotice);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = GameShellScope.maybeOf(context);
    final players = shell?.players ?? _players;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: ZpAssets.image(Connect4Assets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const CustomPaint(painter: StarfieldPainter())),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x11000000), Color(0xAA000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              return ValueListenableBuilder<Connect4State?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final boardWidget = Center(
                    child: AspectRatio(
                      aspectRatio: _aspect(state),
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Charging the grid')),
                    ),
                  );
                  final bottom = _BottomHud(game: _game, state: state, players: players);
                  if (portrait) {
                    return Column(children: [hud, Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm), child: boardWidget)), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: boardWidget),
                    SizedBox(width: 300, child: Column(children: [hud, const Spacer(), bottom])),
                  ]);
                },
              );
            },
          ),
        ),
        if (_toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 96,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? ZpColors.gold)),
          ),
      ],
    );
  }

  double _aspect(Connect4State? s) {
    final cols = s?.columns ?? 7;
    final rows = s?.rows ?? 6;
    // Mirrors GridGeometry: width = cols, height = 1.4 + rows + 0.35 (in cells).
    return cols / (rows + 1.75);
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final Connect4Game game;
  final Connect4State? state;
  final List<RoomPlayer> players;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.sm, ZpSpace.md, 0),
      child: Column(children: [
        Row(children: [
          ZpIconButton(icon: Icons.pause_rounded, onPressed: onPause, tooltip: 'Pause'),
          const Spacer(),
          if (s != null) _TurnBanner(game: game, state: s),
          const Spacer(),
          const SizedBox(width: 44),
        ]),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final seat in s.seats)
                _PlayerFrame(
                  seat: seat,
                  state: s,
                  player: players.where((p) => p.userId == seat.userId).firstOrNull,
                  active: s.turnSeat == seat.seat && !s.finished,
                  isMe: seat.seat == game.mySeat,
                  deadline: s.turnSeat == seat.seat ? (game.latestState.value?.turnDeadline ?? s.turnDeadline) : null,
                  totalMs: s.rules.turnTimeoutSeconds * 1000,
                ),
            ],
          ),
        if (game.isSpectator) Padding(padding: const EdgeInsets.only(top: 4), child: Text('SPECTATING', style: t.labelSmall?.copyWith(letterSpacing: 2))),
      ]),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.game, required this.state});
  final Connect4Game game;
  final Connect4State state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat;
    final seatColor = state.finished ? (state.winnerSeat == null ? ZpColors.champagne : GalaxyPalette.seat(state.winnerSeat!)) : GalaxyPalette.seat(state.turnSeat);
    final text = state.finished
        ? state.draw
            ? 'Draw'
            : state.winnerSeat == game.mySeat
                ? 'Victory'
                : '${state.seatOrNull(state.winnerSeat)?.displayName ?? 'Player'} wins'
        : mine
            ? 'Your move'
            : '${state.current.displayName} is thinking';
    return AnimatedSwitcher(
      duration: ZpDurations.base,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: 8),
        decoration: BoxDecoration(
          color: ZpColors.obsidian.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          border: Border.all(color: seatColor.withValues(alpha: 0.8)),
          boxShadow: mine && !state.finished ? [BoxShadow(color: seatColor.withValues(alpha: 0.4), blurRadius: 16)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: seatColor, boxShadow: [BoxShadow(color: seatColor.withValues(alpha: 0.8), blurRadius: 8)])),
          const SizedBox(width: ZpSpace.sm),
          Text(text, style: t.titleSmall?.copyWith(color: mine ? GalaxyPalette.seatLight(game.mySeat ?? 0) : ZpColors.ivory)),
        ]),
      ),
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  const _PlayerFrame({required this.seat, required this.state, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final Connect4Seat seat;
  final Connect4State state;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = GalaxyPalette.seat(seat.seat);
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final winner = state.finished && state.winnerSeat == seat.seat;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TurnTimerRing(
          deadlineMs: active ? deadline : null,
          totalMs: totalMs,
          size: 62,
          color: color,
          child: ZpAvatar(player: p, size: 46, seatColor: color, highlight: active || winner, showName: false),
        ),
        const SizedBox(height: 2),
        SizedBox(width: 90, child: Text(isMe ? 'You' : seat.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: active ? GalaxyPalette.seatLight(seat.seat) : ZpColors.textSecondary))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6)])),
          const SizedBox(width: 4),
          Text('${state.discCount(seat.seat)} discs', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
        ]),
        if (winner) Text('Winner', style: t.labelSmall?.copyWith(color: GalaxyPalette.seatLight(seat.seat))),
        if (state.finished && state.draw) Text('Draw', style: t.labelSmall?.copyWith(color: ZpColors.champagne)),
      ]),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final Connect4Game game;
  final Connect4State? state;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.sm, ZpSpace.lg, ZpSpace.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerDisconnectedBanner(players: players),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          ValueListenableBuilder<bool>(
            valueListenable: game.awaitingServer,
            builder: (context, waiting, _) => ValueListenableBuilder<bool>(
              valueListenable: game.busy,
              builder: (context, busy, _) => ValueListenableBuilder<int?>(
                valueListenable: game.selectedColumn,
                builder: (context, selected, _) {
                  final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
                  final canDrop = myTurn && selected != null && !waiting && !busy;
                  final label = game.isSpectator
                      ? 'Watching'
                      : s.finished
                          ? (s.draw ? 'Grid full. Draw.' : (s.winnerSeat == game.mySeat ? 'Four in a row. You win.' : 'Match over'))
                          : !myTurn
                              ? 'Waiting for ${s.current.displayName}'
                              : waiting
                                  ? 'Dropping'
                                  : selected == null
                                      ? (game.cosmetics.confirmDrop ? 'Tap a column to aim' : 'Tap a column to drop')
                                      : 'Column ${selected + 1} locked';
                  return Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(label, style: t.titleMedium?.copyWith(color: myTurn ? GalaxyPalette.seatLight(game.mySeat ?? 0) : ZpColors.textSecondary)),
                        Text('Move ${s.moveCount + 1} of ${s.rows * s.columns}  |  connect ${s.rules.connect}', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
                      ]),
                    ),
                    if (game.cosmetics.confirmDrop)
                      ZpButton(
                        label: 'Drop',
                        icon: Icons.arrow_downward_rounded,
                        onPressed: canDrop ? () => game.requestDrop(selected) : null,
                        loading: waiting,
                      ).animate(target: canDrop ? 1 : 0).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.35)),
                  ]);
                },
              ),
            ),
          ),
      ]),
    );
  }
}
