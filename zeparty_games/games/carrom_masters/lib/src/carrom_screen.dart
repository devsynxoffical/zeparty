import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'carrom_assets.dart';
import 'carrom_game.dart';
import 'model/carrom_state.dart';

/// Full-screen Carrom scene: club background, Flame board in a square
/// viewport, Flutter HUD (seat frames with timers, queen chip, coin trays,
/// aim readout, toasts).
class CarromScreen extends StatefulWidget {
  const CarromScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final CarromCosmetics cosmetics;

  @override
  State<CarromScreen> createState() => _CarromScreenState();
}

class _CarromScreenState extends State<CarromScreen> with WidgetsBindingObserver {
  late final CarromGame _game = CarromGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  CarromNotice? _toast;
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
        Image(image: ZpAssets.image(CarromAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A160B), Color(0xFF120905)])))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x33000000), Color(0xBB000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              final boardSide = portrait ? c.maxWidth : c.maxHeight - 120;
              return ValueListenableBuilder<CarromState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final boardWidget = Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Polishing the board')),
                    ),
                  );
                  final bottom = _BottomHud(game: _game, state: state, players: players);
                  if (portrait) {
                    return Column(children: [hud, Expanded(child: boardWidget), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: boardWidget),
                    SizedBox(width: 320, child: Column(children: [hud, const Spacer(), bottom])),
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
            top: MediaQuery.of(context).padding.top + 104,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? ZpColors.gold)),
          ),
      ],
    );
  }
}

Color sideColor(CarromSide side) => side == CarromSide.white ? ZpColors.ivory : const Color(0xFF8C7B6B);

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final CarromGame game;
  final CarromState? state;
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
          if (s != null) _QueenChip(state: s) else const SizedBox(width: 44),
        ]),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final seat in s.seats)
                _SeatFrame(
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
  final CarromGame game;
  final CarromState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat && !state.finished;
    final current = state.seatOrNull(state.turnSeat);
    final color = current == null ? ZpColors.gold : sideColor(current.side);
    final text = state.finished
        ? (state.winnerSide == null ? 'Match over' : '${state.winnerSide == CarromSide.white ? 'White' : 'Black'} wins')
        : mine
            ? (state.queen.status == QueenState.pending && state.queen.pendingBy == current?.side ? 'Cover the queen' : (state.strikesThisTurn > 0 ? 'Strike again' : 'Your strike'))
            : '${current?.displayName ?? 'Player'} is aiming';
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
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: ZpColors.goldDeep, width: 1))),
          const SizedBox(width: ZpSpace.sm),
          Text(text, style: t.titleSmall?.copyWith(color: mine ? ZpColors.goldLight : ZpColors.ivory)),
        ]),
      ),
    );
  }
}

/// Queen status: on the board, pending cover, or covered by a side.
class _QueenChip extends StatelessWidget {
  const _QueenChip({required this.state});
  final CarromState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = state.queen;
    final (label, color) = switch (q.status) {
      QueenState.board => ('Queen', ZpColors.textSecondary),
      QueenState.pending => ('Cover', ZpColors.amber),
      QueenState.covered => (q.coveredBy == CarromSide.white ? 'White' : 'Black', ZpColors.ruby),
    };
    return Tooltip(
      message: switch (q.status) { QueenState.board => 'Queen on the board', QueenState.pending => 'Queen pocketed, must be covered', QueenState.covered => 'Queen covered' },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(ZpRadius.pill), border: Border.all(color: color.withValues(alpha: 0.7))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFFE05A62), Color(0xFF7E141C)]), border: Border.all(color: ZpColors.goldLight, width: 1))),
          const SizedBox(width: 6),
          Text(label, style: t.labelMedium?.copyWith(color: color)),
        ]),
      ),
    );
  }
}

