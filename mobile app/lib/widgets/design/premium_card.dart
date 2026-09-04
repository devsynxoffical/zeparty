import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';

/// Standard dark luxury card with a subtle gold border.
/// Set `premium`/`glow` for selected or VIP content to increase gold presence.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool premium;
  final bool glowing;
  final bool animate;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.premium = false,
    this.glowing = false,
    this.animate = false,
    this.onTap,
    this.gradient,
    this.borderColor,
    this.borderWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorder = borderColor ??
        (premium || glowing
            ? AppColors.getBorderStrong(isDark)
            : (isDark ? AppColors.borderGold : AppColors.lightBorder));

    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ??
            (isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF161616), Color(0xFF121212)],
                  )
                : null),
        color: gradient == null ? AppColors.getCard(isDark) : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: effectiveBorder,
          width: glowing ? borderWidth + 0.6 : borderWidth,
        ),
        boxShadow: glowing
            ? AppColors.primaryGlow(isDark, alpha: 0.26, blur: 20)
            : (isDark ? AppColors.cardShadow : null),
      ),
      child: child,
    );

    if (animate && glowing) {
      card = GoldGlowBorder(
        borderRadius: radius,
        color: AppColors.getPrimary(isDark),
        child: card,
      );
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      );
    }
    return card;
  }
}
