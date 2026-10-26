import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

import '../model/course.dart';
import '../model/mini_golf_state.dart';

/// Holes x players grid with par row and totals. Shown from the HUD and for 3 s
/// whenever a hole completes.
class Scorecard extends StatelessWidget {
  const Scorecard({super.key, required this.state, required this.mySeat, this.onClose});
  final MiniGolfState state;
  final int? mySeat;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final holes = state.rules.holes.length;
    final cellW = holes > 6 ? 30.0 : 38.0;
    final current = state.holeIndex;
    Widget cell(Widget child, {double? width, Color? bg}) => Container(
          width: width ?? cellW,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: child,
        );
    final headerStyle = t.labelSmall?.copyWith(color: ZpColors.textSecondary, letterSpacing: 1);
    return ZpPanel(
      padding: const EdgeInsets.all(ZpSpace.md),
      glow: true,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.list_alt_rounded, color: ZpColors.goldLight, size: 20),
          const SizedBox(width: ZpSpace.sm),
          Text('Scorecard', style: t.titleMedium?.copyWith(color: ZpColors.goldLight)),
          const Spacer(),
          if (onClose != null) ZpIconButton(icon: Icons.close_rounded, onPressed: onClose, size: 36),
        ]),
        const SizedBox(height: ZpSpace.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              cell(Text('HOLE', style: headerStyle), width: 96),
              for (var h = 0; h < holes; h++) cell(Text('${h + 1}', style: headerStyle?.copyWith(color: h == current && !state.finished ? ZpColors.goldLight : null)), bg: h == current && !state.finished ? ZpColors.gold.withValues(alpha: 0.12) : null),
              cell(Text('TOT', style: headerStyle), width: 44),
            ]),
            Row(children: [
              cell(Align(alignment: Alignment.centerLeft, child: Text('Par', style: t.labelMedium?.copyWith(color: ZpColors.textMuted))), width: 96),
              for (var h = 0; h < holes; h++) cell(Text('${h == current ? state.course.par : parForHole(state.rules.holes, h)}', style: t.labelMedium?.copyWith(color: ZpColors.textMuted))),
              cell(const SizedBox.shrink(), width: 44),
            ]),
            const Divider(height: 8, color: ZpColors.divider),
            for (final seat in _ranked())
              Row(children: [
                cell(
                  Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: ZpColors.seat(seat.seat))),
                    const SizedBox(width: 6),
                    Expanded(child: Text(seat.seat == mySeat ? 'You' : seat.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: seat.forfeited ? ZpColors.textMuted : ZpColors.ivory))),
                  ]),
                  width: 96,
                ),
                for (var h = 0; h < holes; h++) _scoreCell(h, seat, cell, t),
                cell(Text('${seat.total}', style: t.titleSmall?.copyWith(color: ZpColors.goldLight)), width: 44),
              ]),
          ]),
        ),
        if (state.finished && state.placements.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: ZpSpace.sm),
            child: Text('Winner: ${state.seatOrNull(state.placements.first)?.displayName ?? ''}', style: t.labelMedium?.copyWith(color: ZpColors.goldLight)),
          ),
      ]),
    );
  }

  List<MiniGolfSeat> _ranked() {
    if (state.placements.isNotEmpty) return state.placements.map(state.seatAt).toList();
    final list = [...state.seats];
    list.sort((a, b) => a.total.compareTo(b.total));
    return list;
  }

  Widget _scoreCell(int h, MiniGolfSeat seat, Widget Function(Widget, {double? width, Color? bg}) cell, TextTheme t) {
    final played = h < state.holeIndex || (h == state.holeIndex && seat.holed) || state.finished;
    final strokes = h < seat.strokes.length ? seat.strokes[h] : 0;
    final live = h == state.holeIndex && !played && strokes > 0;
    final won = h < state.holeWinners.length && state.holeWinners[h] == seat.seat;
    final text = played ? '$strokes' : (live ? '$strokes' : '');
    return cell(
      Text(text, style: t.labelLarge?.copyWith(color: won ? ZpColors.goldLight : (live ? ZpColors.textSecondary : ZpColors.ivory), fontWeight: won ? FontWeight.w700 : null)),
      bg: won ? ZpColors.gold.withValues(alpha: 0.15) : null,
    );
  }
}
