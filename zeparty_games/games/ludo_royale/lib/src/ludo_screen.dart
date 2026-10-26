import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/board_component.dart';
import 'ludo_game.dart';
import 'model/board.dart';
import 'model/ludo_state.dart';

/// Full-screen Ludo scene: chamber background, Flame board in a square viewport,
/// Flutter HUD (player frames, turn banner, timer, roll button, toasts).
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final LudoCosmetics cosmetics;

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> with WidgetsBindingObserver {
  late final LudoGame _game = LudoGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  LudoNotice? _toast;
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
    // Pause rendering in background; the server keeps the match going.
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
    final bgKey = LudoAssets.backgrounds[widget.cosmetics.board] ?? LudoAssets.backgrounds['imperial_palace']!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: ZpAssets.image(bgKey), fit: BoxFit.cover, errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(gradient: ZpColors.backdrop))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x22000000), Color(0xAA000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              final boardSide = portrait ? c.maxWidth - 16 : c.maxHeight - 140;
              return ValueListenableBuilder<LudoState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final boardWidget = Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Setting the board')),
                    ),
                  );
                  final bottom = _BottomHud(game: _game, state: state, players: players);
                  if (portrait) {
                    return Column(children: [hud, Expanded(child: boardWidget), bottom]);
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
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final LudoGame game;
  final LudoState? state;
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
                  player: players.where((p) => p.userId == seat.userId).firstOrNull,
                  active: s.turnSeat == seat.seat && s.phase != LudoPhase.finished,
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
  final LudoGame game;
  final LudoState state;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat;
    final color = BoardComponent.colorOf(state.current.color);
    final text = state.phase == LudoPhase.finished
        ? 'Match over'
        : mine
            ? (state.phase == LudoPhase.roll ? 'Your roll' : 'Choose a token')
            : '${state.current.displayName} ${state.phase == LudoPhase.roll ? 'is rolling' : 'is moving'}';
    return AnimatedSwitcher(
      duration: ZpDurations.base,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: 8),
        decoration: BoxDecoration(
          color: ZpColors.obsidian.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          border: Border.all(color: (mine ? ZpColors.goldLight : color).withValues(alpha: 0.8)),
          boxShadow: mine ? [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.35), blurRadius: 16)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: ZpSpace.sm),
          Text(text, style: t.titleSmall?.copyWith(color: mine ? ZpColors.goldLight : ZpColors.ivory)),
        ]),
      ),
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  const _PlayerFrame({required this.seat, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final LudoSeat seat;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = BoardComponent.colorOf(seat.color);
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TurnTimerRing(
          deadlineMs: active ? deadline : null,
          totalMs: totalMs,
          size: 62,
          color: color,
          child: ZpAvatar(player: p, size: 46, seatColor: color, highlight: active, showName: false),
        ),
        const SizedBox(height: 2),
        SizedBox(width: 78, child: Text(isMe ? 'You' : seat.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: active ? ZpColors.goldLight : ZpColors.textSecondary))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < seat.tokens.length; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(shape: BoxShape.circle, color: seat.tokens[i] == homeStep ? ZpColors.goldLight : (seat.tokens[i] < 0 ? color.withValues(alpha: 0.3) : color)),
            ),
        ]),
        if (seat.finishedPlacement != null) Text(switch (seat.finishedPlacement!) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${seat.finishedPlacement}th' }, style: t.labelSmall?.copyWith(color: ZpColors.goldLight)),
      ]),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final LudoGame game;
  final LudoState? state;
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
              builder: (context, busy, _) {
                final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && s.phase != LudoPhase.finished;
                final canRoll = myTurn && s.phase == LudoPhase.roll && !waiting && !busy;
                final label = game.isSpectator
                    ? 'Watching'
                    : s.phase == LudoPhase.finished
                        ? 'Finished'
                        : !myTurn
                            ? 'Waiting for ${s.current.displayName}'
                            : s.phase == LudoPhase.roll
                                ? (waiting ? 'Rolling' : 'Roll the dice')
                                : 'Tap a highlighted token';
                return Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: t.titleMedium?.copyWith(color: canRoll ? ZpColors.goldLight : ZpColors.textSecondary)),
                      if (s.dice != null && s.phase == LudoPhase.move) Text('Rolled ${s.dice}', style: t.labelSmall),
                      if (s.consecutiveSixes > 0 && myTurn) Text('${s.consecutiveSixes} six${s.consecutiveSixes > 1 ? 'es' : ''} in a row', style: t.labelSmall?.copyWith(color: ZpColors.goldLight)),
                    ]),
                  ),
                  ZpButton(
                    label: 'Roll',
                    icon: Icons.casino_rounded,
                    onPressed: canRoll ? game.requestRoll : null,
                    loading: waiting && s.phase == LudoPhase.roll,
                  ).animate(target: canRoll ? 1 : 0).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.35)),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}
