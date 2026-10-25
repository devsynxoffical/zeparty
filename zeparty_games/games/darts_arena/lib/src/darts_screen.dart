import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'darts_assets.dart';
import 'darts_game.dart';
import 'model/checkouts.dart';
import 'model/darts_state.dart';

/// Full-screen Darts Arena scene: oak lounge background with a warm spotlight
/// vignette, the Flame board in a square viewport, Flutter HUD (player frames,
/// turn banner, timers, scoreboard, darts left, checkout hints, toasts).
class DartsScreen extends StatefulWidget {
  const DartsScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final DartsCosmetics cosmetics;

  @override
  State<DartsScreen> createState() => _DartsScreenState();
}

class _DartsScreenState extends State<DartsScreen> with WidgetsBindingObserver {
  late final DartsGame _game = DartsGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  DartsNotice? _toast;
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
        Image(image: ZpAssets.image(DartsAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const _OakWall()),
        // Warm spotlight vignette: bright on the board, dark oak at the edges.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -0.15), radius: 0.95, colors: [Color(0x14FFD27A), Color(0x33000000), Color(0xCC000000)], stops: [0, 0.55, 1]),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              final boardSide = portrait ? math.min(c.maxWidth - 8, c.maxHeight * 0.5) : c.maxHeight - 120;
              return ValueListenableBuilder<DartsState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final boardWidget = Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Lighting the lounge')),
                    ),
                  );
                  final bottom = _BottomHud(game: _game, state: state, players: players);
                  if (portrait) {
                    return Column(children: [hud, Expanded(child: boardWidget), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: boardWidget),
                    SizedBox(width: 340, child: Column(children: [hud, const Spacer(), bottom])),
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

/// Procedural oak wall used when the lounge background is not bundled.
class _OakWall extends StatelessWidget {
  const _OakWall();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _OakPainter());
}

class _OakPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3B2614), Color(0xFF231509), Color(0xFF120A04)]).createShader(Offset.zero & size));
    final plank = Paint()..color = Colors.black.withValues(alpha: 0.18)..strokeWidth = 2;
    final grain = Paint()..color = const Color(0xFF8A5A2B).withValues(alpha: 0.10)..strokeWidth = 1;
    final rnd = math.Random(7);
    for (var y = 0.0; y < size.height; y += 96) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
      for (var i = 0; i < 6; i++) {
        final gy = y + rnd.nextDouble() * 96;
        canvas.drawLine(Offset(0, gy), Offset(size.width, gy + rnd.nextDouble() * 6 - 3), grain);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final DartsGame game;
  final DartsState? state;
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
  final DartsGame game;
  final DartsState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat;
    final color = ZpColors.seat(state.turnSeat);
    final legs = state.rules.legsToWin > 1 ? ' · Leg ${state.leg}' : '';
    final text = state.finished ? 'Match over' : (mine ? 'Your visit' : '${state.current.displayName} throws') + legs;
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
          const SizedBox(width: ZpSpace.sm),
          Text(state.format.title, style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
        ]),
      ),
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  const _PlayerFrame({required this.seat, required this.state, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final DartsSeat seat;
  final DartsState state;
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
    final sub = switch (state.format) {
      DartsFormat.x501 || DartsFormat.x301 => '${seat.remaining}',
      DartsFormat.cricket => '${seat.points} pts',
      DartsFormat.aroundTheClock => seat.clockTarget >= kClockDone ? 'Done' : (seat.clockTarget == kClockBull ? 'Bull' : 'On ${seat.clockTarget}'),
    };
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TurnTimerRing(
          deadlineMs: active ? deadline : null,
          totalMs: totalMs,
          size: 58,
          color: color,
          child: ZpAvatar(player: p, size: 42, seatColor: color, highlight: active, showName: false),
        ),
        const SizedBox(height: 2),
        SizedBox(width: 78, child: Text(isMe ? 'You' : seat.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: active ? ZpColors.goldLight : ZpColors.textSecondary))),
        Text(sub, style: t.labelSmall?.copyWith(color: ZpColors.ivory)),
        if (state.rules.legsToWin > 1)
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < state.rules.legsToWin; i++)
              Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(shape: BoxShape.circle, color: i < seat.legsWon ? ZpColors.goldLight : color.withValues(alpha: 0.3))),
          ]),
        if (seat.finishedPlacement != null) Text(switch (seat.finishedPlacement!) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${seat.finishedPlacement}th' }, style: t.labelSmall?.copyWith(color: ZpColors.goldLight)),
      ]),
    );
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final DartsGame game;
  final DartsState? state;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.xs, ZpSpace.md, ZpSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerDisconnectedBanner(players: players),
        if (s != null)
          ValueListenableBuilder<ThrowPhase>(
            valueListenable: game.phase,
            builder: (context, phase, _) => ValueListenableBuilder<bool>(
              valueListenable: game.awaitingServer,
              builder: (context, waiting, _) => ZpPanel(
                padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.sm, ZpSpace.md, ZpSpace.sm),
                radius: ZpRadius.md,
                glow: !game.isSpectator && s.turnSeat == game.mySeat && !s.finished,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _Scoreboard(state: s, mySeat: game.mySeat),
                  const SizedBox(height: ZpSpace.sm),
                  _VisitRow(state: s, game: game, phase: phase, waiting: waiting),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Darts-left indicator, this visit's darts and the gesture hint / checkout.
class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.state, required this.game, required this.phase, required this.waiting});
  final DartsState state;
  final DartsGame game;
  final ThrowPhase phase;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
    final hint = game.isSpectator
        ? 'Watching'
        : s.finished
            ? 'Finished'
            : !myTurn
                ? 'Waiting for ${s.current.displayName}'
                : waiting
                    ? 'Throwing'
                    : switch (phase) {
                        ThrowPhase.idle => 'Press and drag to aim, lift to start the meter',
                        ThrowPhase.aiming => 'Hold steady, lift when the reticle is on target',
                        ThrowPhase.meter => 'Tap to release',
                        ThrowPhase.waiting => 'Throwing',
                      };
    final me = s.seatOrNull(s.turnSeat);
    final checkout = s.format.isX01 && me != null && me.remaining <= 170 ? checkoutFor(me.remaining, s.dartsLeft) : null;
    return Row(children: [
      _DartsLeft(left: s.finished ? 0 : s.dartsLeft, gold: game.cosmetics.dartSkin == 'gold'),
      const SizedBox(width: ZpSpace.md),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            for (final d in s.visit) ...[_DartChip(label: d.miss ? 'Miss' : d.label, bust: d.bust, highlight: d.multiplier > 1), const SizedBox(width: 4)],
            if (s.visit.isEmpty && s.lastVisit != null && !s.finished) Text('Last: ${s.lastVisit!.darts.map((d) => d.miss ? 'M' : d.label).join(' ')} (${s.lastVisit!.score})', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
          ]),
          const SizedBox(height: 2),
          Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: myTurn ? ZpColors.goldLight : ZpColors.textSecondary)),
          if (checkout != null)
            Row(children: [
              const Icon(Icons.flag_rounded, size: 13, color: ZpColors.champagne),
              const SizedBox(width: 4),
              Text('Checkout: ${checkout.join(' ')}', style: t.labelSmall?.copyWith(color: ZpColors.champagne)),
            ]).animate().fadeIn(duration: 300.ms),
        ]),
      ),
    ]);
  }
}

