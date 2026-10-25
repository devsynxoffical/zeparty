import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'zp_colors.dart';

/// Spacing scale (4pt grid).
class ZpSpace {
  ZpSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class ZpRadius {
  ZpRadius._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}

class ZpDurations {
  ZpDurations._();
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration page = Duration(milliseconds: 360);
}

class ZpTheme {
  ZpTheme._();

  static TextTheme textTheme() {
    final display = GoogleFonts.cinzelTextTheme();
    final body = GoogleFonts.interTextTheme();
    return TextTheme(
      displayLarge: display.displayLarge?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1.5),
      displayMedium: display.displayMedium?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      headlineLarge: display.headlineLarge?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1),
      headlineMedium: display.headlineMedium?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.8),
      headlineSmall: display.headlineSmall?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      titleLarge: body.titleLarge?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(color: ZpColors.textPrimary, fontWeight: FontWeight.w600),
      titleSmall: body.titleSmall?.copyWith(color: ZpColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.4),
      bodyLarge: body.bodyLarge?.copyWith(color: ZpColors.textPrimary),
      bodyMedium: body.bodyMedium?.copyWith(color: ZpColors.textSecondary),
      bodySmall: body.bodySmall?.copyWith(color: ZpColors.textMuted),
      labelLarge: body.labelLarge?.copyWith(color: ZpColors.obsidian, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      labelMedium: body.labelMedium?.copyWith(color: ZpColors.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      labelSmall: body.labelSmall?.copyWith(color: ZpColors.textMuted, letterSpacing: 0.8),
    );
  }

  static ThemeData dark() {
    final text = textTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ZpColors.obsidian,
      colorScheme: const ColorScheme.dark(
        primary: ZpColors.gold,
        onPrimary: ZpColors.obsidian,
        secondary: ZpColors.royalPurple,
        onSecondary: ZpColors.ivory,
        surface: ZpColors.panel,
        onSurface: ZpColors.textPrimary,
        error: ZpColors.danger,
      ),
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: ZpColors.divider,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.headlineSmall,
        iconTheme: const IconThemeData(color: ZpColors.gold),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: ZpColors.panel, surfaceTintColor: Colors.transparent),
      dialogTheme: const DialogThemeData(backgroundColor: ZpColors.panel, surfaceTintColor: Colors.transparent),
      snackBarTheme: SnackBarThemeData(backgroundColor: ZpColors.panelRaised, contentTextStyle: text.bodyLarge, behavior: SnackBarBehavior.floating),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZpColors.charcoal,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ZpRadius.md), borderSide: const BorderSide(color: ZpColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZpRadius.md), borderSide: const BorderSide(color: ZpColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ZpRadius.md), borderSide: const BorderSide(color: ZpColors.gold)),
        labelStyle: text.bodyMedium,
      ),
    );
  }
}
