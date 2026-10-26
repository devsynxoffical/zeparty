import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'air_hockey_assets.dart';
import 'air_hockey_game.dart';
import 'components/arena_component.dart';
import 'model/air_hockey_state.dart';
import 'model/physics.dart';

/// Full-screen Neon Air Hockey scene: arena background, Flame table in a
/// portrait viewport, holographic scoreboard, latency indicator, banners.
class AirHockeyScreen extends StatefulWidget {
  const AirHockeyScreen({super.key, required this.session, required this.channel});
  final GameSessionContext session;
  final GameChannel channel;

  @override
  State<AirHockeyScreen> createState() => _AirHockeyScreenState();
}

class _AirHockeyScreenState extends State<AirHockeyScreen> with WidgetsBindingObserver {
  late final AirHockeyGame _game = AirHockeyGame(session: widget.session, channel: widget.channel);
  AirHockeyNotice? _toast;
  AirHockeyNotice? _banner;
  Timer? _toastTimer;
  Timer? _bannerTimer;
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
    if (n.big) {
      _bannerTimer?.cancel();
      setState(() => _banner = n);
      _bannerTimer = Timer(const Duration(milliseconds: 1100), () {
        if (mounted) setState(() => _banner = null);
      });
      return;
    }
    _toastTimer?.cancel();
    setState(() => _toast = n);
    _toastTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The match keeps running on the server; we only stop rendering.
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
    _bannerTimer?.cancel();
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
        Image(image: ZpAssets.image(AirHockeyAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B1030), Color(0xFF05060C)])))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x33000000), Color(0xBB000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              return ValueListenableBuilder<AirHockeyState?>(
                valueListenable: _game.latestState,
                builder: (context, state, _) {
                  final hud = _Scoreboard(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final table = Center(
                    child: AspectRatio(
                      aspectRatio: AirHockeyPhysics.tableWidth / AirHockeyPhysics.tableHeight,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Stack(fit: StackFit.expand, children: [
                          GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Charging the arena')),
                          _FaceoffCountdown(game: _game),
                          if (_banner != null) _BigBanner(key: ValueKey(_banner), notice: _banner!),
                          _FinishOverlay(game: _game, players: players),
                        ]),
                      ),
                    ),
                  );
                  final bottom = _BottomBar(game: _game, players: players);
                  if (portrait) {
                    return Column(children: [hud, Expanded(child: table), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: table),
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
            top: MediaQuery.of(context).padding.top + 110,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? NeonPalette.cyan)),
          ),
      ],
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.game, required this.state, required this.players, required this.onPause});
  final AirHockeyGame game;
  final AirHockeyState? state;
  final List<RoomPlayer> players;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    final bottom = game.bottomSeat;
    final top = 1 - bottom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.sm, ZpSpace.md, ZpSpace.xs),
      child: Column(children: [
        Row(children: [
          ZpIconButton(icon: Icons.pause_rounded, onPressed: onPause, tooltip: 'Pause'),
          const Spacer(),
          _LatencyChip(game: game),
          const SizedBox(width: ZpSpace.sm),
          _ClockChip(game: game, state: s),
        ]),
        const SizedBox(height: ZpSpace.sm),
        if (s != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [NeonPalette.cyan.withValues(alpha: 0.12), const Color(0xCC0A0D1C), NeonPalette.magenta.withValues(alpha: 0.12)]),
              borderRadius: BorderRadius.circular(ZpRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              boxShadow: [BoxShadow(color: NeonPalette.cyan.withValues(alpha: 0.15), blurRadius: 24), BoxShadow(color: NeonPalette.magenta.withValues(alpha: 0.12), blurRadius: 24)],
            ),
            child: Row(children: [
              Expanded(child: _SeatCell(seat: s.seatAt(bottom), player: _playerOf(bottom), color: game.colorOfSeat(bottom), isMe: bottom == game.mySeat, alignEnd: false, leader: s.leaderSeat == bottom)),
              _ScoreDigits(a: s.seatAt(bottom).score, b: s.seatAt(top).score, colorA: game.colorOfSeat(bottom), colorB: game.colorOfSeat(top), goalsToWin: s.rules.goalsToWin),
              Expanded(child: _SeatCell(seat: s.seatAt(top), player: _playerOf(top), color: game.colorOfSeat(top), isMe: top == game.mySeat, alignEnd: true, leader: s.leaderSeat == top)),
            ]),
          ),
        if (s != null && s.suddenDeath && !s.finished)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('SUDDEN DEATH  next goal wins', style: t.labelSmall?.copyWith(color: Colors.amberAccent, letterSpacing: 1.5))),
        if (game.isSpectator) Padding(padding: const EdgeInsets.only(top: 4), child: Text('SPECTATING', style: t.labelSmall?.copyWith(letterSpacing: 2))),
      ]),
    );
  }

  RoomPlayer? _playerOf(int seat) {
    final id = state?.seatAt(seat).userId;
    return players.where((p) => p.userId == id).firstOrNull;
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({required this.seat, required this.player, required this.color, required this.isMe, required this.alignEnd, required this.leader});
  final AirHockeySeat seat;
  final RoomPlayer? player;
  final Color color;
  final bool isMe;
  final bool alignEnd;
  final bool leader;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final avatar = ZpAvatar(player: p, size: 40, seatColor: color, highlight: leader, showName: false);
    final name = Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(isMe ? 'You' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelLarge?.copyWith(color: color)),
        Text(dim ? 'offline' : (isMe ? 'defending bottom' : 'defending top'), style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
      ],
    );
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Row(
        mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: alignEnd ? [Flexible(child: name), const SizedBox(width: ZpSpace.sm), avatar] : [avatar, const SizedBox(width: ZpSpace.sm), Flexible(child: name)],
      ),
    );
  }
}