class _DartChip extends StatelessWidget {
  const _DartChip({required this.label, required this.bust, required this.highlight});
  final String label;
  final bool bust;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final color = bust ? ZpColors.danger : (highlight ? ZpColors.goldLight : ZpColors.ivory);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(ZpRadius.sm), border: Border.all(color: color.withValues(alpha: 0.6))),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Three brushed-metal darts; the ones already thrown are ghosted.
class _DartsLeft extends StatelessWidget {
  const _DartsLeft({required this.left, required this.gold});
  final int left;
  final bool gold;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < kDartsPerVisit; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Opacity(opacity: i < left ? 1 : 0.25, child: CustomPaint(size: const Size(14, 44), painter: _DartIconPainter(gold: gold))),
          ),
      ]);
}

class _DartIconPainter extends CustomPainter {
  _DartIconPainter({required this.gold});
  final bool gold;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final metal = gold ? const [Color(0xFFF6E3A1), Color(0xFFC9A227), Color(0xFF7A5A0E)] : const [Color(0xFFF2F4F7), Color(0xFF9EA4AD), Color(0xFF4B5058)];
    canvas.drawPath(Path()..moveTo(cx, 0)..lineTo(cx - 1.5, h * 0.22)..lineTo(cx + 1.5, h * 0.22)..close(), Paint()..color = metal[1]);
    final barrel = Rect.fromLTWH(cx - w * 0.22, h * 0.22, w * 0.44, h * 0.34);
    canvas.drawRRect(RRect.fromRectAndRadius(barrel, const Radius.circular(2)), Paint()..shader = LinearGradient(colors: metal).createShader(barrel));
    canvas.drawRect(Rect.fromLTWH(cx - 1, h * 0.56, 2, h * 0.2), Paint()..color = const Color(0xFF22242A));
    final flight = Paint()..color = ZpColors.gold;
    canvas.drawPath(Path()..moveTo(cx, h * 0.72)..lineTo(cx - w * 0.5, h)..lineTo(cx, h * 0.92)..lineTo(cx + w * 0.5, h)..close(), flight);
  }

  @override
  bool shouldRepaint(covariant _DartIconPainter old) => old.gold != gold;
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.state, required this.mySeat});
  final DartsState state;
  final int? mySeat;

  @override
  Widget build(BuildContext context) => switch (state.format) {
        DartsFormat.x501 || DartsFormat.x301 => _X01Board(state: state, mySeat: mySeat),
        DartsFormat.cricket => _CricketBoard(state: state, mySeat: mySeat),
        DartsFormat.aroundTheClock => _ClockBoard(state: state, mySeat: mySeat),
      };
}

