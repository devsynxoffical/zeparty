import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import 'views/rocket_crash_view.dart';
import 'views/dragon_tiger_view.dart';
import 'views/fruit_party_view.dart';
import 'views/teen_patti_view.dart';
import 'views/roulette_view.dart';
import 'views/greedy_lion_view.dart';
import 'views/bounty_football_view.dart';
import 'views/fishing_star_view.dart';
import 'views/double_seven_view.dart';
import 'views/delicious_view.dart';

class GameScreen extends StatefulWidget {
  final String gameId;
  final String gameName;
  final int wager;

  const GameScreen({
    super.key,
    this.gameId = 'fishing_star',
    required this.gameName,
    this.wager = 50,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    Widget gameBody;
    switch (widget.gameId) {
      case 'rocket':
        gameBody = RocketCrashView(wager: widget.wager);
        break;
      case 'dragon_tiger':
        gameBody = DragonTigerView(wager: widget.wager);
        break;
      case 'fruit_party_jackpot':
        gameBody = FruitPartyView(wager: widget.wager);
        break;
      case 'teen_patti':
        gameBody = TeenPattiView(wager: widget.wager);
        break;
      case 'roulette':
        gameBody = RouletteView(wager: widget.wager);
        break;
      case 'greedy_lion':
        gameBody = GreedyLionView(wager: widget.wager);
        break;
      case 'bounty_football':
        gameBody = BountyFootballView(wager: widget.wager);
        break;
      case 'fishing_star':
        gameBody = FishingStarView(wager: widget.wager);
        break;
      case 'double_seven_77':
        gameBody = DoubleSevenView(wager: widget.wager);
        break;
      case 'delicious':
        gameBody = DeliciousView(wager: widget.wager);
        break;
      default:
        gameBody = RocketCrashView(wager: widget.wager);
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: AppColors.warmGold, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${wallet.coins}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(child: gameBody),
    );
  }
}
