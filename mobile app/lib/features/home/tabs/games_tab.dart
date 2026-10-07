import 'package:flutter/material.dart';
import '../../games/game_lobby_screen.dart';

class GamesTab extends StatelessWidget {
  final bool isDark;

  const GamesTab({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return const GameLobbyScreen();
  }
}
