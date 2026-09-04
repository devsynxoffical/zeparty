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
        'title': 'Rocket Crash',
        'subtitle': 'Bet & Win 2000x',
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
        'title': 'Wheel of Fortune',
        'subtitle': 'Spin up to 20x',
        'icon': '🎡',
        'color': Colors.amber,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'Wheel of Fortune');
        },
      },
      {
        'title': 'Lucky Dice Roll',
        'subtitle': 'Predict High Roll',
        'icon': '🎲',
        'color': Colors.cyanAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'Lucky Dice Roll');
        },
      },
      {
        'title': 'Fruit Slots',
        'subtitle': 'Hit 3x Jackpot',
        'icon': '🎰',
        'color': Colors.pinkAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'Lucky Fruit Slots');
        },
      },
      {
        'title': 'Coin Flip',
        'subtitle': 'Double Your Coins',
        'icon': '🪙',
        'color': Colors.orangeAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'Coin Flip Double');
        },
      },
      {
        'title': 'Treasure Box',
        'subtitle': 'Open Mystery Box',
        'icon': '📦',
        'color': Colors.greenAccent,
        'onTap': () {
          Navigator.pop(context);
          _openGameScreen(context, 'Treasure Box Mystery');
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
                  Row(
                    children: const [
                      Text('🎮 Live Game Center', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: games.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.1,
                ),
                itemBuilder: (context, index) {
                  final game = games[index];
                  return GestureDetector(
                    onTap: game['onTap'] as VoidCallback,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            (game['color'] as Color).withValues(alpha: 0.25),
                            const Color(0xFF28243D),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: (game['color'] as Color).withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Text(game['icon'] as String, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  game['title'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  game['subtitle'] as String,
                                  style: TextStyle(color: (game['color'] as Color), fontSize: 10, fontWeight: FontWeight.w600),
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
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  static void _openGameScreen(BuildContext context, String gameName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(gameName: gameName),
      ),
    );
  }
}
