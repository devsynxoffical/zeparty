import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';

/// Animated coin counter. Tweens between values so rewards visibly count up.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins, this.onTap, this.compact = false});
  final int coins;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ZpRadius.pill),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 4, compact ? 10 : 14, 4),
          decoration: BoxDecoration(
            color: ZpColors.obsidian.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(ZpRadius.pill),
            border: Border.all(color: ZpColors.gold.withValues(alpha: 0.55)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(image: ZpAssets.image(LudoAssets.coin), width: compact ? 18 : 22, height: compact ? 18 : 22, errorBuilder: (_, _, _) => const Icon(Icons.monetization_on_rounded, color: ZpColors.gold, size: 20)),
              const SizedBox(width: 6),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: coins, end: coins),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Text(_fmt(v), style: (compact ? t.labelMedium : t.titleMedium)?.copyWith(color: ZpColors.goldLight, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}