class _SeatFrame extends StatelessWidget {
  const _SeatFrame({required this.seat, required this.state, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final CarromSeat seat;
  final CarromState state;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = sideColor(seat.side);
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final placement = state.finished ? state.placements.indexOf(seat.seat) : -1;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TurnTimerRing(
          deadlineMs: active ? deadline : null,
          totalMs: totalMs,
          size: 58,
          color: active ? ZpColors.goldLight : color,
          child: ZpAvatar(player: p, size: 42, seatColor: color, highlight: active, showName: false),
        ),
        const SizedBox(height: 2),
        SizedBox(width: 76, child: Text(isMe ? 'You' : seat.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: active ? ZpColors.goldLight : ZpColors.textSecondary))),
        Text(seat.side == CarromSide.white ? 'White' : 'Black', style: t.labelSmall?.copyWith(color: color.withValues(alpha: 0.8))),
        if (placement >= 0 && state.winnerSide != null)
          Text(seat.side == state.winnerSide ? 'Winner' : 'Runner-up', style: t.labelSmall?.copyWith(color: seat.side == state.winnerSide ? ZpColors.goldLight : ZpColors.textMuted)),
      ]),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final CarromGame game;
  final CarromState? state;
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
          Row(children: [
            Expanded(child: _Tray(side: CarromSide.white, state: s, highlight: s.seatOrNull(game.mySeat)?.side == CarromSide.white)),
            const SizedBox(width: ZpSpace.md),
            Expanded(child: _Tray(side: CarromSide.black, state: s, highlight: s.seatOrNull(game.mySeat)?.side == CarromSide.black)),
          ]),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          ValueListenableBuilder<AimInfo?>(
            valueListenable: game.aimInfo,
            builder: (context, aim, _) => ValueListenableBuilder<bool>(
              valueListenable: game.awaitingServer,
              builder: (context, waiting, _) => ValueListenableBuilder<bool>(
                valueListenable: game.busy,
                builder: (context, busy, _) {
                  final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
                  final String label;
                  if (game.isSpectator) {
                    label = 'Watching';
                  } else if (s.finished) {
                    label = 'Finished';
                  } else if (busy) {
                    label = 'Coins in motion';
                  } else if (!myTurn) {
                    label = 'Waiting for ${s.current.displayName}';
                  } else if (waiting) {
                    label = 'Striking';
                  } else if (aim == null) {
                    label = 'Drag the striker to place it, pull back to aim';
                  } else if (aim.mode == AimMode.place) {
                    label = aim.valid ? 'Striker at ${aim.strikerX.round()}' : 'Striker overlaps a coin';
                  } else {
                    label = 'Power ${(aim.power * 100).round()}%';
                  }
                  return Row(children: [
                    Expanded(child: Text(label, style: t.titleSmall?.copyWith(color: myTurn && !busy ? ZpColors.goldLight : ZpColors.textSecondary))),
                    if (aim != null && aim.mode == AimMode.aim)
                      SizedBox(
                        width: 90,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(ZpRadius.pill),
                          child: LinearProgressIndicator(value: aim.power, minHeight: 8, backgroundColor: Colors.white.withValues(alpha: 0.1), color: Color.lerp(ZpColors.goldLight, ZpColors.ruby, aim.power)),
                        ),
                      ),
                    if (s.rules.pointsToWin > 1) Padding(padding: const EdgeInsets.only(left: ZpSpace.md), child: Text('Boards ${s.boardsWon[CarromSide.white]} : ${s.boardsWon[CarromSide.black]}', style: t.labelMedium?.copyWith(color: ZpColors.champagne))),
                  ]);
                },
              ),
            ),
          ),
      ]),
    );
  }
}

/// Pocketed coins of one side, laid out as small discs with the queen when covered.
class _Tray extends StatelessWidget {
  const _Tray({required this.side, required this.state, required this.highlight});
  final CarromSide side;
  final CarromState state;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pocketed = state.pocketedFor(side).length;
    final total = state.rules.coinsPerSide;
    final hasQueen = state.queen.status == QueenState.covered && state.queen.coveredBy == side;
    final dues = state.dues[side] ?? 0;
    final color = sideColor(side);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: ZpSpace.sm),
      decoration: BoxDecoration(
        color: ZpColors.obsidian.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ZpRadius.md),
        border: Border.all(color: (highlight ? ZpColors.gold : ZpColors.divider).withValues(alpha: highlight ? 0.7 : 1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(side == CarromSide.white ? 'White' : 'Black', style: t.labelMedium?.copyWith(color: highlight ? ZpColors.goldLight : ZpColors.textSecondary)),
          const Spacer(),
          Text('$pocketed / $total', style: t.labelMedium?.copyWith(color: ZpColors.ivory)),
          if (dues > 0) Padding(padding: const EdgeInsets.only(left: 6), child: Text('due $dues', style: t.labelSmall?.copyWith(color: ZpColors.danger))),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 3, runSpacing: 3, children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < pocketed ? color : color.withValues(alpha: 0.15),
                border: Border.all(color: i < pocketed ? ZpColors.goldDeep : Colors.transparent, width: 1),
              ),
            ).animate(target: i < pocketed ? 1 : 0).scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.easeOutBack),
          if (hasQueen)
            Container(width: 11, height: 11, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xFFE05A62), Color(0xFF7E141C)]), border: Border.all(color: ZpColors.goldLight, width: 1))),
        ]),
      ]),
    );
  }
}
