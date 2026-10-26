import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_core/zeparty_game_core.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_avatar.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';

/// Match results + rematch. Rendered as a full-screen overlay on top of the game.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result, required this.room, required this.onRematch, required this.onLeave, this.rematchVotes = const []});
  final MatchResult result;
  final RoomState room;
  final VoidCallback onRematch;
  final VoidCallback onLeave;
  final List<String> rematchVotes;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final t = Theme.of(context).textTheme;
    final me = s.userId;
    final iWon = result.winnerIds.contains(me);
    final myReward = result.rewards[me] ?? 0;
    final sorted = [...result.placements]..sort((a, b) => a.placement.compareTo(b.placement));
    final voted = rematchVotes.contains(me);
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(ZpSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ZpAssets.image(LudoAssets.victoryCrown), width: 140, height: 140, errorBuilder: (_, _, _) => const Icon(Icons.emoji_events_rounded, color: ZpColors.gold, size: 100))
                    .animate()
                    .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 900.ms)
                    .then()
                    .shimmer(duration: 1200.ms, color: ZpColors.goldLight),
                const SizedBox(height: ZpSpace.md),
                Text(iWon ? 'VICTORY' : 'MATCH OVER', style: t.displayMedium?.copyWith(color: iWon ? ZpColors.goldLight : ZpColors.ivory)).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0),
                if (myReward > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: ZpSpace.sm),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image(image: ZpAssets.image(LudoAssets.coin), width: 22, height: 22, errorBuilder: (_, _, _) => const Icon(Icons.monetization_on_rounded, color: ZpColors.gold, size: 20)),
                      const SizedBox(width: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: myReward),
                        duration: 1200.ms,
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text('+$v coins', style: t.titleLarge?.copyWith(color: ZpColors.goldLight)),
                      ),
                    ]).animate().fadeIn(delay: 600.ms),
                  ),
                const SizedBox(height: ZpSpace.xl),
                ZpPanel(
                  glow: iWon,
                  child: Column(
                    children: [
                      for (final (i, p) in sorted.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: ZpSpace.sm),
                          child: Row(children: [
                            SizedBox(width: 36, child: Text(_ordinal(p.placement), style: t.headlineSmall?.copyWith(color: p.placement == 1 ? ZpColors.goldLight : ZpColors.textSecondary))),
                            ZpAvatar(player: room.playerById(p.userId) ?? RoomPlayer(userId: p.userId, displayName: p.userId, seat: p.seat, ready: false, connected: true), size: 44, showName: false, highlight: p.userId == me),
                            const SizedBox(width: ZpSpace.md),
                            Expanded(child: Text(room.playerById(p.userId)?.displayName ?? p.userId, style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Text('${p.score} pts', style: t.labelMedium),
                            const SizedBox(width: ZpSpace.md),
                            Text('+${result.rewards[p.userId] ?? 0}', style: t.titleSmall?.copyWith(color: ZpColors.goldLight)),
                          ]),
                        ).animate().fadeIn(delay: (500 + 120 * i).ms).slideX(begin: 0.1, end: 0),
                    ],
                  ),
                ),
                const SizedBox(height: ZpSpace.xl),
                if (rematchVotes.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: ZpSpace.md), child: Text('${rematchVotes.length}/${room.players.length} want a rematch', style: t.bodyMedium)),
                ZpButton(label: voted ? 'Waiting for others' : 'Rematch', icon: Icons.replay_rounded, expand: true, onPressed: voted ? null : onRematch),
                const SizedBox(height: ZpSpace.md),
                ZpButton(label: 'Back to lobby', kind: ZpButtonKind.ghost, expand: true, onPressed: onLeave),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
}
