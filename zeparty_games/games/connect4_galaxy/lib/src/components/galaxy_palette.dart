import 'package:flutter/material.dart';
import 'package:zeparty_game_ui/zeparty_game_ui.dart';

/// Colour vocabulary of the Galactic Strategy Chamber. Seat colours follow the
/// product brief (seat 0 blue, seat 1 gold); the rest is derived to sit on the
/// shared ZeParty dark theme.
class GalaxyPalette {
  GalaxyPalette._();

  static const Color blue = Color(0xFF5B7CFF);
  static const Color blueLight = Color(0xFF9DB1FF);
  static const Color blueDeep = Color(0xFF2338A8);
  static const Color gold = ZpColors.gold; // #C9A227
  static const Color goldLight = ZpColors.goldLight;
  static const Color goldDeep = ZpColors.goldDeep;

  static const Color spaceTop = Color(0xFF05060F);
  static const Color spaceMid = Color(0xFF0B0D22);
  static const Color spaceBottom = Color(0xFF120A24);
  static const Color nebulaViolet = Color(0xFF6A3BC9);
  static const Color nebulaBlue = Color(0xFF2E5BFF);
  static const Color nebulaTeal = Color(0xFF19B6C9);
  static const Color nebulaRose = Color(0xFFC94B8A);
  static const Color starWarm = Color(0xFFFFE2B0);
  static const Color starCool = Color(0xFFBFD4FF);

  static const Color crystal = Color(0xFFCFE3FF);
  static const Color crystalEdge = Color(0xFF8FB4FF);
  static const Color metalLight = Color(0xFFDDE6F5);
  static const Color metalMid = Color(0xFF7D8AA6);
  static const Color metalDark = Color(0xFF2A3043);

  static Color seat(int seat) => seat == 0 ? blue : gold;
  static Color seatLight(int seat) => seat == 0 ? blueLight : goldLight;
  static Color seatDeep(int seat) => seat == 0 ? blueDeep : goldDeep;
}
