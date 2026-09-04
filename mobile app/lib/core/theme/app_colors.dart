import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Dual Design System — ZeParty
///
/// Dark Mode  → Luxury Gold / Black (warmGold + metallicGold + deepBronze)
/// Light Mode → Metallic Blue / White (metallicBlue + lightBlue + darkNavy)
///
/// Use AppThemeColors.of(context) to get the right color for the current
/// theme. Never hard-code warmGold/metallicGold in widgets that appear in
/// both modes.
/// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // =====================================================================
  // Surfaces / Backgrounds
  // =====================================================================
  static const Color black = Color(0xFF080808); // Black
  static const Color darkBlack = Color(0xFF0D0D0D); // Dark Black
  static const Color cardBlack = Color(0xFF141414); // Card Black
  static const Color softBlack = Color(0xFF1B1B1B); // Soft Black

  /// Light-mode surfaces (White & Blue theme).
  static const Color champagne = Color(0xFFF4F7FB);
  static const Color champagneCard = Color(0xFFFFFFFF);
  static const Color champagneSoft = Color(0xFFE8EEF5);

  // =====================================================================
  // Gold Palette
  // =====================================================================
  static const Color metallicGold = Color(0xFFCF9828); // Metallic Gold
  static const Color warmGold = Color(0xFFE7C55F); // Warm Gold
  static const Color lightGold = Color(0xFFF4D982); // Light Gold
  static const Color deepBronze = Color(0xFF8C601C); // Deep Bronze
  static const Color goldBorder = Color(0xFFB98525); // Gold Border
  static const Color goldHighlight = Color(0xFFFFE29A); // Gold Highlight

  /// Subtle bronze-tinted dark border for resting cards.
  static const Color borderGold = Color(0xFF3A2E14);

  // =====================================================================
  // Text
  // =====================================================================
  static const Color primaryText = Color(0xFFFFFFFF); // Primary Text
  static const Color secondaryText = Color(0xFFB8B8B8); // Secondary Text
  static const Color mutedText = Color(0xFF777777); // Muted Text

  // =====================================================================
  // Status / System
  // =====================================================================
  static const Color success = Color(0xFFD4AF37);
  static const Color liveGreen = Color(0xFF10B981);
  static const Color liveRed = Color(0xFFD93636);
  static const Color live = liveRed;
  static const Color error = liveRed;
  static const Color danger = Color(0xFFC0392B);
  static const Color transparent = Color(0x00000000);
  static const Color white = Color(0xFFFFFFFF);

  // =====================================================================
  // Gradients
  // =====================================================================

  /// Metallic gold CTA gradient (bronze -> gold -> light gold -> gold).
  static const LinearGradient metallicGoldGradient = LinearGradient(
    colors: [
      deepBronze,
      metallicGold,
      warmGold,
      lightGold,
      warmGold,
      metallicGold,
      deepBronze,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Diagonal premium gold gradient for banners, badges and VIP content.
  static const LinearGradient premiumGradient = LinearGradient(
    colors: [
      deepBronze,
      metallicGold,
      warmGold,
      goldHighlight,
      warmGold,
      metallicGold,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep gradient for premium banners with a metallic reflection feel.
  static const LinearGradient bannerGradient = LinearGradient(
    colors: [
      Color(0xFF191204),
      darkBlack,
      Color(0xFF2B1F08),
      Color(0xFF141414),
      Color(0xFF1E1505),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft bronze wash used behind important sections.
  static const LinearGradient bronzeWashGradient = LinearGradient(
    colors: [
      Color(0xFF0D0D0D),
      Color(0xFF15100A),
      Color(0xFF0D0D0D),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Very subtle warm radial glow used as a screen background tint.
  static final RadialGradient radialGoldGlow = RadialGradient(
    colors: [
      deepBronze.withValues(alpha: 0.16),
      deepBronze.withValues(alpha: 0.06),
      transparent,
    ],
    radius: 1.1,
  );

  // =====================================================================
  // Shadows / Glows
  // =====================================================================

  /// Soft gold glow for selected / premium cards.
  static List<BoxShadow> goldGlow({
    double alpha = 0.30,
    double blur = 22,
    double spread = 0,
  }) =>
      [
        BoxShadow(
          color: metallicGold.withValues(alpha: alpha),
          blurRadius: blur,
          spreadRadius: spread,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: warmGold.withValues(alpha: alpha * 0.5),
          blurRadius: blur * 0.6,
          offset: const Offset(0, 0),
        ),
      ];

  /// Resting dark card shadow.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 12,
      offset: Offset(0, 5),
    ),
  ];

  // =====================================================================
  // Light Mode Palette — White · Metallic Blue · Light Blue · Dark Navy
  // =====================================================================
  static const Color lightBackground   = Color(0xFFFFFFFF);   // Pure White
  static const Color lightCard         = Color(0xFFFFFFFF);   // White card
  static const Color lightSurface      = Color(0xFFE3F2FD);   // Light Blue surface
  static const Color lightTextPrimary  = Color(0xFF0D1B4B);   // Dark Navy text
  static const Color lightTextSecondary = Color(0xFF1E3A6E);  // Medium navy
  static const Color lightMuted        = Color(0xFF6B8CC5);   // Muted blue
  static const Color lightBorder       = Color(0xFFBBDEFB);   // Light Blue border
  static const Color lightAccent       = Color(0xFF1565C0);   // Metallic Blue

  // ── Named light-mode accent colours ──────────────────────────────────────
  /// Metallic Blue — main CTA, selected state, buttons (replaces warmGold)
  static const Color metallicBlue      = Color(0xFF1565C0);
  /// Light Blue — surfaces, chips, highlight backgrounds (replaces lightGold)
  static const Color lightBlueAccent   = Color(0xFFE3F2FD);
  /// Dark Navy — deep accents, headings (replaces deepBronze / metallicGold)
  static const Color darkNavyAccent    = Color(0xFF0D47A1);
  /// Royal Blue — kept for backward compat
  static const Color royalBlue         = Color(0xFF1565C0);
  static const Color deepRoyalBlue     = Color(0xFF0D47A1);

  // =====================================================================
  // Primary & Color Aliases
  // =====================================================================
  static const Color primaryBlue = Color(0xFF1976D2);
  static const Color cyan = Color(0xFF00ACC1);
  static const Color violet = Color(0xFF7B1FA2);
  static const Color accent = warmGold;
  static const Color primary = warmGold;
  static const Color gold = warmGold;
  static const Color darkGold = deepBronze;
  static const Color deepBlue = Color(0xFF0D47A1);
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color veryLightSurface = Color(0xFFF8FAFC);
  static const Color lightCardSecondary = Color(0xFFF1F5F9);
  static const Color secondaryTextLight = lightTextSecondary;
  static const Color lightBorderF0 = lightBorder;
  static const Color textPrimary = lightTextPrimary;
  static const Color textSecondary = lightTextSecondary;
  static const Color darkTextSecondary = secondaryText;
  static const Color cardBackground = cardBlack;
  static const Color background = black;
  static const Color surface = softBlack;

  // Dark-mode aliases (kept for compatibility with existing widgets).
  static const Color darkBackground = black;
  static const Color darkCard = cardBlack;
  static const Color darkCardSecondary = softBlack;
  static const Color darkSecondarySurface = softBlack;
  static const Color primaryGold = warmGold;
  static const Color secondaryGold = metallicGold;
  static const Color primaryTextDark = primaryText;
  static const Color secondaryTextDark = secondaryText;
  static const Color mutedIconDark = mutedText;
  static const Color borderDark = borderGold;

  // ── Blue gradients for light mode ────────────────────────────────────────

  /// Metallic Blue CTA gradient (navy → metallic blue → sky → metallic blue → navy)
  /// — mirror of metallicGoldGradient, used in light mode for buttons / banners.
  static const LinearGradient metallicBlueGradient = LinearGradient(
    colors: [
      Color(0xFF0D47A1), // dark navy
      Color(0xFF1565C0), // metallic blue
      Color(0xFF1976D2), // royal blue
      Color(0xFF42A5F5), // sky blue highlight
      Color(0xFF1976D2),
      Color(0xFF1565C0),
      Color(0xFF0D47A1),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Premium blue gradient — diagonal (replaces premiumGradient in light mode).
  static const LinearGradient premiumBlueGradient = LinearGradient(
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF1565C0),
      Color(0xFF1976D2),
      Color(0xFFBBDEFB), // highlight
      Color(0xFF1976D2),
      Color(0xFF1565C0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Banner gradient for light mode (navy blue).
  static const LinearGradient bannerBlueGradient = LinearGradient(
    colors: [
      Color(0xFF0A1929),
      Color(0xFF0D2B54),
      Color(0xFF0D47A1),
      Color(0xFF1565C0),
      Color(0xFF0D47A1),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy gradient aliases.
  static const LinearGradient primaryGradient = metallicGoldGradient;
  static const LinearGradient vipGradient = premiumGradient;
  static const LinearGradient goldGradient = metallicGoldGradient;

  // =====================================================================
  // Theme-aware helpers
  // Dark Mode  = Luxury Gold / Black
  // Light Mode = Metallic Blue / White / Dark Navy
  // =====================================================================
  static Color getPrimary(bool isDark)        => isDark ? warmGold        : metallicBlue;
  static Color getPrimaryDeep(bool isDark)    => isDark ? metallicGold    : darkNavyAccent;
  static Color getPrimaryLight(bool isDark)   => isDark ? lightGold       : lightBlueAccent;
  static Color getOnPrimary(bool isDark)      => isDark ? black           : white;
  static Color getBackground(bool isDark)     => isDark ? black           : lightBackground;
  static Color getCard(bool isDark)           => isDark ? cardBlack       : lightCard;
  static Color getSurface(bool isDark)        => isDark ? softBlack       : lightSurface;
  static Color getTextPrimary(bool isDark)    => isDark ? primaryText     : lightTextPrimary;
  static Color getTextSecondary(bool isDark)  => isDark ? secondaryText   : lightTextSecondary;
  static Color getMuted(bool isDark)          => isDark ? mutedText       : lightMuted;
  static Color getBorder(bool isDark)         => isDark ? borderGold      : lightBorder;
  static Color getBorderStrong(bool isDark)   => isDark ? goldBorder      : metallicBlue;
  static LinearGradient getAccentGradient(bool isDark) =>
      isDark ? metallicGoldGradient : metallicBlueGradient;
  static LinearGradient getPremiumGradient(bool isDark) =>
      isDark ? premiumGradient : premiumBlueGradient;
  static LinearGradient getBannerGradient(bool isDark) =>
      isDark ? bannerGradient : bannerBlueGradient;

  /// Text colour on top of primary-coloured surface (black on gold, white on blue).
  static Color onPrimary({bool isDark = true}) => isDark ? black : white;
  static Color onGold({bool isDark = true}) => isDark ? black : white;

  /// Shimmer colours.
  static Color shimmerHighlight({bool isDark = true}) =>
      isDark ? const Color(0xFF2A2110) : const Color(0xFFBBDEFB);
  static Color shimmerBase({bool isDark = true}) =>
      isDark ? const Color(0xFF1B1B1B) : const Color(0xFFE3F2FD);

  /// Primary glow for whichever mode.
  static List<BoxShadow> primaryGlow(bool isDark, {double alpha = 0.30, double blur = 22, double spread = 0}) => [
    BoxShadow(
      color: getPrimary(isDark).withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: getPrimary(isDark).withValues(alpha: alpha * 0.5),
      blurRadius: blur * 0.6,
      offset: const Offset(0, 0),
    ),
  ];
}

/// Reusable background that layers a soft radial glow over the canvas.
/// Used as the scaffold background on major screens.
class LuxBackground extends StatelessWidget {
  final Widget child;
  final bool showGlow;
  final Alignment glowAlignment;

  const LuxBackground({
    super.key,
    required this.child,
    this.showGlow = true,
    this.glowAlignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B0A07),
                  Color(0xFF080808),
                  Color(0xFF0D0D0D),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),  // pure white
                  Color(0xFFEEF5FF),  // soft light blue
                  Color(0xFFE3F2FD),  // light blue
                ],
              ),
      ),
      child: Stack(
        children: [
          if (showGlow)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        (isDark ? AppColors.deepBronze : AppColors.darkNavyAccent)
                            .withValues(alpha: isDark ? 0.16 : 0.06),
                        AppColors.transparent,
                        AppColors.transparent,
                      ],
                      radius: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
