import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_screen.dart';

class GameCenterSheet extends StatelessWidget {
  const GameCenterSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GameCenterSheet(),
    );
  }

  void _openGame(BuildContext context, String gameId, String gameName) {
    HapticFeedback.selectionClick();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          gameId: gameId,
          gameName: gameName,
          inRoom: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = [
      {
        'id': 'fishing',
        'name': 'Fishing',
        'subtitle': 'Arcade Shooter',
        'icon': '🎣',
        'color': const Color(0xFF00E5FF),
        'gradient': [const Color(0xFF0D253F), const Color(0xFF0072FF)],
      },
      {
        'id': 'football',
        'name': 'Football',
        'subtitle': 'Penalty Shootout',
        'icon': '⚽',
        'color': const Color(0xFF38EF7D),
        'gradient': [const Color(0xFF0F3820), const Color(0xFF11998E)],
      },
      {
        'id': 'fruit_match',
        'name': 'Fruit Match',
        'subtitle': 'Match-3 Puzzle',
        'icon': '🍓',
        'color': const Color(0xFFFF512F),
        'gradient': [const Color(0xFF2C1038), const Color(0xFFDD2476)],
      },
      {
        'id': 'rocket_challenge',
        'name': 'Rocket Challenge',
        'subtitle': 'Precision & Reflex',
        'icon': '🚀',
        'color': const Color(0xFF8E2DE2),
        'gradient': [const Color(0xFF1B0A33), const Color(0xFF4A00E0)],
      },
      {
        'id': 'lion_adventure',
        'name': 'Lion Adventure',
        'subtitle': '3-Lane Runner',
        'icon': '🦁',
        'color': const Color(0xFFFFB300),
        'gradient': [const Color(0xFF1E3C1B), const Color(0xFFF7971E)],
      },
      {
        'id': 'seven_puzzle',
        'name': 'Seven Puzzle',
        'subtitle': 'Number Merge',
        'icon': '🧩',
        'color': const Color(0xFFEAAFC8),
        'gradient': [const Color(0xFF200B3B), const Color(0xFF654EA3)],
      },
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF140824),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFFF2A6D), width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sports_esports, color: Color(0xFFFF2A6D), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Play Games in Room',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white60),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3x2 Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: games.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.94,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final game = games[index];
                final gradient = game['gradient'] as List<Color>;
                final color = game['color'] as Color;

                return GestureDetector(
                  onTap: () => _openGame(context, game['id'] as String, game['name'] as String),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(game['icon'] as String, style: const TextStyle(fontSize: 26)),
                        const SizedBox(height: 4),
                        Text(
                          game['name'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                        ),
                        Text(
                          game['subtitle'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: color, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
