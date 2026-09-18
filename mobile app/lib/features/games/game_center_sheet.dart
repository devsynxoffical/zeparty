import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import 'rocket_game_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();

    final games = [
      {
        'id': 'rocket',
        'title': 'Rocket',
        'subtitle': 'Crash Multiplier',
        'icon': '🚀',
        'color': Colors.purpleAccent,
        'onTap': () {
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const RocketGameSheet(),
          );
        },
      },
      {
        'id': 'fishing_star',
        'title': 'Fishing Star',
        'subtitle': 'Arcade Fishing',
        'icon': '🎣',
        'color': Colors.cyanAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'fishing_star', 'Fishing Star');
        },
      },
      {
        'id': 'teen_patti',
        'title': 'Teen Patti',
        'subtitle': '3-Card Poker',
        'icon': '🃏',
        'color': Colors.amber,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'teen_patti', 'Teen Patti');
        },
      },
      {
        'id': 'dragon_tiger',
        'title': 'Dragon & Tiger',
        'subtitle': '2-Card Table',
        'icon': '🐉',
        'color': Colors.redAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'dragon_tiger', 'Dragon & Tiger');
        },
      },
      {
        'id': 'roulette',
        'title': 'Roulette',
        'subtitle': 'European Wheel',
        'icon': '🎡',
        'color': Colors.greenAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'roulette', 'Roulette');
        },
      },
      {
        'id': 'fruit_party_jackpot',
        'title': 'Fruit Party Jackpot',
        'subtitle': 'Hit 50x 777',
        'icon': '🎰',
        'color': Colors.pinkAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'fruit_party_jackpot', 'Fruit Party Jackpot');
        },
      },
      {
        'id': 'delicious',
        'title': 'Delicious',
        'subtitle': 'Culinary Arcade',
        'icon': '🍰',
        'color': Colors.orangeAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'delicious', 'Delicious');
        },
      },
      {
        'id': 'bounty_football',
        'title': 'Bounty Football',
        'subtitle': 'Penalty Challenge',
        'icon': '⚽',
        'color': Colors.blueAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'bounty_football', 'Bounty Football');
        },
      },
      {
        'id': 'greedy_lion',
        'title': 'Greedy Lion',
        'subtitle': 'Animal Multiplier',
        'icon': '🦁',
        'color': Colors.amberAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'greedy_lion', 'Greedy Lion');
        },
      },
      {
        'id': 'double_seven_77',
        'title': 'Double Seven (77)',
        'subtitle': 'Lucky 77 Match',
        'icon': '7️⃣',
        'color': Colors.tealAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'double_seven_77', 'Double Seven (77)');
        },
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1929),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),

              // Header Row with Balance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🎮 Official Live Games', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${wallet.coins} 🪙',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Playable Games Grid
              SizedBox(
                height: 320,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: games.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final color = game['color'] as Color;
                    return GestureDetector(
                      onTap: game['onTap'] as VoidCallback,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.25),
                              const Color(0xFF28243D),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Text(game['icon'] as String, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    game['title'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    game['subtitle'] as String,
                                    style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  static void _openGameScreen(BuildContext context, String gameId, String gameName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameId: gameId, gameName: gameName),
      ),
    );
  }
}
