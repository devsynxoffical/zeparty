import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import 'chess_assets.dart';
import 'chess_game.dart';
import 'components/piece_painter.dart';
import 'model/chess_state.dart';

/// Full-screen Chess Legends scene: hall background, Flame board in a square
/// viewport, Flutter HUD (clocks, captured material, move list, controls).
class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key, required this.session, required this.channel, required this.cosmetics});
  final GameSessionContext session;
  final GameChannel channel;
  final ChessCosmetics cosmetics;

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> with WidgetsBindingObserver {
  late final ChessGame _game = ChessGame(session: widget.session, channel: widget.channel, cosmetics: widget.cosmetics);
  ChessNotice? _toast;
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

  Future<void> _confirm(String title, String body, String action, Future<void> Function() run, {bool danger = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ZpPanel(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: t.titleLarge?.copyWith(color: ZpColors.goldLight)),
              const SizedBox(height: ZpSpace.sm),
              Text(body, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: ZpSpace.xl),
              Row(children: [
                Expanded(child: ZpButton(label: 'Cancel', kind: ZpButtonKind.ghost, onPressed: () => Navigator.of(ctx).pop(false))),
                const SizedBox(width: ZpSpace.md),
                Expanded(child: ZpButton(label: action, kind: danger ? ZpButtonKind.danger : ZpButtonKind.primary, onPressed: () => Navigator.of(ctx).pop(true))),
              ]),
            ]),
          ),
        );
      },
    );
    if (ok == true) await run();
  }

  @override
  Widget build(BuildContext context) {
    final shell = GameShellScope.maybeOf(context);
    final players = shell?.players ?? _players;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: ZpAssets.image(ChessAssets.background), fit: BoxFit.cover, errorBuilder: (_, _, _) => const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1C1326), Color(0xFF0B0A0F)])))),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xAA000000), Color(0x33000000), Color(0xBB000000)]))),
        const _HallGlow(),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final portrait = c.maxHeight >= c.maxWidth;
              final boardSide = portrait ? math.min(c.maxWidth - 12, c.maxHeight - 300) : c.maxHeight - 60;
              return ValueListenableBuilder<ChessState?>(
                valueListenable: _game.displayState,
                builder: (context, state, _) {
                  final flipped = _game.flipped;
                  final bottomColor = flipped ? 'b' : 'w';
                  final topColor = flipped ? 'w' : 'b';
                  final boardWidget = Center(
                    child: SizedBox(
                      width: boardSide,
                      height: boardSide,
                      child: GameWidget(game: _game, loadingBuilder: (_) => const ZpLoading(label: 'Entering the hall')),
                    ),
                  );
                  final top = Column(mainAxisSize: MainAxisSize.min, children: [
                    _TopBar(game: _game, state: state, onPause: shell?.onPause),
                    if (state != null) _PlayerPanel(game: _game, state: state, color: topColor, players: players, top: true),
                  ]);
                  final bottom = state == null
                      ? const SizedBox.shrink()
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          _PlayerPanel(game: _game, state: state, color: bottomColor, players: players, top: false),
                          _MoveList(state: state),
                          _Controls(game: _game, state: state, confirm: _confirm),
                          PlayerDisconnectedBanner(players: players),
                        ]);
                  if (portrait) {
                    return Column(children: [top, Expanded(child: boardWidget), bottom]);
                  }
                  return Row(children: [
                    Expanded(child: boardWidget),
                    SizedBox(width: 320, child: SingleChildScrollView(child: Column(children: [top, const SizedBox(height: ZpSpace.lg), bottom]))),
                  ]);
                },
              );
            },
          ),
        ),
        ValueListenableBuilder<PendingPromotion?>(
          valueListenable: _game.pendingPromotion,
          builder: (context, pending, _) => pending == null ? const SizedBox.shrink() : _PromotionPicker(game: _game),
        ),
        ValueListenableBuilder<ChessState?>(
          valueListenable: _game.displayState,
          builder: (context, state, _) {
            if (state == null || !state.finished || state.result == null) return const SizedBox.shrink();
            return _FinishedOverlay(game: _game, state: state);
          },
        ),
        if (_toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 60,
            child: Center(child: GameToast(key: ValueKey(_toast), text: _toast!.text, icon: _toast!.icon, color: _toast!.color ?? ZpColors.gold)),
          ),
      ],
    );
  }
}

