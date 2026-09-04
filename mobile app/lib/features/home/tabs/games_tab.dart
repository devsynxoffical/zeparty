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
      {'title': 'Wheel of Fortune', 'icon': Icons.data_usage_rounded, 'color': Colors.amber, 'screen': const GameScreen(gameName: 'Wheel of Fortune')},
      {'title': 'Lucky Fruit Slots', 'icon': Icons.casino_rounded, 'color': Colors.purpleAccent, 'screen': const GameScreen(gameName: 'Lucky Fruit Slots')},
      {'title': 'Treasure Box', 'icon': Icons.card_giftcard_rounded, 'color': Colors.blueAccent, 'screen': const GameScreen(gameName: 'Treasure Box')},
      {'title': 'Lucky Dice Roll', 'icon': Icons.extension_rounded, 'color': Colors.greenAccent, 'screen': const GameScreen(gameName: 'Lucky Dice Roll')},
      {'title': 'Coin Flip Double', 'icon': Icons.monetization_on_rounded, 'color': Colors.orangeAccent, 'screen': const GameScreen(gameName: 'Coin Flip Double')},
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
                'Trending Games',
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
                  'Lobby',
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
                        child: Icon(game['icon'] as IconData, size: 36, color: color),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        game['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
