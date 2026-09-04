import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Small premium label badge. Variants:
///  - `premium` (default): metallic gold gradient with dark text
///  - `outline`: dark surface with gold border + gold text
///  - `vip`: light-gold text with deep bronze glow
class GoldBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool outline;
  final bool vip;
  final double fontSize;
  final EdgeInsets padding;

  const GoldBadge({
    super.key,
    required this.label,
    this.icon,
    this.outline = false,
    this.vip = false,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final borderStrong = AppColors.getBorderStrong(isDark);

    final gradient = isDark
        ? (vip
            ? const LinearGradient(
                colors: [AppColors.deepBronze, AppColors.metallicGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.premiumGradient)
        : (vip
            ? const LinearGradient(
                colors: [AppColors.darkNavyAccent, AppColors.royalBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppColors.metallicBlueGradient);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: outline ? null : gradient,
        color: outline
            ? (isDark ? AppColors.cardBlack : AppColors.lightSurface)
            : null,
        borderRadius: BorderRadius.circular(20),
        border: outline
            ? Border.all(color: borderStrong, width: 1.1)
            : null,
        boxShadow: outline
            ? null
            : [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: fontSize + 2,
              color: outline
                  ? primaryColor
                  : (isDark ? AppColors.black : AppColors.white),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: outline
                  ? primaryColor
                  : (isDark
                      ? (vip ? AppColors.goldHighlight : AppColors.black)
                      : AppColors.white),
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
