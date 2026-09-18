import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../games/game_lobby_screen.dart';
import '../../games/game_screen.dart';

class GamesTab extends StatelessWidget {
  final bool isDark;

  const GamesTab({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final games = [
      {'id': 'fishing_star', 'title': 'Fishing Star', 'icon': Icons.phishing_rounded, 'color': Colors.cyanAccent, 'screen': const GameScreen(gameId: 'fishing_star', gameName: 'Fishing Star')},
      {'id': 'teen_patti', 'title': 'Teen Patti', 'icon': Icons.style_rounded, 'color': Colors.amber, 'screen': const GameScreen(gameId: 'teen_patti', gameName: 'Teen Patti')},
      {'id': 'dragon_tiger', 'title': 'Dragon & Tiger', 'icon': Icons.compare_arrows_rounded, 'color': Colors.redAccent, 'screen': const GameScreen(gameId: 'dragon_tiger', gameName: 'Dragon & Tiger')},
      {'id': 'roulette', 'title': 'Roulette', 'icon': Icons.data_usage_rounded, 'color': Colors.greenAccent, 'screen': const GameScreen(gameId: 'roulette', gameName: 'Roulette')},
      {'id': 'fruit_party_jackpot', 'title': 'Fruit Party Jackpot', 'icon': Icons.casino_rounded, 'color': Colors.pinkAccent, 'screen': const GameScreen(gameId: 'fruit_party_jackpot', gameName: 'Fruit Party Jackpot')},
      {'id': 'rocket', 'title': 'Rocket', 'icon': Icons.rocket_launch_rounded, 'color': Colors.purpleAccent, 'screen': const GameScreen(gameId: 'rocket', gameName: 'Rocket')},
      {'id': 'delicious', 'title': 'Delicious', 'icon': Icons.cake_rounded, 'color': Colors.orangeAccent, 'screen': const GameScreen(gameId: 'delicious', gameName: 'Delicious')},
      {'id': 'bounty_football', 'title': 'Bounty Football', 'icon': Icons.sports_soccer_rounded, 'color': Colors.blueAccent, 'screen': const GameScreen(gameId: 'bounty_football', gameName: 'Bounty Football')},
      {'id': 'greedy_lion', 'title': 'Greedy Lion', 'icon': Icons.pets_rounded, 'color': Colors.amberAccent, 'screen': const GameScreen(gameId: 'greedy_lion', gameName: 'Greedy Lion')},
      {'id': 'double_seven_77', 'title': 'Double Seven (77)', 'icon': Icons.looks_two_rounded, 'color': Colors.tealAccent, 'screen': const GameScreen(gameId: 'double_seven_77', gameName: 'Double Seven (77)')},
    ];

    final primary = AppColors.getPrimary(isDark);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Official ZeParty Games (10)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GameLobbyScreen()),
                ),
                child: Text(
                  'Full Lobby',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1.sw > 900 ? 5 : (1.sw > 600 ? 3 : 2),
              childAspectRatio: 1.1,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              final color = game['color'] as Color;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => game['screen'] as Widget),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(game['icon'] as IconData, size: 32, color: color),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        game['title'] as String,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
