import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';
import 'package:zeparty_game_wallet/zeparty_game_wallet.dart';

import '../session_controller.dart';
import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import '../widgets/zp_button.dart';
import '../widgets/zp_panel.dart';
import '../widgets/zp_states.dart';

/// Wallet overview + transaction history + daily reward claim.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  static Route<void> route() => MaterialPageRoute(builder: (_) => const WalletScreen());
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => SessionScope.read(context).wallet.refreshAll());
  }

  Future<void> _claimDaily() async {
    final w = SessionScope.read(context).wallet;
    setState(() => _claiming = true);
    try {
      final amount = await w.claimDaily();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(amount > 0 ? 'Daily reward: +$amount coins' : 'Already claimed today')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = SessionScope.of(context).wallet;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ZpBackdrop(
        child: ListenableBuilder(
          listenable: w,
          builder: (context, _) {
            final tx = w.transactions;
            return RefreshIndicator(
              color: ZpColors.gold,
              backgroundColor: ZpColors.panel,
              onRefresh: w.refreshAll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.all(ZpSpace.lg),
                children: [
                  ZpPanel(
                    glow: true,
                    child: Column(children: [
                      Image(image: ZpAssets.image(LudoAssets.coin), width: 64, height: 64, errorBuilder: (_, _, _) => const Icon(Icons.monetization_on_rounded, color: ZpColors.gold, size: 56))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(begin: -3, end: 3, duration: 1800.ms, curve: Curves.easeInOut),
                      const SizedBox(height: ZpSpace.md),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: 0, end: w.coins),
                        duration: 900.ms,
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text('$v', style: t.displayLarge?.copyWith(color: ZpColors.goldLight, fontSize: 48)),
                      ),
                      Text('ZEPARTY COINS', style: t.labelSmall?.copyWith(letterSpacing: 3)),
                      const SizedBox(height: ZpSpace.lg),
                      ZpButton(label: 'Claim daily reward', icon: Icons.card_giftcard_rounded, expand: true, loading: _claiming, onPressed: _claiming ? null : _claimDaily),
                      const SizedBox(height: ZpSpace.sm),
                      Text('In-app entertainment currency. No cash value, no withdrawals, no wagering.', style: t.bodySmall, textAlign: TextAlign.center),
                    ]),
                  ),
                  const ZpSectionHeader('Transactions'),
                  if (w.loading && tx.isEmpty)
                    const Column(children: [ZpSkeleton(height: 56), SizedBox(height: 8), ZpSkeleton(height: 56), SizedBox(height: 8), ZpSkeleton(height: 56)])
                  else if (tx.isEmpty)
                    const ZpEmpty(icon: Icons.receipt_long_outlined, title: 'No transactions yet', message: 'Play a match or claim your daily reward.')
                  else
                    for (final (i, x) in tx.indexed) _TxRow(x).animate().fadeIn(delay: (30 * i).ms),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow(this.x);
  final WalletTransaction x;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final credit = x.amount > 0;
    final icon = switch (x.type) {
      'purchase_cosmetic' => Icons.shopping_bag_rounded,
      'reward_achievement' => Icons.military_tech_rounded,
      'reward_daily' => Icons.card_giftcard_rounded,
      _ => Icons.sports_esports_rounded,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: ZpSpace.sm),
      child: ZpPanel(
        padding: const EdgeInsets.symmetric(horizontal: ZpSpace.lg, vertical: ZpSpace.md),
        radius: ZpRadius.md,
        blur: false,
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: (credit ? ZpColors.success : ZpColors.danger).withValues(alpha: 0.15)),
            child: Icon(icon, color: credit ? ZpColors.success : ZpColors.danger, size: 20),
          ),
          const SizedBox(width: ZpSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x.label, style: t.titleSmall?.copyWith(color: ZpColors.textPrimary)),
              Text(_date(x.createdAt), style: t.labelSmall),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${credit ? '+' : ''}${x.amount}', style: t.titleMedium?.copyWith(color: credit ? ZpColors.success : ZpColors.danger)),
            Text('bal ${x.balanceAfter}', style: t.labelSmall),
          ]),
        ]),
      ),
    );
  }

  static String _date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }
}
