import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'components/ball_component.dart';
import 'model/pool_state.dart';
import 'pool_assets.dart';
import 'pool_game.dart';

/// Full-screen pool scene: lounge background, the Flame table (rotated 90
/// degrees in portrait so the long axis runs down the phone), Flutter HUD with
/// player frames, group chips, timer ring, turn banner, power slider, spin
/// control, toasts and the victory card.
class PoolScreen extends StatefulWidget {
  const PoolScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final PoolCosmetics cosmetics;

  @override
  State<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends State<PoolScreen> with WidgetsBindingObserver {
  late final PoolGame _game = PoolGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  PoolNotice? _toast;
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
    _toastTimer = Timer(const Duration(milliseconds: 2100), () {
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
        Image(image: ZpAssets.image(PoolAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const _LoungeFallback()),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x33000000), Color(0xBB000000)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              return ValueListenableBuilder<PoolState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final hud = _TopHud(game: _game, state: state, players: players, onPause: shell?.onPause);
                  final controls = _ShotControls(game: _game, state: state, vertical: true);
                  if (portrait) {
                    // Table ratio (with rails) is 2.18 : 1.18. Rotate so the long axis is vertical.
                    const ratio = (200 + 2 * PoolGame.railUnits) / (100 + 2 * PoolGame.railUnits);
                    return Column(children: [
                      hud,
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm),
                          child: Row(children: [
                            Expanded(
                              child: LayoutBuilder(builder: (context, tc) {
                                var w = tc.maxWidth;
                                var h = w * ratio;
                                if (h > tc.maxHeight) {
                                  h = tc.maxHeight;
                                  w = h / ratio;
                                }
                                return Center(
                                  child: SizedBox(
                                    width: w,
                                    height: h,
                                    child: RotatedBox(quarterTurns: 1, child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Racking the balls'))),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(width: ZpSpace.sm),
                            SizedBox(width: 72, child: controls),
                          ]),
                        ),
                      ),
                      _BottomHud(game: _game, state: state, players: players),
                    ]);
                  }
                  return Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(ZpSpace.sm),
                        child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Racking the balls')),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: Column(children: [
                        hud,
                        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md), child: _ShotControls(game: _game, state: state, vertical: false))),
                        _BottomHud(game: _game, state: state, players: players),
                      ]),
                    ),
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
        ValueListenableBuilder<PoolFinish?>(
          valueListenable: _game.finish,
          builder: (context, f, _) => f == null ? const SizedBox.shrink() : _VictoryCard(game: _game, finish: f, players: players),
        ),
      ],
    );
  }
}

/// Deep lounge gradient with a warm spotlight when the background is missing.
class _LoungeFallback extends StatelessWidget {
  const _LoungeFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.4), radius: 1.1, colors: [Color(0xFF3A2614), Color(0xFF17100B), Color(0xFF07060A)], stops: [0, 0.45, 1]),
        ),
      );
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.players, required this.onPause});
  final PoolGame game;
  final PoolState? state;
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
                  state: s,
                  seat: seat,
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
  final PoolGame game;
  final PoolState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.turnSeat == game.mySeat;
    final text = state.finished
        ? 'Match over'
        : state.isBreak
            ? (mine ? 'Your break' : '${state.current.displayName} breaks')
            : mine
                ? (state.ballInHand ? 'Ball in hand' : (state.openTable ? 'Your shot, open table' : 'Your shot'))
                : '${state.current.displayName} is shooting';
    return AnimatedSwitcher(
      duration: ZpDurations.base,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: 8),
        decoration: BoxDecoration(
          color: ZpColors.obsidian.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          border: Border.all(color: (mine ? ZpColors.goldLight : ZpColors.champagne).withValues(alpha: 0.8)),
          boxShadow: mine ? [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.35), blurRadius: 16)] : null,
        ),
        child: Text(text, style: t.titleSmall?.copyWith(color: mine ? ZpColors.goldLight : ZpColors.ivory)),
      ),
    );
  }
}

