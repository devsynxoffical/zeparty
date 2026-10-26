import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/board_component.dart';
import 'kingdom_assets.dart';
import 'model/kingdom_state.dart';
import 'snake_ladder_kingdom_game.dart';

/// Full-screen scene: kingdom sky background, Flame board in a square viewport,
/// Flutter HUD (player frames with turn timers, turn banner, roll button, toasts).
class SnakeLadderKingdomScreen extends StatefulWidget {
  const SnakeLadderKingdomScreen({super.key, required this.session, required this.channel});
  final GameSessionContext session;
  final GameChannel channel;

  @override
  State<SnakeLadderKingdomScreen> createState() => _SnakeLadderKingdomScreenState();
}

class _SnakeLadderKingdomScreenState extends State<SnakeLadderKingdomScreen> with WidgetsBindingObserver {
  late final SnakeLadderKingdomGame _game = SnakeLadderKingdomGame(session: widget.session, channel: widget.channel);
  KingdomNotice? _toast;
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
        Image(image: ZpAssets.image(KingdomAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const _KingdomSky()),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x88000000), Color(0x11000000), Color(0x99000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              final boardSide = portrait ? c.maxWidth - 12 : c.maxHeight - 140;
              return ValueListenableBuilder<KingdomState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final boardWidget = Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Raising the islands')),
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

/// Procedural sky used when `backgrounds/kingdom.webp` is missing: dusk gradient,
/// distant mountains and a soft sun halo.
class _KingdomSky extends StatelessWidget {
  const _KingdomSky();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SkyPainter());
}

class _SkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1B1440), Color(0xFF4A2C7A), Color(0xFFB8678A), Color(0xFFE9B27A)], stops: [0, 0.4, 0.75, 1]).createShader(r));
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.62), size.width * 0.22, Paint()..color = const Color(0xFFFFE2A8).withValues(alpha: 0.35)..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.12));
    final mountains = Path()..moveTo(0, size.height);
    final peaks = [0.0, 0.12, 0.25, 0.4, 0.52, 0.66, 0.8, 0.92, 1.0];
    for (var i = 0; i < peaks.length; i++) {
      final x = size.width * peaks[i];
      final y = size.height * (i.isEven ? 0.78 : 0.68 - (i % 3) * 0.03);
      mountains.lineTo(x, y);
    }
    mountains
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(mountains, Paint()..color = const Color(0xFF2B1F4D).withValues(alpha: 0.85));
    final rng = [0.1, 0.33, 0.52, 0.71, 0.88, 0.2, 0.62, 0.95];
    for (var i = 0; i < rng.length; i++) {
      canvas.drawCircle(Offset(size.width * rng[i], size.height * (0.05 + (i * 0.07) % 0.4)), 1.5 + (i % 3) * 0.6, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final SnakeLadderKingdomGame game;
  final KingdomState? state;
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
                  boardSize: s.boardSize,
                  player: players.where((p) => p.userId == seat.userId).firstOrNull,
                  active: s.turnSeat == seat.seat && s.phase != KingdomPhase.finished,
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
  final SnakeLadderKingdomGame game;
  final KingdomState state;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat;
    final color = KingdomBoardComponent.colorOf(state.current.color);
    final text = state.phase == KingdomPhase.finished
        ? 'Match over'
        : mine
            ? 'Your roll'
            : '${state.current.displayName} is rolling';
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
  const _PlayerFrame({required this.seat, required this.boardSize, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final KingdomSeat seat;
  final int boardSize;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = KingdomBoardComponent.colorOf(seat.color);
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final progress = (seat.position / boardSize).clamp(0.0, 1.0);
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
        SizedBox(
          width: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: color.withValues(alpha: 0.2), color: seat.finishedPlacement != null ? ZpColors.goldLight : color),
          ),
        ),
        Text(
          seat.finishedPlacement != null ? switch (seat.finishedPlacement!) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${seat.finishedPlacement}th' } : (seat.position == 0 ? 'Camp' : 'Square ${seat.position}'),
          style: t.labelSmall?.copyWith(color: seat.finishedPlacement != null ? ZpColors.goldLight : ZpColors.textMuted),
        ),
      ]),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final SnakeLadderKingdomGame game;
  final KingdomState? state;
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
                final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && s.phase != KingdomPhase.finished;
                final canRoll = myTurn && s.phase == KingdomPhase.roll && !waiting && !busy;
                final label = game.isSpectator
                    ? 'Watching'
                    : s.phase == KingdomPhase.finished
                        ? 'Finished'
                        : !myTurn
                            ? 'Waiting for ${s.current.displayName}'
                            : (waiting ? 'Rolling' : 'Roll the crystal die');
                final me = game.mySeat == null ? null : s.seatOrNull(game.mySeat);
                return Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: t.titleMedium?.copyWith(color: canRoll ? ZpColors.goldLight : ZpColors.textSecondary)),
                      if (s.dice != null) Text('Last roll ${s.dice}', style: t.labelSmall),
                      if (me != null && me.finishedPlacement == null) Text('${s.boardSize - me.position} squares to the castle', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
                    ]),
                  ),
                  ZpButton(
                    label: 'Roll',
                    icon: Icons.casino_rounded,
                    onPressed: canRoll ? game.requestRoll : null,
                    loading: waiting && s.phase == KingdomPhase.roll,
                  ).animate(target: canRoll ? 1 : 0).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.35)),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}