/// Soft gold light pooling from above the board, part of the "magical lighting".
class _HallGlow extends StatelessWidget {
  const _HallGlow();
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.9, colors: [ZpColors.gold.withValues(alpha: 0.14), Colors.transparent])),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.game, required this.state, required this.onPause});
  final ChessGame game;
  final ChessState? state;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = state;
    String text;
    var mine = false;
    if (s == null) {
      text = 'Setting the board';
    } else if (s.finished) {
      text = 'Game over';
    } else if (game.isSpectator) {
      text = '${s.current.displayName} to move';
    } else if (s.turnSeat == game.mySeat) {
      mine = true;
      text = s.check ? 'You are in check' : 'Your move';
    } else {
      text = '${s.current.displayName} is thinking';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.sm, ZpSpace.md, 0),
      child: Row(children: [
        ZpIconButton(icon: Icons.pause_rounded, onPressed: onPause, tooltip: 'Pause'),
        const Spacer(),
        AnimatedSwitcher(
          duration: ZpDurations.base,
          child: Container(
            key: ValueKey(text),
            padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: 8),
            decoration: BoxDecoration(
              color: ZpColors.obsidian.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(ZpRadius.pill),
              border: Border.all(color: (mine ? ZpColors.goldLight : ZpColors.gold).withValues(alpha: 0.7)),
              boxShadow: mine ? [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.35), blurRadius: 16)] : null,
            ),
            child: Text(text, style: t.titleSmall?.copyWith(color: mine ? ZpColors.goldLight : ZpColors.ivory)),
          ),
        ),
        const Spacer(),
        if (game.isSpectator) Text('SPECTATING', style: t.labelSmall?.copyWith(letterSpacing: 2, color: ZpColors.textSecondary)) else const SizedBox(width: 44),
      ]),
    );
  }
}

/// One side's frame: avatar, name, captured material and a large clock.
class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.game, required this.state, required this.color, required this.players, required this.top});
  final ChessGame game;
  final ChessState state;
  final String color;
  final List<RoomPlayer> players;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final seat = state.seatOfColor(color);
    final p = players.where((x) => x.userId == seat.userId).firstOrNull ?? RoomPlayer(userId: seat.userId, displayName: seat.displayName, seat: seat.seat, ready: true, connected: seat.connected);
    final active = !state.finished && state.turn == color;
    final isMe = seat.seat == game.mySeat;
    final diff = state.materialDiff(color);
    final captured = state.captured[color] ?? const [];
    final accent = color == 'w' ? ZpColors.champagne : const Color(0xFF9A93AD);
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.xs, ZpSpace.md, ZpSpace.xs),
      child: Row(children: [
        ZpAvatar(player: p, size: 44, seatColor: accent, highlight: active, showName: false),
        const SizedBox(width: ZpSpace.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color == 'w' ? ZpColors.ivory : const Color(0xFF2B2833), border: Border.all(color: ZpColors.gold, width: 1.2))),
              const SizedBox(width: 6),
              Flexible(child: Text(isMe ? 'You' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall?.copyWith(color: active ? ZpColors.goldLight : ZpColors.ivory))),
              if (state.drawOffer == seat.seat) Padding(padding: const EdgeInsets.only(left: 6), child: Text('offers a draw', style: t.labelSmall?.copyWith(color: ZpColors.champagne))),
            ]),
            const SizedBox(height: 2),
            _CapturedRow(captured: captured, byWhite: color == 'w', diff: diff, style: game.pieceStyle),
          ]),
        ),
        _ClockBox(game: game, color: color, active: active),
      ]),
    );
  }
}

class _CapturedRow extends StatelessWidget {
  const _CapturedRow({required this.captured, required this.byWhite, required this.diff, required this.style});
  final List<String> captured;
  final bool byWhite;
  final int diff;
  final PieceStyle style;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const order = ['q', 'r', 'b', 'n', 'p'];
    final sorted = [...captured]..sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return SizedBox(
      height: 18,
      child: Row(children: [
        for (var i = 0; i < sorted.length; i++)
          SizedBox(
            width: i == sorted.length - 1 ? 16 : 11,
            child: OverflowBox(
              maxWidth: 18,
              alignment: Alignment.centerLeft,
              child: CustomPaint(size: const Size(18, 18), painter: _PieceGlyph(type: sorted[i], white: !byWhite, style: style)),
            ),
          ),
        if (diff > 0) Padding(padding: const EdgeInsets.only(left: 6), child: Text('+$diff', style: t.labelMedium?.copyWith(color: ZpColors.goldLight, fontWeight: FontWeight.w700))),
        if (sorted.isEmpty && diff <= 0) Text('No captures', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
      ]),
    );
  }
}