class _X01Board extends StatelessWidget {
  const _X01Board({required this.state, required this.mySeat});
  final DartsState state;
  final int? mySeat;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        for (final seat in state.seats)
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(seat.seat == mySeat ? 'You' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: seat.seat == state.turnSeat ? ZpColors.goldLight : ZpColors.textSecondary)),
              AnimatedSwitcher(
                duration: ZpDurations.base,
                transitionBuilder: (child, anim) => ScaleTransition(scale: Tween(begin: 1.15, end: 1.0).animate(anim), child: FadeTransition(opacity: anim, child: child)),
                child: Text(
                  key: ValueKey(seat.remaining),
                  '${seat.remaining}',
                  style: t.headlineMedium?.copyWith(color: seat.seat == state.turnSeat ? ZpColors.ivory : ZpColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
              ),
              if (state.rules.doubleIn && !seat.inOpen) Text('needs a double', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
            ]),
          ),
      ],
    );
  }
}

class _ClockBoard extends StatelessWidget {
  const _ClockBoard({required this.state, required this.mySeat});
  final DartsState state;
  final int? mySeat;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      for (final seat in state.seats)
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(seat.seat == mySeat ? 'You' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: seat.seat == state.turnSeat ? ZpColors.goldLight : ZpColors.textSecondary)),
            Text(seat.clockTarget >= kClockDone ? 'Done' : (seat.clockTarget == kClockBull ? 'Bull' : '${seat.clockTarget}'), style: t.headlineMedium?.copyWith(color: ZpColors.ivory, fontWeight: FontWeight.w700)),
            SizedBox(
              width: 70,
              child: LinearProgressIndicator(value: (math.min(seat.clockTarget, 21) - 1) / 21, minHeight: 4, backgroundColor: ZpColors.divider, color: ZpColors.seat(seat.seat)),
            ),
          ]),
        ),
    ]);
  }
}

class _CricketBoard extends StatelessWidget {
  const _CricketBoard({required this.state, required this.mySeat});
  final DartsState state;
  final int? mySeat;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cols = state.seats;
    Widget cell(Widget child, {double width = 36}) => SizedBox(width: width, height: 20, child: Center(child: child));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        cell(const SizedBox.shrink()),
        for (final s in cols)
          Expanded(child: Center(child: Text(s.seat == mySeat ? 'You' : s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: s.seat == state.turnSeat ? ZpColors.goldLight : ZpColors.textSecondary)))),
      ]),
      for (final n in kCricketNumbers)
        Row(children: [
          cell(Text(n == 25 ? 'B' : '$n', style: t.labelMedium?.copyWith(color: ZpColors.champagne, fontWeight: FontWeight.w700))),
          for (final s in cols)
            Expanded(
              child: Center(
                child: CustomPaint(
                  size: const Size(18, 18),
                  painter: _MarkPainter(marks: s.marksOn(n), color: s.closed(n) ? ZpColors.goldLight : ZpColors.ivory, dim: cols.every((o) => o.closed(n))),
                ),
              ),
            ),
        ]),
      Row(children: [
        cell(Text('pts', style: t.labelSmall?.copyWith(color: ZpColors.textMuted))),
        for (final s in cols) Expanded(child: Center(child: Text('${s.points}', style: t.titleMedium?.copyWith(color: ZpColors.ivory, fontWeight: FontWeight.w700)))),
      ]),
    ]);
  }
}

/// Cricket mark glyph: slash, cross, circled cross.
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.marks, required this.color, required this.dim});
  final int marks;
  final Color color;
  final bool dim;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: dim ? 0.35 : 1)..strokeWidth = 2..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final r = size.width / 2;
    final c = Offset(r, r);
    if (marks <= 0) {
      canvas.drawCircle(c, 1.5, Paint()..color = color.withValues(alpha: 0.2));
      return;
    }
    canvas.drawLine(Offset(r * 0.4, r * 1.6), Offset(r * 1.6, r * 0.4), p);
    if (marks >= 2) canvas.drawLine(Offset(r * 0.4, r * 0.4), Offset(r * 1.6, r * 1.6), p);
    if (marks >= 3) canvas.drawCircle(c, r - 1, p);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.marks != marks || old.color != color || old.dim != dim;
}
