import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Reusable application logo widget featuring the official ZeParty mascot emblem.
/// Transparent background only — no white box or filled background container.
class AppLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showGlow;
  final bool showBorder;
  final BoxBorder? customBorder;
  final VoidCallback? onTap;

  const AppLogo({
    super.key,
    this.size = 40,
    this.borderRadius,
    this.showGlow = false,
    this.showBorder = false,
    this.customBorder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveRadius = borderRadius ?? (size * 0.22);

    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(effectiveRadius),
      child: Image.asset(
        'assets/images/zeparty_logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.getAccentGradient(isDark),
              borderRadius: BorderRadius.circular(effectiveRadius),
            ),
            child: Icon(
              Icons.live_tv_rounded,
              size: size * 0.55,
              color: AppColors.onPrimary(isDark: isDark),
            ),
          );
        },
      ),
    );

    if (showBorder || customBorder != null || showGlow) {
      image = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: customBorder ??
              (showBorder
                  ? Border.all(
                      color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.5),
                      width: size > 60 ? 2.0 : 1.2,
                    )
                  : null),
          boxShadow: showGlow
              ? AppColors.primaryGlow(isDark, alpha: 0.35, blur: size * 0.3)
              : null,
        ),
        child: image,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: image,
      );
    }

    return image;
  }
}