class _PlayerFrame extends StatelessWidget {
  const _PlayerFrame({required this.state, required this.seat, required this.player, required this.active, required this.isMe, required this.deadline, required this.totalMs});
  final PoolState state;
  final PoolSeat seat;
  final RoomPlayer? player;
  final bool active;
  final bool isMe;
  final int? deadline;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = seat.seat == 0 ? ZpColors.gold : ZpColors.champagne;
    final p = player ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: false, connected: seat.connected);
    final dim = seat.forfeited || !p.connected;
    final group = seat.group;
    final remaining = group == null ? const <PoolBall>[] : state.balls.where((b) => !b.pocketed && b.group == group).toList();
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
        SizedBox(width: 92, child: Text(isMe ? 'You' : seat.displayName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: active ? ZpColors.goldLight : ZpColors.textSecondary))),
        if (group == null)
          Text(state.finished ? '' : 'open', style: t.labelSmall?.copyWith(color: ZpColors.textMuted))
        else
          _GroupChips(group: group, remaining: remaining.map((b) => b.id).toList()),
        if (state.winnerSeat == seat.seat) Text('Winner', style: t.labelSmall?.copyWith(color: ZpColors.goldLight)),
      ]),
    );
  }
}

/// Seven tiny ball chips for a group; pocketed ones fade out.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.group, required this.remaining});
  final String group;
  final List<int> remaining;

  @override
  Widget build(BuildContext context) {
    final ids = group == 'solids' ? [1, 2, 3, 4, 5, 6, 7] : [9, 10, 11, 12, 13, 14, 15];
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final id in ids)
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: remaining.contains(id) ? ballColor(id) : Colors.white.withValues(alpha: 0.12),
            border: group == 'stripes' && remaining.contains(id) ? Border.all(color: ZpColors.ivory, width: 1.5) : null,
          ),
        ),
    ]);
  }
}

