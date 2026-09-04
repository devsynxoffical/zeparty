import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Light Mode Theme — Clean White & Royal Blue Theme.
/// Pure white surfaces, light blue highlights, and royal blue accents.
class LightTheme {
  LightTheme._();

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    brightness: Brightness.light,
    primaryColor: AppColors.royalBlue,
    scaffoldBackgroundColor: AppColors.lightBackground,
    canvasColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.royalBlue,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.lightBlue,
      onPrimaryContainer: AppColors.deepRoyalBlue,
      secondary: AppColors.deepRoyalBlue,
      onSecondary: AppColors.white,
      tertiary: AppColors.cyan,
      onTertiary: AppColors.white,
      surface: AppColors.lightCard,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainer: AppColors.lightSurface,
      surfaceContainerHigh: AppColors.lightSurface,
      surfaceContainerHighest: AppColors.lightSurface,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightBorder,
      error: AppColors.liveRed,
      onError: AppColors.white,
      shadow: Color(0x200D47A1),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.lightTextPrimary),
      titleTextStyle: TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightCard,
      selectedItemColor: AppColors.royalBlue,
      unselectedItemColor: AppColors.lightMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightCard,
      hintStyle: const TextStyle(color: AppColors.lightMuted, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.royalBlue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.liveRed),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.royalBlue,
      selectionColor: Color(0x401976D2),
      selectionHandleColor: AppColors.royalBlue,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightCard,
      elevation: 8,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightCard,
      modalBackgroundColor: AppColors.lightCard,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: AppColors.lightBorder),
      ),
      dragHandleColor: AppColors.lightMuted,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.royalBlue,
      unselectedLabelColor: AppColors.lightTextSecondary,
      indicatorColor: AppColors.royalBlue,
      dividerColor: AppColors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedColor: AppColors.lightBlue,
      side: const BorderSide(color: AppColors.lightBorder),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
      secondaryLabelStyle: const TextStyle(color: AppColors.royalBlue),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.royalBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.royalBlue,
        side: const BorderSide(color: AppColors.royalBlue, width: 1.2),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.royalBlue,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    dividerColor: AppColors.lightBorder,
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 24, color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.4),
        displayMedium: TextStyle(fontSize: 20, color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        displaySmall: TextStyle(fontSize: 17, color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        headlineLarge: TextStyle(fontSize: 18, color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 16, color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        headlineSmall: TextStyle(fontSize: 14.5, color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 15.5, color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 13.5, color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 12.5, color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 13.5, color: AppColors.lightTextPrimary, height: 1.3),
        bodyMedium: TextStyle(fontSize: 12, color: AppColors.lightTextSecondary, height: 1.3),
        bodySmall: TextStyle(fontSize: 10.5, color: AppColors.lightMuted, height: 1.2),
        labelLarge: TextStyle(fontSize: 12.5, color: AppColors.royalBlue, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 11, color: AppColors.lightTextSecondary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 9.5, color: AppColors.lightMuted),
      ),
    ),
  );
}
