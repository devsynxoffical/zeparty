import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_wallet/zeparty_game_wallet.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  static Route<void> route() => MaterialPageRoute(builder: (_) => const AchievementsScreen());
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String? _busy;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => SessionScope.read(context).wallet.refreshAll());
  }

  Future<void> _claim(Achievement a) async {
    final w = SessionScope.read(context).wallet;
    setState(() => _busy = a.id);
    try {
      final coins = await w.claimAchievement(a);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('+$coins coins for ${a.name}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final w = s.wallet;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ZpBackdrop(
        child: ListenableBuilder(
          listenable: w,
          builder: (context, _) {
            final list = w.achievements;
            if (w.loading && list.isEmpty) return const ZpLoading();
            if (list.isEmpty) return const ZpEmpty(icon: Icons.military_tech_outlined, title: 'No achievements available');
            final unlocked = list.where((a) => a.unlocked).length;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(ZpSpace.lg),
              children: [
                ZpPanel(
                  child: Row(children: [
                    Expanded(child: Text('$unlocked of ${list.length} unlocked', style: t.titleLarge)),
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(alignment: Alignment.center, children: [
                        CircularProgressIndicator(value: unlocked / list.length, color: ZpColors.gold, backgroundColor: ZpColors.gold.withValues(alpha: 0.15), strokeWidth: 5),
                        Text('${(100 * unlocked / list.length).round()}%', style: t.labelMedium),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: ZpSpace.md),
                for (final (i, a) in list.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZpSpace.sm),
                    child: ZpPanel(
                      blur: false,
                      radius: ZpRadius.md,
                      borderColor: a.claimable ? ZpColors.gold : null,
                      glow: a.claimable,
                      padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
                      child: Row(children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: a.unlocked ? ZpColors.goldGradient : null, color: a.unlocked ? null : ZpColors.panelRaised),
                          child: Icon(Icons.military_tech_rounded, color: a.unlocked ? ZpColors.obsidian : ZpColors.textMuted),
                        ),
                        const SizedBox(width: ZpSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.name, style: t.titleMedium?.copyWith(color: a.unlocked ? ZpColors.textPrimary : ZpColors.textSecondary)),
                            Text(a.description, style: t.bodySmall),
                            Text('${s.entry(a.gameId)?.title ?? 'All games'}  +${a.rewardCoins} coins', style: t.labelSmall?.copyWith(color: ZpColors.gold)),
                          ]),
                        ),
                        if (a.claimable)
                          ZpButton(label: 'Claim', compact: true, loading: _busy == a.id, onPressed: _busy == null ? () => _claim(a) : null)
                        else if (a.claimedAt != null)
                          const Icon(Icons.check_circle_rounded, color: ZpColors.success)
                        else if (!a.unlocked)
                          const Icon(Icons.lock_outline_rounded, color: ZpColors.textMuted),
                      ]),
                    ),
                  ).animate().fadeIn(delay: (40 * i).ms).slideX(begin: 0.05, end: 0),
              ],
            );
          },
        ),
      ),
    );
  }
}
