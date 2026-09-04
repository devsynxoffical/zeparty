import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';

/// Premium membership-style banner: black base with metallic gold reflection,
/// diagonal shine sweep, gold border and layered text hierarchy.
class PremiumBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String? footer;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showShine;
  final bool animated;

  const PremiumBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.footer,
    this.trailing,
    this.onTap,
    this.showShine = true,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: AppColors.getBannerGradient(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.goldBorder : AppColors.metallicBlue)
              .withValues(alpha: isDark ? 0.85 : 0.5),
          width: 1.2,
        ),
        boxShadow: AppColors.primaryGlow(isDark, alpha: 0.16, blur: 26, spread: 1),
      ),
      child: Stack(
        children: [
          // Curved metallic light reflection
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.warmGold : AppColors.lightBlue)
                        .withValues(alpha: isDark ? 0.35 : 0.3),
                    (isDark ? AppColors.warmGold : AppColors.lightBlue)
                        .withValues(alpha: 0.10),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.deepBronze : AppColors.darkNavyAccent)
                        .withValues(alpha: isDark ? 0.5 : 0.25),
                    AppColors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Diagonal shine bar
          Positioned(
            top: 0,
            bottom: 0,
            left: -60,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.transparent,
                      (isDark ? AppColors.goldHighlight : AppColors.white)
                          .withValues(alpha: 0.22),
                      AppColors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: trailing != null ? 60 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? AppColors.warmGold : AppColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? AppColors.secondaryText : AppColors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? AppColors.lightGold : AppColors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    footer!,
                    style: TextStyle(
                      color: isDark ? AppColors.mutedText : AppColors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Positioned(right: 0, top: 0, bottom: 0, child: Center(child: trailing)),
        ],
      ),
    );

    if (!showShine) return banner;
    return MetallicShine(
      duration: const Duration(milliseconds: 3200),
      bandWidth: 0.3,
      beginX: -0.8,
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: banner)
          : banner,
    );
  }
}