class _PieceGlyph extends CustomPainter {
  const _PieceGlyph({required this.type, required this.white, required this.style});
  final String type;
  final bool white;
  final PieceStyle style;
  @override
  void paint(Canvas canvas, Size size) => PiecePainter.paint(canvas, type: type, white: white, size: size.shortestSide, style: style);
  @override
  bool shouldRepaint(_PieceGlyph old) => old.type != type || old.white != white || old.style != style;
}

/// Large clock. Ticks locally from the server deadline while active; red under 20 s.
class _ClockBox extends StatefulWidget {
  const _ClockBox({required this.game, required this.color, required this.active});
  final ChessGame game;
  final String color;
  final bool active;
  @override
  State<_ClockBox> createState() => _ClockBoxState();
}

class _ClockBoxState extends State<_ClockBox> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && widget.active) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _remaining(ChessState s) {
    if (!widget.active || s.finished) return s.clockFor(widget.color);
    final dl = s.turnDeadline;
    if (dl == null) return s.clockFor(widget.color);
    return math.max(0, dl - DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.game.latestState.value ?? widget.game.displayState.value;
    if (s == null) return const SizedBox.shrink();
    final enabled = s.rules.clockEnabled;
    final ms = _remaining(s);
    final urgent = enabled && widget.active && ms < 20_000;
    final fg = !enabled ? ZpColors.textSecondary : urgent ? ZpColors.danger : widget.active ? ZpColors.goldLight : ZpColors.ivory;
    return AnimatedContainer(
      duration: ZpDurations.base,
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: 6),
      decoration: BoxDecoration(
        color: widget.active ? ZpColors.obsidian.withValues(alpha: 0.85) : ZpColors.panel.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ZpRadius.sm),
        border: Border.all(color: (urgent ? ZpColors.danger : widget.active ? ZpColors.goldLight : ZpColors.divider).withValues(alpha: widget.active ? 0.9 : 1)),
        boxShadow: widget.active ? [BoxShadow(color: (urgent ? ZpColors.danger : ZpColors.gold).withValues(alpha: 0.45), blurRadius: 18)] : null,
      ),
      child: Text(
        enabled ? formatClock(ms) : 'No clock',
        style: (enabled ? t.headlineSmall : t.labelMedium)?.copyWith(color: fg, fontFeatures: const [FontFeature.tabularFigures()], fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Horizontal, auto-scrolling SAN list.
class _MoveList extends StatefulWidget {
  const _MoveList({required this.state});
  final ChessState state;
  @override
  State<_MoveList> createState() => _MoveListState();
}

class _MoveListState extends State<_MoveList> {
  final _ctrl = ScrollController();

  @override
  void didUpdateWidget(covariant _MoveList old) {
    super.didUpdateWidget(old);
    if (old.state.san.length != widget.state.san.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_ctrl.hasClients) _ctrl.animateTo(_ctrl.position.maxScrollExtent, duration: ZpDurations.base, curve: Curves.easeOut);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final san = widget.state.san;
    return Container(
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.sm),
      decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(ZpRadius.sm), border: Border.all(color: ZpColors.divider)),
      child: san.isEmpty
          ? Center(child: Text('Moves appear here', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)))
          : ListView.builder(
              controller: _ctrl,
              scrollDirection: Axis.horizontal,
              itemCount: (san.length + 1) ~/ 2,
              itemBuilder: (context, i) {
                final w = san[i * 2];
                final b = i * 2 + 1 < san.length ? san[i * 2 + 1] : null;
                final last = i == (san.length - 1) ~/ 2;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${i + 1}.', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)),
                    const SizedBox(width: 3),
                    Text(w, style: t.labelMedium?.copyWith(color: last && b == null ? ZpColors.goldLight : ZpColors.ivory, fontWeight: FontWeight.w600)),
                    if (b != null) ...[const SizedBox(width: 5), Text(b, style: t.labelMedium?.copyWith(color: last ? ZpColors.goldLight : ZpColors.textSecondary, fontWeight: FontWeight.w600))],
                  ]),
                );
              },
            ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.game, required this.state, required this.confirm});
  final ChessGame game;
  final ChessState state;
  final Future<void> Function(String title, String body, String action, Future<void> Function() run, {bool danger}) confirm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (game.isSpectator) {
      return Padding(padding: const EdgeInsets.all(ZpSpace.sm), child: Text('Watching both clocks', style: t.labelSmall?.copyWith(color: ZpColors.textMuted)));
    }
    if (state.finished) return const SizedBox(height: ZpSpace.sm);
    final offeredToMe = state.drawOffer != null && state.drawOffer != game.mySeat;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.md, ZpSpace.xs, ZpSpace.md, ZpSpace.sm),
      child: offeredToMe
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: ZpSpace.md, vertical: ZpSpace.sm),
              decoration: BoxDecoration(color: ZpColors.royalPurpleDeep.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(ZpRadius.md), border: Border.all(color: ZpColors.champagne.withValues(alpha: 0.7))),
              child: Row(children: [
                const Icon(Icons.handshake_rounded, color: ZpColors.champagne, size: 20),
                const SizedBox(width: ZpSpace.sm),
                Expanded(child: Text('${state.seatOrNull(state.drawOffer)?.displayName ?? 'Opponent'} offers a draw', style: t.bodyMedium?.copyWith(color: ZpColors.ivory))),
                ZpButton(label: 'Decline', kind: ZpButtonKind.ghost, compact: true, onPressed: game.declineDraw),
                const SizedBox(width: ZpSpace.xs),
                ZpButton(label: 'Accept', compact: true, onPressed: game.acceptDraw),
              ]),
            ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.3, end: 0)
          : Row(children: [
              Expanded(
                child: ZpButton(
                  label: 'Resign',
                  icon: Icons.flag_rounded,
                  kind: ZpButtonKind.ghost,
                  compact: true,
                  onPressed: () => confirm('Resign the game?', 'Your opponent will be awarded the win.', 'Resign', game.resign, danger: true),
                ),
              ),
              const SizedBox(width: ZpSpace.md),
              Expanded(
                child: ZpButton(
                  label: state.drawOffer == game.mySeat ? 'Draw offered' : 'Offer draw',
                  icon: Icons.handshake_rounded,
                  kind: ZpButtonKind.secondary,
                  compact: true,
                  onPressed: state.drawOffer == null ? () => confirm('Offer a draw?', 'Your opponent can accept or decline. Making a move withdraws the offer.', 'Offer', game.offerDraw) : null,
                ),
              ),
            ]),
    );
  }
}

