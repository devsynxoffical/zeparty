import 'package:flutter/material.dart';
import 'app_colors.dart';

/// ---------------------------------------------------------------------------
/// AppThemeColors — a single resolved palette for the current theme.
///
/// USAGE in any widget:
///   final tc = AppThemeColors.of(context);
///   container.color = tc.primary;     // royalBlue (light) or warmGold (dark)
///   text.color     = tc.textPrimary;  // dark text (light) or white (dark)
///
/// This is the single source of truth for every color in the app.
/// Dark mode  → Luxury Gold/Black
/// Light mode → Clean White/Royal Blue (zero gold)
/// ---------------------------------------------------------------------------
class AppThemeColors {
  final bool isDark;

  const AppThemeColors._(this.isDark);

  /// Resolve from [BuildContext].
  factory AppThemeColors.of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppThemeColors._(isDark);
  }

  // ── Surfaces / Backgrounds ────────────────────────────────────────────────
  Color get background      => isDark ? AppColors.black          : AppColors.lightBackground;
  Color get card            => isDark ? AppColors.cardBlack      : AppColors.lightCard;
  Color get surface         => isDark ? AppColors.softBlack      : AppColors.lightSurface;
  Color get surfaceVariant  => isDark ? AppColors.darkBlack      : AppColors.lightCardSecondary;

  // ── Primary accent (Gold ↔ Royal Blue) ───────────────────────────────────
  Color get primary         => isDark ? AppColors.warmGold       : AppColors.royalBlue;
  Color get primaryDeep     => isDark ? AppColors.metallicGold   : AppColors.deepRoyalBlue;
  Color get primaryLight    => isDark ? AppColors.lightGold      : AppColors.lightBlue;
  Color get primaryBorder   => isDark ? AppColors.goldBorder     : AppColors.royalBlue;
  Color get primaryMuted    => isDark ? AppColors.deepBronze     : AppColors.lightBorder;
  Color get onPrimary       => isDark ? AppColors.black          : AppColors.white;

  // ── Text ─────────────────────────────────────────────────────────────────
  Color get textPrimary     => isDark ? AppColors.primaryText    : AppColors.lightTextPrimary;
  Color get textSecondary   => isDark ? AppColors.secondaryText  : AppColors.lightTextSecondary;
  Color get textMuted       => isDark ? AppColors.mutedText      : AppColors.lightMuted;

  // ── Borders ───────────────────────────────────────────────────────────────
  Color get border          => isDark ? AppColors.borderGold     : AppColors.lightBorder;
  Color get borderStrong    => isDark ? AppColors.goldBorder     : AppColors.lightAccent.withValues(alpha: 0.4);

  // ── Gradients ─────────────────────────────────────────────────────────────
  LinearGradient get accentGradient   => isDark ? AppColors.metallicGoldGradient : AppColors.metallicBlueGradient;
  LinearGradient get premiumGradient  => isDark ? AppColors.premiumGradient      : AppColors.metallicBlueGradient;
  LinearGradient get bannerGradient   => isDark
      ? AppColors.bannerGradient
      : const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
  LinearGradient get backgroundGradient => isDark
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0A07), Color(0xFF080808), Color(0xFF0D0D0D)],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F7FB), Color(0xFFE8EEF5)],
        );

  // ── Shadows / Glows ───────────────────────────────────────────────────────
  List<BoxShadow> primaryGlow({double alpha = 0.30, double blur = 22, double spread = 0}) => [
    BoxShadow(
      color: primary.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: primary.withValues(alpha: alpha * 0.5),
      blurRadius: blur * 0.6,
      offset: const Offset(0, 0),
    ),
  ];

  // ── Status ────────────────────────────────────────────────────────────────
  Color get live     => AppColors.liveRed;
  Color get success  => isDark ? AppColors.warmGold    : const Color(0xFF2E7D32);
  Color get error    => AppColors.liveRed;
}
