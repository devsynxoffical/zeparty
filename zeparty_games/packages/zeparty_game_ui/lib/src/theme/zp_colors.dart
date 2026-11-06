import 'package:flutter/material.dart';

/// ZeParty brand palette (gold on black, mirrors the host app's AppColors) extended with the royal game accents.
class ZpColors {
  ZpColors._();

  static const Color obsidian = Color(0xFF080808); // AppColors.black
  static const Color charcoal = Color(0xFF0D0D0D); // AppColors.darkBlack
  static const Color panel = Color(0xFF141414); // AppColors.cardBlack
  static const Color panelRaised = Color(0xFF1B1B1B); // AppColors.softBlack
  static const Color divider = Color(0xFF3A2E14); // AppColors.borderGold

  static const Color gold = Color(0xFFCF9828); // AppColors.metallicGold
  static const Color goldLight = Color(0xFFE7C55F); // AppColors.warmGold
  static const Color goldDeep = Color(0xFF8C601C); // AppColors.deepBronze
  static const Color champagne = Color(0xFFF4D982); // AppColors.lightGold
  static const Color ivory = Color(0xFFFFFFFF); // AppColors.primaryText

  static const Color royalPurple = Color(0xFF3B1E63);
  static const Color royalPurpleDeep = Color(0xFF22113C);
  static const Color ruby = Color(0xFFC0213A);
  static const Color emerald = Color(0xFF1E8C5A);
  static const Color amber = Color(0xFFF2B01E);
  static const Color sapphire = Color(0xFF2650C8);

  static const Color textPrimary = ivory;
  static const Color textSecondary = Color(0xFFB8B8B8); // AppColors.secondaryText
  static const Color textMuted = Color(0xFF8A8A8A); // AppColors.mutedText, lifted for contrast on black
  static const Color success = Color(0xFF3DBE7A);
  static const Color danger = Color(0xFFE24B5C);
  static const Color info = Color(0xFF5B7CFF);

  static Color seat(int seat) => switch (seat % 4) { 0 => ruby, 1 => emerald, 2 => amber, _ => sapphire };

  static Color forLudoColor(String name) => switch (name) {
        'red' => ruby,
        'green' => emerald,
        'yellow' => amber,
        'blue' => sapphire,
        _ => gold,
      };

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [panelRaised, panel],
  );

  static const LinearGradient backdrop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1030), obsidian],
  );
}
