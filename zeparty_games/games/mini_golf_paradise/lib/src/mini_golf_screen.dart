import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'mini_golf_assets.dart';
import 'mini_golf_game.dart';
import 'model/mini_golf_state.dart';
import 'widgets/scorecard.dart';

/// Full-screen Mini Golf scene: resort background, Flame course in a letterboxed
/// portrait viewport, Flutter HUD (player frames with timers, hole info, scorecard,
/// toasts, banners).
class MiniGolfScreen extends StatefulWidget {
  const MiniGolfScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final MiniGolfCosmetics cosmetics;

  @override
  State<MiniGolfScreen> createState() => _MiniGolfScreenState();
}

class _MiniGolfScreenState extends State<MiniGolfScreen> with WidgetsBindingObserver {
  late final MiniGolfGame _game = MiniGolfGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  MiniGolfNotice? _toast;
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
    _toastTimer = Timer(const Duration(milliseconds: 2000), () {
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
        Image(
          image: ZpAssets.image(MiniGolfAssets.background),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E3B5E), Color(0xFF14797A), Color(0xFF0B2A3A)])),
          ),
        ),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x99000000), Color(0x11000000), Color(0x22000000), Color(0xAA000000)]))),
        SafeArea(
          child: ValueListenableBuilder<MiniGolfState?>(
            valueListenable: _game.displayState,
            builder: (context, state, _) {
              final aspect = state == null ? 100 / 160 : state.course.width / state.course.height;
              final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
              final courseWidget = Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm, vertical: ZpSpace.xs),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Raking the greens')),
                  ),
                ),
              );
              final bottom = _BottomHud(game: _game, state: state);
              return LayoutBuilder(builder: (context, c) {
                final portrait = c.maxHeight >= c.maxWidth;
                if (portrait) return Column(children: [hud, Expanded(child: courseWidget), bottom]);
                return Row(children: [
                  Expanded(child: courseWidget),
                  SizedBox(width: 320, child: Column(children: [hud, const Spacer(), bottom])),
                ]);
              });
            },
          ),
        ),
        // Scorecard overlay
        ValueListenableBuilder<bool>(
          valueListenable: _game.scorecardVisible,
          builder: (context, visible, _) {
            if (!visible) return const SizedBox.shrink();
            final s = _game.displayState.value;
            if (s == null) return const SizedBox.shrink();
            return ZpOverlay(
              dismissible: true,
              onDismiss: _game.toggleScorecard,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ZpSpace.lg),
                  child: Scorecard(state: s, mySeat: _game.mySeat, onClose: _game.toggleScorecard),
                ),
              ),
            ).animate().fadeIn(duration: 220.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), curve: Curves.easeOutBack);
          },
        ),
        // Banners (hole intro, hole in one, match over)
        ValueListenableBuilder<MiniGolfBanner?>(
          valueListenable: _game.banner,
          builder: (context, b, _) {
            if (b == null) return const SizedBox.shrink();
            return Positioned(left: 0, right: 0, top: MediaQuery.of(context).size.height * 0.34, child: IgnorePointer(child: _Banner(key: ValueKey(b), banner: b)));
          },
        ),
        if (_toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 100,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? ZpColors.gold)),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.banner});
  final MiniGolfBanner banner;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gold = banner.kind != BannerKind.holeIntro;
    final accent = switch (banner.kind) { BannerKind.holeIntro => const Color(0xFF2BC0B4), BannerKind.holeInOne => ZpColors.goldLight, BannerKind.matchOver => ZpColors.goldLight };
    final body = Container(
      margin: const EdgeInsets.symmetric(horizontal: ZpSpace.xl),
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.xl, vertical: ZpSpace.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [ZpColors.obsidian.withValues(alpha: 0.92), ZpColors.panel.withValues(alpha: 0.92)]),
        borderRadius: BorderRadius.circular(ZpRadius.lg),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 30)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(banner.title, textAlign: TextAlign.center, style: (gold ? t.headlineMedium : t.titleLarge)?.copyWith(color: accent, fontWeight: FontWeight.w800, letterSpacing: gold ? 2 : 0.5)),
        if (banner.subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(banner.subtitle!, style: t.titleSmall?.copyWith(color: ZpColors.textSecondary))),
      ]),
    );
    return switch (banner.kind) {
      BannerKind.holeIntro => body.animate().fadeIn(duration: 260.ms).slideX(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
      BannerKind.holeInOne => body.animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms).then().shimmer(duration: 900.ms, color: Colors.white.withValues(alpha: 0.5)),
      BannerKind.matchOver => body.animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
    };
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final MiniGolfGame game;
  final MiniGolfState? state;
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
          ZpIconButton(icon: Icons.list_alt_rounded, onPressed: game.toggleScorecard, tooltip: 'Scorecard'),
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
  final MiniGolfGame game;
  final MiniGolfState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat && !state.finished;
    final color = ZpColors.seat(state.turnSeat);
    final text = state.finished ? 'Match over' : (mine ? 'Your putt' : '${state.current.displayName} is putting');
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
  const _PlayerFrame({required this.seat, required this.state, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final MiniGolfSeat seat;
  final MiniGolfState state;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = ZpColors.seat(seat.seat);
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final strokes = state.strokesOnCurrentHole(seat.seat);
    final placement = state.placements.indexOf(seat.seat);
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
        Text(
          state.finished && placement >= 0 ? '${_ordinal(placement + 1)} (${seat.total})' : (seat.holed ? 'In: $strokes' : 'Strokes: $strokes'),
          style: t.labelSmall?.copyWith(color: seat.holed || state.finished ? ZpColors.goldLight : ZpColors.textMuted),
        ),
      ]),
    );
  }

  static String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state});
  final MiniGolfGame game;
  final MiniGolfState? state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    final shell = GameShellScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.sm, ZpSpace.lg, ZpSpace.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (shell != null) PlayerDisconnectedBanner(players: shell.players),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          ValueListenableBuilder<bool>(
            valueListenable: game.awaitingServer,
            builder: (context, waiting, _) => ValueListenableBuilder<bool>(
              valueListenable: game.busy,
              builder: (context, busy, _) {
                final me = s.seatOrNull(game.mySeat);
                final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
                final label = game.isSpectator
                    ? 'Watching'
                    : s.finished
                        ? 'Finished'
                        : waiting
                            ? 'Putting'
                            : busy
                                ? 'Ball in motion'
                                : myTurn
                                    ? 'Drag back from your ball, release to putt'
                                    : 'Waiting for ${s.current.displayName}';
                final me0 = me;
                final total = me0?.total ?? 0;
                return Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hole ${s.holeIndex + 1}/${s.holeCount}: ${s.course.name}', style: t.titleMedium?.copyWith(color: ZpColors.ivory)),
                      Text('Par ${s.course.par}${me0 != null ? '  |  You: ${s.strokesOnCurrentHole(me0.seat)} this hole, $total total' : ''}', style: t.labelSmall?.copyWith(color: ZpColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(label, style: t.labelMedium?.copyWith(color: myTurn && !waiting && !busy ? ZpColors.goldLight : ZpColors.textMuted)),
                    ]),
                  ),
                  ZpButton(label: 'Scores', icon: Icons.list_alt_rounded, onPressed: game.toggleScorecard),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}