class _ScoreDigits extends StatelessWidget {
  const _ScoreDigits({required this.a, required this.b, required this.colorA, required this.colorB, required this.goalsToWin});
  final int a;
  final int b;
  final Color colorA;
  final Color colorB;
  final int goalsToWin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    TextStyle digit(Color c) => (t.displaySmall ?? const TextStyle(fontSize: 34)).copyWith(color: c, fontWeight: FontWeight.w800, shadows: [Shadow(color: c.withValues(alpha: 0.8), blurRadius: 18)]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$a', key: ValueKey('a$a'), style: digit(colorA)).animate(key: ValueKey('fa$a')).scale(begin: const Offset(1.4, 1.4), end: const Offset(1, 1), duration: 350.ms, curve: Curves.easeOutBack),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: digit(Colors.white.withValues(alpha: 0.6)))),
          Text('$b', key: ValueKey('b$b'), style: digit(colorB)).animate(key: ValueKey('fb$b')).scale(begin: const Offset(1.4, 1.4), end: const Offset(1, 1), duration: 350.ms, curve: Curves.easeOutBack),
        ]),
        Text('first to $goalsToWin', style: t.labelSmall?.copyWith(color: ZpColors.textMuted, letterSpacing: 1)),
      ]),
    );
  }
}

class _ClockChip extends StatelessWidget {
  const _ClockChip({required this.game, required this.state});
  final AirHockeyGame game;
  final AirHockeyState? state;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: game.clockMs,
      builder: (context, ms, _) {
        final s = state;
        final untimed = s != null && s.rules.matchSeconds == 0;
        final total = (ms / 1000).ceil();
        final text = untimed ? 'no clock' : '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
        final low = !untimed && ms <= 15_000 && ms > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: 6),
          decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(ZpRadius.pill), border: Border.all(color: (low ? Colors.amberAccent : Colors.white).withValues(alpha: 0.35))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.timer_outlined, size: 14, color: low ? Colors.amberAccent : ZpColors.textSecondary),
            const SizedBox(width: 6),
            Text(text, style: t.titleSmall?.copyWith(color: low ? Colors.amberAccent : ZpColors.ivory, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
      },
    );
  }
}

/// Round-trip latency between a paddle input and its server acknowledgement.
class _LatencyChip extends StatelessWidget {
  const _LatencyChip({required this.game});
  final AirHockeyGame game;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<int?>(
      valueListenable: game.latencyMs,
      builder: (context, ms, _) {
        if (game.isSpectator) return const SizedBox.shrink();
        final color = ms == null ? ZpColors.textMuted : ms < 80 ? ZpColors.success : ms < 160 ? Colors.amberAccent : ZpColors.danger;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm, vertical: 6),
          decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(ZpRadius.pill), border: Border.all(color: color.withValues(alpha: 0.5))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.network_check_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(ms == null ? '-- ms' : '$ms ms', style: t.labelSmall?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        );
      },
    );
  }
}

