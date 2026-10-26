import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'color_clash_assets.dart';
import 'color_clash_game.dart';
import 'components/card_painter.dart';
import 'components/layout.dart';
import 'model/card.dart';
import 'model/color_clash_view.dart';

/// Full-screen Color Clash scene: arena background, Flame table in a 2:3 viewport,
/// Flutter HUD (avatars with timer rings around the table, action bar, colour
/// picker, toasts, results panel).
class ColorClashScreen extends StatefulWidget {
  const ColorClashScreen({super.key, required this.session, required this.channel});
  final GameSessionContext session;
  final GameChannel channel;

  @override
  State<ColorClashScreen> createState() => _ColorClashScreenState();
}

class _ColorClashScreenState extends State<ColorClashScreen> with WidgetsBindingObserver {
  late final ColorClashGame _game = ColorClashGame(session: widget.session, channel: widget.channel);
  CcNotice? _toast;
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
        Image(image: ZpAssets.image(ColorClashAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const _ArenaBackdrop()),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x22000000), Color(0xBB05030A)]))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              return ValueListenableBuilder<CcView?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final top = _TopHud(game: _game, state: state, onPause: shell?.onPause);
                  final bottom = _ActionBar(game: _game, state: state, players: players);
                  final table = _TableArea(game: _game, state: state, players: players);
                  if (portrait) {
                    return Column(children: [top, Expanded(child: table), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: table),
                    SizedBox(width: 320, child: Column(children: [top, const Spacer(), bottom])),
                  ]);
                },
              );
            },
          ),
        ),
        ValueListenableBuilder<CcCard?>(
          valueListenable: _game.pendingWild,
          builder: (context, card, _) => card == null ? const SizedBox.shrink() : _ColorPicker(card: card, onPick: _game.chooseColor, onCancel: _game.cancelWild),
        ),
        ValueListenableBuilder<CcView?>(
          valueListenable: _game.displayState,
          builder: (context, state, _) => state != null && state.finished ? _ResultsPanel(state: state, mySeat: _game.mySeat) : const SizedBox.shrink(),
        ),
        if (_toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 72,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? ZpColors.gold)),
          ),
      ],
    );
  }
}

/// Procedural stand-in for the arena background image.
class _ArenaBackdrop extends StatelessWidget {
  const _ArenaBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.2, colors: [Color(0xFF2B1A4F), Color(0xFF120B22), Color(0xFF05030A)], stops: [0, 0.55, 1]),
        ),
      );
}

/// The Flame viewport plus the avatar overlay, kept in one 2:3 box so world anchors
/// and widget positions line up.
class _TableArea extends StatelessWidget {
  const _TableArea({required this.game, required this.state, required this.players});
  final ColorClashGame game;
  final CcView? state;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const ratio = ArenaLayout.worldW / ArenaLayout.worldH;
      var w = c.maxWidth;
      var h = w / ratio;
      if (h > c.maxHeight) {
        h = c.maxHeight;
        w = h * ratio;
      }
      final s = state;
      final opp = s == null ? const <int>[] : game.opponentSeats(s);
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: GameWidget(game: game, loadingBuilder: (_) => const ZpLoading(label: 'Shuffling the deck'))),
              if (s != null)
                for (var i = 0; i < opp.length; i++) _positionedAvatar(context, s, opp[i], ArenaLayout.normalised(ArenaLayout.opponentAvatar(i, opp.length)), w, h),
            ],
          ),
        ),
      );
    });
  }

  Widget _positionedAvatar(BuildContext context, CcView s, int seat, Vector2 n, double w, double h) {
    const size = 66.0;
    final cs = s.seatAt(seat);
    final p = players.where((p) => p.userId == cs.userId).firstOrNull ?? RoomPlayer(userId: cs.userId, displayName: cs.displayName, seat: seat, ready: false, connected: cs.connected);
    final active = s.turnSeat == seat && !s.finished;
    return Positioned(
      left: n.x * w - size / 2,
      top: n.y * h - size / 2 - 8,
      child: IgnorePointer(
        child: _SeatBadge(
          player: p,
          seat: cs,
          active: active,
          deadline: active ? (game.latestState.value?.turnDeadline ?? s.turnDeadline) : null,
          totalMs: s.rules.turnTimeoutSeconds * 1000,
          size: size,
          showScore: s.rules.maxRounds > 1 || s.round > 1,
        ),
      ),
    );
  }
}

