import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/design/gold_button.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';
import 'spin_wheel_game.dart';
import 'slots_game.dart';
import 'treasure_game.dart';
import 'dice_game.dart';
import 'coin_flip_game.dart';

class GameScreen extends StatefulWidget {
  final String gameName;
  final int wager;
  const GameScreen({super.key, required this.gameName, this.wager = 100});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int betCoins;

  @override
  void initState() {
    super.initState();
    betCoins = widget.wager;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.gameName == 'Lucky Dice Roll') {
      return DiceGameScreen(wager: widget.wager);
    } else if (widget.gameName == 'Coin Flip Double') {
      return CoinFlipGameScreen(wager: widget.wager);
    }

    final game = context.watch<GameProvider>();
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.gameName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Balance Badge Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(isDark).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: AppColors.getPrimary(isDark), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      '${wallet.coins} ZeCoins',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark), fontSize: 16),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Game Widget Switcher
              // Game Widget Switcher
              if (widget.gameName == 'Wheel of Fortune')
                SpinWheelGameWidget(
                  isSpinning: game.isPlaying,
                  winMultiplier: 2.0,
                  onSpin: () {},
                )
              else if (widget.gameName == 'Lucky Fruit Slots')
                SlotsGameWidget(
                  isPlaying: game.isPlaying,
                  onFinished: (winAmount) {
                    if (game.activeSession != null) {
                      final mult = winAmount > 0 ? (winAmount ~/ betCoins).clamp(1, 10) : 0;
                      game.completeSession(walletProvider: wallet, multiplier: mult);
                    }
                  },
                )
              else
                TreasureGameWidget(
                  isPlaying: game.isPlaying,
                  onChestOpened: (wonCoins) {
                    final mult = wonCoins > 0 ? (wonCoins ~/ betCoins).clamp(1, 10) : 0;
                    if (game.activeSession != null) {
                      game.completeSession(walletProvider: wallet, multiplier: mult);
                    } else {
                      wallet.earnCoins(wonCoins, 'Treasure Box Surprise');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🎉 Won $wonCoins ZeCoins from Treasure Box!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              Text(
                game.gameMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const Spacer(),

              // Bet Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [50, 100, 500, 1000].map((b) {
                    final isSelected = betCoins == b;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$b 🪙'),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(color: isSelected ? AppColors.black : null),
                        onSelected: (val) {
                          if (val) setState(() => betCoins = b);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              GoldButton(
                text: game.isPlaying ? 'Playing Game...' : 'Play Now ($betCoins 🪙)',
                isLoading: game.isPlaying,
                onPressed: () async {
                  final session = await game.startSession(
                    walletProvider: wallet,
                    gameId: widget.gameName.toLowerCase().replaceAll(' ', '_'),
                    gameType: widget.gameName,
                    entryCoins: betCoins,
                  );
                  if (session != null) {
                    if (widget.gameName == 'Wheel of Fortune') {
                      Future.delayed(const Duration(milliseconds: 2500), () {
                        if (mounted) {
                          final won = (Random().nextInt(100) > 40);
                          game.completeSession(walletProvider: wallet, multiplier: won ? 2 : 0);
                        }
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