class _FaceoffCountdown extends StatelessWidget {
  const _FaceoffCountdown({required this.game});
  final AirHockeyGame game;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<int?>(
      valueListenable: game.faceoffMs,
      builder: (context, ms, _) {
        if (ms == null) return const SizedBox.shrink();
        final n = (ms / 500).ceil().clamp(1, 3);
        return IgnorePointer(
          child: Center(
            child: Text(
              '$n',
              key: ValueKey(n),
              style: (t.displayLarge ?? const TextStyle(fontSize: 64)).copyWith(color: Colors.white, fontWeight: FontWeight.w900, shadows: const [Shadow(color: NeonPalette.cyan, blurRadius: 30), Shadow(color: NeonPalette.magenta, blurRadius: 50)]),
            ).animate(key: ValueKey('fo$n')).scale(begin: const Offset(1.6, 1.6), end: const Offset(1, 1), duration: 380.ms, curve: Curves.easeOutCubic).fadeIn(duration: 150.ms),
          ),
        );
      },
    );
  }
}

class _BigBanner extends StatelessWidget {
  const _BigBanner({super.key, required this.notice});
  final AirHockeyNotice notice;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = notice.color ?? NeonPalette.white;
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.xl, vertical: ZpSpace.md),
          decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(ZpRadius.lg), border: Border.all(color: c.withValues(alpha: 0.7)), boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 40)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (notice.icon != null) Padding(padding: const EdgeInsets.only(right: 10), child: Icon(notice.icon, color: c, size: 30)),
            Text(notice.text, style: (t.displaySmall ?? const TextStyle(fontSize: 34)).copyWith(color: c, fontWeight: FontWeight.w900, letterSpacing: 3, shadows: [Shadow(color: c, blurRadius: 24)])),
          ]),
        ).animate().scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 320.ms, curve: Curves.easeOutBack).fadeIn(duration: 120.ms).then(delay: 500.ms).fadeOut(duration: 300.ms),
      ),
    );
  }
}

class _FinishOverlay extends StatelessWidget {
  const _FinishOverlay({required this.game, required this.players});
  final AirHockeyGame game;
  final List<RoomPlayer> players;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<AirHockeyFinish?>(
      valueListenable: game.finish,
      builder: (context, f, _) {
        if (f == null) return const SizedBox.shrink();
        final s = game.latestState.value;
        final winner = f.winnerSeat;
        final color = winner == null ? NeonPalette.white : game.colorOfSeat(winner);
        final title = winner == null ? 'DRAW' : (winner == game.mySeat ? 'VICTORY' : game.isSpectator ? '${s?.seatAt(winner).displayName ?? 'Player'} WINS' : 'DEFEAT');
        final reason = switch (f.reason) { 'goals' => 'Goal limit reached', 'time' => 'Time expired', 'sudden_death' => 'Sudden death goal', 'forfeit' => 'Opponent forfeited', _ => 'Match over' };
        return IgnorePointer(
          child: Container(
            color: Colors.black.withValues(alpha: 0.35),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: (t.displayMedium ?? const TextStyle(fontSize: 44)).copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 4, shadows: [Shadow(color: color, blurRadius: 36)]))
                    .animate()
                    .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut)
                    .shimmer(delay: 600.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6)),
                const SizedBox(height: ZpSpace.sm),
                Text('${f.score[game.bottomSeat]}  :  ${f.score[1 - game.bottomSeat]}', style: t.headlineMedium?.copyWith(color: ZpColors.ivory, fontWeight: FontWeight.w700)).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 4),
                Text(reason, style: t.bodyMedium?.copyWith(color: ZpColors.textSecondary)).animate().fadeIn(delay: 500.ms),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.game, required this.players});
  final AirHockeyGame game;
  final List<RoomPlayer> players;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.xs, ZpSpace.lg, ZpSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerDisconnectedBanner(players: players),
        const SizedBox(height: ZpSpace.xs),
        ValueListenableBuilder<AirHockeyFinish?>(
          valueListenable: game.finish,
          builder: (context, f, _) => Text(
            f != null
                ? 'Match over'
                : game.isSpectator
                    ? 'Watching live'
                    : 'Drag anywhere on your half to move the mallet',
            style: t.labelMedium?.copyWith(color: ZpColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}