class _BottomHud extends StatelessWidget {
  const _BottomHud({required this.game, required this.state, required this.players});
  final PoolGame game;
  final PoolState? state;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.sm, ZpSpace.lg, ZpSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerDisconnectedBanner(players: players),
        if (s != null)
          ValueListenableBuilder<bool>(
            valueListenable: game.awaitingServer,
            builder: (context, waiting, _) => ValueListenableBuilder<bool>(
              valueListenable: game.replaying,
              builder: (context, replaying, _) {
                final myTurn = !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
                final label = game.isSpectator
                    ? 'Watching'
                    : s.finished
                        ? 'Finished'
                        : replaying
                            ? 'Balls rolling'
                            : waiting
                                ? 'Sending'
                                : !myTurn
                                    ? 'Waiting for ${s.current.displayName}'
                                    : s.ballInHand
                                        ? 'Drag the cue ball, then aim'
                                        : 'Drag to aim, pull the power bar to shoot';
                return Row(children: [
                  Expanded(child: Text(label, style: t.titleSmall?.copyWith(color: myTurn && !waiting && !replaying ? ZpColors.goldLight : ZpColors.textSecondary))),
                  if (s.lastShot != null && s.lastShot!.fouls.isNotEmpty && !s.finished)
                    Text('Foul', style: t.labelMedium?.copyWith(color: ZpColors.danger)).animate().fadeIn(),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}

/// Power slider (drag down to load, release to shoot) and the spin widget.
class _ShotControls extends StatelessWidget {
  const _ShotControls({required this.game, required this.state, required this.vertical});
  final PoolGame game;
  final PoolState? state;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final s = state;
    final enabled = s != null && !game.isSpectator && s.turnSeat == game.mySeat && !s.finished;
    final slider = ValueListenableBuilder<bool>(
      valueListenable: game.awaitingServer,
      builder: (context, waiting, _) => ValueListenableBuilder<bool>(
        valueListenable: game.replaying,
        builder: (context, replaying, _) => PowerSlider(game: game, enabled: enabled && !waiting && !replaying),
      ),
    );
    final spinWidget = SpinControl(game: game, enabled: enabled);
    if (vertical) {
      return Column(children: [
        Expanded(child: slider),
        const SizedBox(height: ZpSpace.md),
        spinWidget,
      ]);
    }
    return Row(children: [
      Expanded(child: slider),
      const SizedBox(width: ZpSpace.lg),
      spinWidget,
    ]);
  }
}

/// Vertical power bar. Drag downwards to load, release to shoot. Public so the
/// widget tests can drive it.
class PowerSlider extends StatefulWidget {
  const PowerSlider({super.key, required this.game, required this.enabled});
  final PoolGame game;
  final bool enabled;

  @override
  State<PowerSlider> createState() => _PowerSliderState();
}

class _PowerSliderState extends State<PowerSlider> {
  double _drag = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final h = c.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: widget.enabled
            ? (_) {
                _dragging = true;
                _drag = 0;
                widget.game.setPower(0);
                setState(() {});
              }
            : null,
        onVerticalDragUpdate: widget.enabled
            ? (d) {
                _drag = (_drag + d.delta.dy / (h * 0.85)).clamp(0.0, 1.0);
                widget.game.setPower(_drag);
                setState(() {});
              }
            : null,
        onVerticalDragEnd: widget.enabled
            ? (_) {
                _dragging = false;
                if (_drag >= 0.05) {
                  widget.game.shoot();
                } else {
                  widget.game.setPower(0.5);
                }
                setState(() {});
              }
            : null,
        onVerticalDragCancel: () {
          _dragging = false;
          widget.game.setPower(0.5);
          setState(() {});
        },
        child: ValueListenableBuilder<double>(
          valueListenable: widget.game.power,
          builder: (context, p, _) => CustomPaint(
            painter: _PowerPainter(power: _dragging ? _drag : p, enabled: widget.enabled, loading: _dragging),
            child: const SizedBox.expand(),
          ),
        ),
      );
    });
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter({required this.power, required this.enabled, required this.loading});
  final double power;
  final bool enabled;
  final bool loading;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.3, 8, size.width * 0.4, size.height - 16), const Radius.circular(12));
    canvas.drawRRect(track, Paint()..color = ZpColors.obsidian.withValues(alpha: 0.7));
    canvas.drawRRect(track, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = (enabled ? ZpColors.gold : ZpColors.divider).withValues(alpha: 0.7));
    final fillH = (size.height - 20) * power;
    final fill = Rect.fromLTWH(track.left + 2, track.top + 2, track.width - 4, fillH);
    canvas.save();
    canvas.clipRRect(track.deflate(2));
    canvas.drawRect(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [ZpColors.champagne, ZpColors.gold, power > 0.8 ? ZpColors.ruby : ZpColors.goldDeep]).createShader(fill),
    );
    canvas.restore();
    // Tick marks.
    for (var i = 1; i < 10; i++) {
      final y = track.top + (track.height) * i / 10;
      canvas.drawLine(Offset(track.left - 4, y), Offset(track.left, y), Paint()..color = Colors.white.withValues(alpha: 0.25));
    }
    // Handle.
    final hy = track.top + 2 + fillH;
    canvas.drawCircle(Offset(size.width / 2, hy), size.width * 0.34, Paint()..color = Colors.black.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(size.width / 2, hy), size.width * 0.3, Paint()..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [ZpColors.champagne, enabled ? ZpColors.gold : ZpColors.panelRaised]).createShader(Rect.fromCircle(center: Offset(size.width / 2, hy), radius: size.width * 0.3)));
    if (loading) {
      final tp = TextPainter(text: TextSpan(text: '${(power * 100).round()}', style: const TextStyle(color: ZpColors.ivory, fontSize: 12, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, hy + size.width * 0.36));
    }
  }

  @override
  bool shouldRepaint(covariant _PowerPainter old) => old.power != power || old.enabled != enabled || old.loading != loading;
}