class _SeatBadge extends StatelessWidget {
  const _SeatBadge({required this.player, required this.seat, required this.active, required this.deadline, required this.totalMs, required this.size, required this.showScore});
  final RoomPlayer player;
  final CcSeat seat;
  final bool active;
  final int? deadline;
  final int totalMs;
  final double size;
  final bool showScore;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final color = ZpColors.seat(seat.seat);
    final dim = seat.forfeited || !player.connected;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TurnTimerRing(
          deadlineMs: active ? deadline : null,
          totalMs: totalMs,
          size: size,
          color: color,
          child: ZpAvatar(player: player, size: size * 0.74, seatColor: color, highlight: active, showName: false),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(ZpRadius.pill)),
          child: Text(showScore ? '${seat.displayName}  ${seat.score}' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelSmall?.copyWith(color: active ? ZpColors.goldLight : ZpColors.textSecondary)),
        ),
      ]),
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({required this.game, required this.state, required this.onPause});
  final ColorClashGame game;
  final CcView? state;
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
          if (s != null)
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ZpColors.obsidian.withValues(alpha: 0.6), border: Border.all(color: s.currentColor.color, width: 2), boxShadow: [BoxShadow(color: s.currentColor.color.withValues(alpha: 0.5), blurRadius: 14)]),
              child: Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: s.currentColor.color)),
            )
          else
            const SizedBox(width: 44),
        ]),
        if (s != null && (s.rules.maxRounds > 1 || s.round > 1))
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Round ${s.round} of ${s.rules.maxRounds}  ·  first to ${s.rules.targetScore}', style: t.labelSmall?.copyWith(letterSpacing: 1))),
        if (game.isSpectator) Padding(padding: const EdgeInsets.only(top: 4), child: Text('SPECTATING', style: t.labelSmall?.copyWith(letterSpacing: 2))),
      ]),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.game, required this.state});
  final ColorClashGame game;
  final CcView state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final mine = state.isMyTurn && !game.isSpectator;
    final color = state.currentColor.color;
    final String text;
    if (state.finished) {
      text = 'Match over';
    } else if (state.pendingDraw > 0) {
      text = mine ? 'Surge +${state.pendingDraw}: stack or draw' : '${state.current.displayName} faces +${state.pendingDraw}';
    } else if (state.echoNumber != null) {
      text = mine ? 'Echo: play a ${state.echoNumber}' : 'Echo ${state.echoNumber} on ${state.current.displayName}';
    } else if (mine) {
      text = state.phase == CcPhase.drawn ? 'Play the drawn card or pass' : (state.playable.isEmpty ? 'No match, draw a card' : 'Your turn');
    } else {
      text = '${state.current.displayName} is playing';
    }
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
        child: Text(text, style: t.titleSmall?.copyWith(color: mine ? ZpColors.goldLight : ZpColors.ivory), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// Bottom bar: my avatar with timer, status line, and the action buttons the
/// server currently allows (Draw / Pass / Play / Declare / Catch).
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.game, required this.state, required this.players});
  final ColorClashGame game;
  final CcView? state;
  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.xs, ZpSpace.md, ZpSpace.md),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PlayerDisconnectedBanner(players: players),
        if (s != null)
          ValueListenableBuilder<bool>(
            valueListenable: game.awaitingServer,
            builder: (context, waiting, _) => ValueListenableBuilder<bool>(
              valueListenable: game.busy,
              builder: (context, busy, _) => ValueListenableBuilder<String?>(
                valueListenable: game.selectedCardId,
                builder: (context, selected, _) {
                  final me = game.mySeat == null ? null : s.seatOrNull(game.mySeat);
                  final myTurn = !game.isSpectator && s.isMyTurn;
                  final idle = !waiting && !busy;
                  final canDraw = myTurn && s.canDraw && idle;
                  final canPass = myTurn && s.canPass && idle;
                  final selectedCard = selected == null ? null : s.myHand?.where((c) => c.id == selected).firstOrNull;
                  final canPlay = myTurn && idle && selectedCard != null && s.isPlayable(selectedCard.id);
                  final canDeclare = !game.isSpectator && s.canDeclare && !waiting;
                  final catchTargets = game.isSpectator ? const <int>[] : s.catchTargets;
                  final mePlayer = me == null ? null : (players.where((p) => p.userId == me.userId).firstOrNull ?? RoomPlayer(userId: me.userId, displayName: me.displayName, seat: me.seat, ready: false, connected: true));
                  return Row(children: [
                    if (me != null && mePlayer != null)
                      TurnTimerRing(
                        deadlineMs: myTurn ? (game.latestState.value?.turnDeadline ?? s.turnDeadline) : null,
                        totalMs: s.rules.turnTimeoutSeconds * 1000,
                        size: 58,
                        color: ZpColors.seat(me.seat),
                        child: ZpAvatar(player: mePlayer, size: 42, seatColor: ZpColors.seat(me.seat), highlight: myTurn || me.declared, showName: false),
                      ),
                    const SizedBox(width: ZpSpace.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          game.isSpectator
                              ? 'Watching'
                              : s.finished
                                  ? 'Finished'
                                  : !myTurn
                                      ? 'Waiting for ${s.current.displayName}'
                                      : selectedCard != null
                                          ? 'Tap again or Play'
                                          : s.phase == CcPhase.drawn
                                              ? 'Play it or pass'
                                              : 'Pick a glowing card',
                          style: t.titleSmall?.copyWith(color: myTurn ? ZpColors.goldLight : ZpColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (me != null) Text('${me.handCount} card${me.handCount == 1 ? '' : 's'}${s.rules.maxRounds > 1 || s.round > 1 ? '  ·  ${me.score} pts' : ''}', style: t.labelSmall),
                      ]),
                    ),
                    Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.end, children: [
                      for (final target in catchTargets)
                        ZpButton(label: 'Catch ${s.seatAt(target).displayName}', icon: Icons.front_hand_rounded, kind: ZpButtonKind.danger, compact: true, onPressed: () => game.requestCatch(target))
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 500.ms),
                      if (canDeclare)
                        ZpButton(label: 'DECLARE', icon: Icons.campaign_rounded, compact: true, onPressed: game.requestDeclare)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 420.ms)
                            .shimmer(duration: 900.ms, color: Colors.white.withValues(alpha: 0.5)),
                      if (canPass) ZpButton(label: 'Pass', icon: Icons.redo_rounded, kind: ZpButtonKind.secondary, compact: true, onPressed: game.requestPass),
                      if (myTurn && s.phase == CcPhase.play)
                        ZpButton(label: 'Draw', icon: Icons.style_rounded, kind: canPlay ? ZpButtonKind.secondary : ZpButtonKind.primary, compact: true, onPressed: canDraw ? game.requestDraw : null, loading: waiting && selected == null),
                      if (canPlay || (myTurn && selectedCard != null))
                        ZpButton(label: 'Play', icon: Icons.play_arrow_rounded, compact: true, onPressed: canPlay ? () => game.requestPlay(selectedCard) : null, loading: waiting && selected != null)
                            .animate(target: canPlay ? 1 : 0)
                            .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.35)),
                    ]),
                  ]);
                },
              ),
            ),
          ),
      ]),
    );
  }
}

