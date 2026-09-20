import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Luxury Dark Gold theme — the definitive ZeParty "GoldLive" look.
/// Black surfaces, metallic gold accents, deep bronze borders.
class DarkTheme {
  DarkTheme._();

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.poppins().fontFamily,
    brightness: Brightness.dark,
    visualDensity: VisualDensity.standard,
    primaryColor: AppColors.warmGold,
    scaffoldBackgroundColor: AppColors.black,
    canvasColor: AppColors.black,
    splashFactory: InkSparkle.splashFactory,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.warmGold,
      onPrimary: AppColors.black,
      primaryContainer: AppColors.deepBronze,
      onPrimaryContainer: AppColors.goldHighlight,
      secondary: AppColors.metallicGold,
      onSecondary: AppColors.black,
      secondaryContainer: AppColors.deepBronze,
      onSecondaryContainer: AppColors.lightGold,
      tertiary: AppColors.lightGold,
      onTertiary: AppColors.black,
      surface: AppColors.cardBlack,
      onSurface: AppColors.primaryText,
      surfaceContainer: AppColors.softBlack,
      surfaceContainerHigh: AppColors.softBlack,
      surfaceContainerHighest: AppColors.softBlack,
      surfaceContainerLow: AppColors.cardBlack,
      surfaceContainerLowest: AppColors.black,
      onSurfaceVariant: AppColors.secondaryText,
      outline: AppColors.borderGold,
      outlineVariant: AppColors.borderGold,
      error: AppColors.liveRed,
      onError: AppColors.white,
      shadow: Colors.black,
    ),
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      color: AppColors.cardBlack,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.borderGold, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.warmGold,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: AppColors.warmGold),
      actionsIconTheme: IconThemeData(color: AppColors.lightGold),
      titleTextStyle: TextStyle(
        color: AppColors.warmGold,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.black,
      selectedItemColor: AppColors.warmGold,
      unselectedItemColor: AppColors.mutedText,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.cardBlack,
      hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 14),
      labelStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
      prefixIconColor: AppColors.mutedText,
      suffixIconColor: AppColors.mutedText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderGold, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.borderGold, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.warmGold, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.liveRed, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.liveRed, width: 1.4),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.warmGold,
      selectionColor: Color(0x40CF9828),
      selectionHandleColor: AppColors.warmGold,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkBlack,
      elevation: 10,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.goldBorder, width: 1),
      ),
      titleTextStyle: const TextStyle(
        color: AppColors.warmGold,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkBlack,
      modalBackgroundColor: AppColors.darkBlack,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        side: BorderSide(color: AppColors.goldBorder, width: 1),
      ),
      dragHandleColor: AppColors.goldBorder,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.borderGold,
      thickness: 1,
    ),
    dividerColor: AppColors.borderGold,
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.warmGold,
      unselectedLabelColor: AppColors.secondaryText,
      indicatorColor: AppColors.warmGold,
      dividerColor: AppColors.transparent,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.softBlack,
      selectedColor: AppColors.deepBronze,
      side: const BorderSide(color: AppColors.borderGold),
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      secondaryLabelStyle: const TextStyle(color: AppColors.warmGold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.lightGold : AppColors.mutedText),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.deepBronze
              : AppColors.softBlack),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? AppColors.goldBorder
              : AppColors.borderGold),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.warmGold,
      inactiveTrackColor: AppColors.softBlack,
      thumbColor: AppColors.lightGold,
      overlayColor: AppColors.metallicGold.withValues(alpha: 0.2),
      trackHeight: 4,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.warmGold : AppColors.softBlack),
      checkColor: WidgetStateProperty.all(AppColors.black),
      side: const BorderSide(color: AppColors.goldBorder),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.warmGold : AppColors.mutedText),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.warmGold,
      linearTrackColor: AppColors.softBlack,
      circularTrackColor: AppColors.softBlack,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkBlack,
      contentTextStyle: const TextStyle(color: AppColors.primaryText),
      actionTextColor: AppColors.warmGold,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.primaryText,
      iconColor: AppColors.warmGold,
      subtitleTextStyle: TextStyle(color: AppColors.secondaryText),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.darkBlack,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.goldBorder),
      ),
      textStyle: const TextStyle(color: AppColors.primaryText, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.warmGold,
        foregroundColor: AppColors.black,
        elevation: 0,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.warmGold,
        side: const BorderSide(color: AppColors.goldBorder, width: 1.2),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.warmGold,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.warmGold,
      foregroundColor: AppColors.black,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.darkBlack,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.goldBorder),
      ),
      textStyle: const TextStyle(color: AppColors.primaryText, fontSize: 12),
    ),
    splashColor: AppColors.metallicGold.withValues(alpha: 0.12),
    highlightColor: AppColors.metallicGold.withValues(alpha: 0.06),
    hoverColor: AppColors.metallicGold.withValues(alpha: 0.08),
    textTheme: GoogleFonts.poppinsTextTheme(
      const TextTheme(
        displayLarge: TextStyle(fontSize: 24, color: AppColors.lightGold, fontWeight: FontWeight.bold, letterSpacing: -0.4),
        displayMedium: TextStyle(fontSize: 20, color: AppColors.lightGold, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        displaySmall: TextStyle(fontSize: 17, color: AppColors.warmGold, fontWeight: FontWeight.bold, letterSpacing: -0.2),
        headlineLarge: TextStyle(fontSize: 18, color: AppColors.warmGold, fontWeight: FontWeight.bold, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 16, color: AppColors.warmGold, fontWeight: FontWeight.w600, letterSpacing: -0.2),
        headlineSmall: TextStyle(fontSize: 14.5, color: AppColors.warmGold, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 15.5, color: AppColors.warmGold, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 13.5, color: AppColors.primaryText, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 12.5, color: AppColors.primaryText, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 13.5, color: AppColors.primaryText, height: 1.3),
        bodyMedium: TextStyle(fontSize: 12, color: AppColors.secondaryText, height: 1.3),
        bodySmall: TextStyle(fontSize: 10.5, color: AppColors.mutedText, height: 1.2),
        labelLarge: TextStyle(fontSize: 12.5, color: AppColors.warmGold, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 9.5, color: AppColors.mutedText),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