class _PromotionPicker extends StatelessWidget {
  const _PromotionPicker({required this.game});
  final ChessGame game;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final white = game.myColor == 'w';
    return ZpOverlay(
      dismissible: true,
      onDismiss: game.cancelPromotion,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Promote to', style: t.titleLarge?.copyWith(color: ZpColors.goldLight)),
        const SizedBox(height: ZpSpace.lg),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final p in const ['q', 'r', 'b', 'n'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(ZpRadius.md),
                onTap: () => game.choosePromotion(p),
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(color: ZpColors.obsidian.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(ZpRadius.md), border: Border.all(color: ZpColors.gold.withValues(alpha: 0.7))),
                  child: CustomPaint(painter: _PieceGlyph(type: p, white: white, style: game.pieceStyle)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: ZpSpace.md),
        ZpButton(label: 'Cancel', kind: ZpButtonKind.ghost, compact: true, onPressed: game.cancelPromotion),
      ]),
    );
  }
}

class _FinishedOverlay extends StatelessWidget {
  const _FinishedOverlay({required this.game, required this.state});
  final ChessGame game;
  final ChessState state;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = state.result!;
    final winner = state.seatOrNull(r.winnerSeat);
    final iWon = !game.isSpectator && r.winnerSeat == game.mySeat;
    final title = r.isDraw ? 'Draw' : game.isSpectator ? '${winner?.displayName ?? 'Winner'} wins' : iWon ? 'Victory' : 'Defeat';
    final color = r.isDraw ? ZpColors.champagne : iWon || game.isSpectator ? ZpColors.goldLight : ZpColors.textSecondary;
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.62),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: ZpSpace.xl, vertical: ZpSpace.md),
          decoration: BoxDecoration(
            color: ZpColors.obsidian.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(ZpRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.8)),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 28)],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: t.headlineSmall?.copyWith(color: color, letterSpacing: 2)),
            const SizedBox(height: 4),
            Text(r.isDraw ? r.reasonLabel : 'by ${r.reasonLabel.toLowerCase()}', style: t.bodyMedium?.copyWith(color: ZpColors.textSecondary)),
          ]),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), curve: Curves.easeOutBack),
      ),
    );
  }
}