/// Small cue ball with a draggable contact dot. Public so tests can drive it.
class SpinControl extends StatelessWidget {
  const SpinControl({super.key, required this.game, required this.enabled, this.size = 64});
  final PoolGame game;
  final bool enabled;
  final double size;

  void _set(Offset local) {
    final c = size / 2;
    var dx = (local.dx - c) / (c * 0.78);
    var dy = -(local.dy - c) / (c * 0.78);
    final len = math.sqrt(dx * dx + dy * dy);
    if (len > 1) {
      dx /= len;
      dy /= len;
    }
    game.setSpin(Offset(dx, dy));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: enabled ? (d) => _set(d.localPosition) : null,
      onPanUpdate: enabled ? (d) => _set(d.localPosition) : null,
      onDoubleTap: enabled ? () => game.setSpin(Offset.zero) : null,
      child: ValueListenableBuilder<Offset>(
        valueListenable: game.spin,
        builder: (context, s, _) => CustomPaint(painter: _SpinPainter(spin: s, enabled: enabled), size: Size.square(size)),
      ),
    );
  }
}

class _SpinPainter extends CustomPainter {
  _SpinPainter({required this.spin, required this.enabled});
  final Offset spin;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c.translate(2, 3), r, Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(center: Alignment(-0.35, -0.4), colors: [Color(0xFFFFFDF7), Color(0xFFD9D2C2), Color(0xFF9A9284)], stops: [0, 0.7, 1]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = (enabled ? ZpColors.gold : ZpColors.divider).withValues(alpha: 0.8));
    // Cross hairs.
    final hair = Paint()..color = Colors.black.withValues(alpha: 0.12);
    canvas.drawLine(Offset(c.dx, c.dy - r * 0.78), Offset(c.dx, c.dy + r * 0.78), hair);
    canvas.drawLine(Offset(c.dx - r * 0.78, c.dy), Offset(c.dx + r * 0.78, c.dy), hair);
    final dot = c + Offset(spin.dx * r * 0.78, -spin.dy * r * 0.78);
    canvas.drawCircle(dot, r * 0.17, Paint()..color = ZpColors.ruby);
    canvas.drawCircle(dot, r * 0.17, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant _SpinPainter old) => old.spin != spin || old.enabled != enabled;
}

class _VictoryCard extends StatelessWidget {
  const _VictoryCard({required this.game, required this.finish, required this.players});
  final PoolGame game;
  final PoolFinish finish;
  final List<RoomPlayer> players;

  static String _reason(String r) => switch (r) {
        'eight_ball' => 'Pocketed the 8 ball',
        'eight_on_break' => '8 ball on the break',
        'early_eight' => 'Opponent sank the 8 early',
        'scratch_on_eight' => 'Opponent scratched on the 8',
        'foul_on_eight' => 'Opponent fouled on the 8',
        'forfeit' => 'Opponent forfeited',
        _ => r,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = game.displayState.value;
    final winner = s?.seatOrNull(finish.winnerSeat);
    final mine = finish.winnerSeat == game.mySeat;
    final name = winner?.displayName ?? players.where((p) => p.seat == finish.winnerSeat).firstOrNull?.displayName ?? 'Player';
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 96,
      child: Center(
        child: ZpPanel(
          glow: true,
          borderColor: ZpColors.gold,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, color: ZpColors.goldLight, size: 40).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 900.ms),
            const SizedBox(height: ZpSpace.sm),
            Text(mine ? 'You win' : '$name wins', style: t.headlineSmall?.copyWith(color: ZpColors.goldLight)),
            const SizedBox(height: 4),
            Text(_reason(finish.reason), style: t.bodyMedium?.copyWith(color: ZpColors.textSecondary)),
          ]),
        ).animate().fadeIn(duration: ZpDurations.slow).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
      ),
    );
  }
}