/// Colour picker for Prism and Prism Surge.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.card, required this.onPick, required this.onCancel});
  final CcCard card;
  final void Function(CcColor) onPick;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ZpOverlay(
      dismissible: true,
      onDismiss: onCancel,
      child: ZpPanel(
        glow: true,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 84, height: 84 / CardPainter.aspect, child: CustomPaint(painter: _CardPreviewPainter(card))),
          const SizedBox(height: ZpSpace.md),
          Text(card.kind.label, style: t.headlineSmall),
          const SizedBox(height: ZpSpace.xs),
          Text('Choose the next colour', style: t.bodyMedium),
          const SizedBox(height: ZpSpace.lg),
          Wrap(
            spacing: ZpSpace.md,
            runSpacing: ZpSpace.md,
            children: [
              for (final c in CcColor.playable)
                Semantics(
                  button: true,
                  label: c.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(ZpRadius.lg),
                    onTap: () => onPick(c),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ZpRadius.lg),
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.lerp(c.color, Colors.white, 0.25)!, c.color, c.deep]),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                        boxShadow: [BoxShadow(color: c.color.withValues(alpha: 0.6), blurRadius: 18)],
                      ),
                      alignment: Alignment.center,
                      child: Text(c.label, style: t.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ).animate().scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 260.ms),
            ],
          ),
          const SizedBox(height: ZpSpace.lg),
          ZpButton(label: 'Cancel', kind: ZpButtonKind.ghost, onPressed: onCancel),
        ]),
      ),
    );
  }
}

class _CardPreviewPainter extends CustomPainter {
  _CardPreviewPainter(this.card);
  final CcCard card;
  @override
  void paint(Canvas canvas, Size size) => CardPainter.paint(canvas, Offset.zero & size, card: card, faceUp: true, sheen: 0.4);
  @override
  bool shouldRepaint(covariant _CardPreviewPainter old) => old.card != card;
}

/// Placement panel shown over the table when the match is finished.
class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({required this.state, required this.mySeat});
  final CcView state;
  final int? mySeat;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final winner = state.placements.isEmpty ? null : state.seatOrNull(state.placements.first);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 120,
      child: Center(
        child: ZpPanel(
          glow: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.emoji_events_rounded, color: ZpColors.goldLight, size: 36),
            const SizedBox(height: ZpSpace.xs),
            Text(winner == null ? 'Match over' : (winner.seat == mySeat ? 'You win!' : '${winner.displayName} wins'), style: t.headlineSmall?.copyWith(color: ZpColors.goldLight)),
            if (state.lastRound != null) Text('+${state.lastRound!.points} points this round', style: t.bodySmall),
            const SizedBox(height: ZpSpace.md),
            for (var i = 0; i < state.placements.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 36, child: Text(switch (i + 1) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${i + 1}th' }, style: t.labelMedium?.copyWith(color: i == 0 ? ZpColors.goldLight : ZpColors.textSecondary))),
                  SizedBox(width: 140, child: Text(state.seatAt(state.placements[i]).displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium)),
                  Text('${state.seatAt(state.placements[i]).score} pts', style: t.labelMedium),
                ]),
              ),
          ]),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), curve: Curves.easeOutBack),
      ),
    );
  }
}
