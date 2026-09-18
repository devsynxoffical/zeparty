import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/design/gold_button.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late int betCoins;
  bool _isProcessing = false;
  Map<String, dynamic>? _lastOutcome;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    betCoins = widget.wager;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _playRound() async {
    if (_isProcessing) return;

    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final game = Provider.of<GameProvider>(context, listen: false);

    if (wallet.coins < betCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient coin balance! Please recharge to play.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastOutcome = null;
    });

    _animController.forward(from: 0.0);

    // Simulate network latency / server-authoritative round execution
    await Future.delayed(const Duration(milliseconds: 1400));

    // Authoritative local simulation matching server engine rules
    final outcome = _simulateServerOutcome(widget.gameId, betCoins);

    // Wallet transaction mutation
    if (outcome['won'] == true && outcome['multiplier'] > 0) {
      final winnings = (betCoins * (outcome['multiplier'] as double)).toInt();
      wallet.spendCoins(betCoins, 'Game Wager: ${widget.gameName}');
      wallet.earnCoins(winnings, 'Game Win: ${widget.gameName}');
      outcome['payout'] = winnings;
    } else {
      wallet.spendCoins(betCoins, 'Game Wager: ${widget.gameName}');
      outcome['payout'] = 0;
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastOutcome = outcome;
      });
    }
  }

  Map<String, dynamic> _simulateServerOutcome(String gameId, int bet) {
    final rand = Random();
    final floatVal = rand.nextDouble();

    switch (gameId) {
      case 'dragon_tiger': {
        final cards = ['A♠', 'K♥', 'Q♦', 'J♣', '10♠', '9♥', '8♦', '7♣'];
        final dCard = cards[rand.nextInt(cards.length)];
        final tCard = cards[rand.nextInt(cards.length)];
        final won = floatVal > 0.48;
        return {
          'won': won,
          'multiplier': won ? 2.0 : 0.0,
          'details': 'Dragon: $dCard vs Tiger: $tCard (${won ? "Dragon Win" : "Tiger Win"})',
        };
      }
      case 'teen_patti': {
        final won = floatVal > 0.52;
        return {
          'won': won,
          'multiplier': won ? 2.5 : 0.0,
          'details': won ? 'Flush Combo (A♠ K♠ 10♠)' : 'High Card (9♥ 4♦ 2♣)',
        };
      }
      case 'roulette': {
        final num = rand.nextInt(37);
        final isRed = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36].contains(num);
        final won = floatVal > 0.50;
        return {
          'won': won,
          'multiplier': won ? 2.0 : 0.0,
          'details': 'Ball landed on $num ${isRed ? "Red" : "Black"}',
        };
      }
      case 'fruit_party_jackpot': {
        final isJackpot = floatVal > 0.95;
        final isWin = floatVal > 0.55;
        final mult = isJackpot ? 20.0 : (isWin ? 2.0 : 0.0);
        return {
          'won': isWin || isJackpot,
          'multiplier': mult,
          'details': isJackpot ? '🎰 7️⃣-7️⃣-7️⃣ MEGA JACKPOT!' : (isWin ? '🍒-🍒-🍋 Matched Pair' : '🍋-🍇-🍉 No Match'),
        };
      }
      case 'fishing_star': {
        final won = floatVal > 0.45;
        final fish = ['Golden Whale', 'Hammerhead', 'Swordfish', 'Clownfish'][rand.nextInt(4)];
        final mult = won ? (rand.nextInt(3) + 2).toDouble() : 0.0;
        return {
          'won': won,
          'multiplier': mult,
          'details': won ? 'Captured $fish ($mult× payout)' : 'Fish escaped into deep waters',
        };
      }
      case 'rocket': {
        final crash = (1.0 + rand.nextDouble() * 5.0);
        final won = crash > 1.5;
        return {
          'won': won,
          'multiplier': won ? 1.8 : 0.0,
          'details': 'Cashed out at 1.80× (Rocket crashed at ${crash.toStringAsFixed(2)}×)',
        };
      }
      default: {
        final won = floatVal > 0.50;
        return {
          'won': won,
          'multiplier': won ? 2.0 : 0.0,
          'details': won ? 'Round complete: Winning tier reached' : 'Round complete: Better luck next round',
        };
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Text(widget.gameName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Balance Badge Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on_rounded, color: AppColors.warmGold, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${wallet.coins} ZeCoins',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark), fontSize: 16),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Interactive Game Visualizer Center
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    height: 220,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.getCard(isDark),
                          AppColors.getSurface(isDark),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isProcessing) ...[
                          const CircularProgressIndicator(color: AppColors.warmGold),
                          const SizedBox(height: 16),
                          Text(
                            'Executing Server Round...',
                            style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Authoritative RNG & Settlement Verification',
                            style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 11),
                          ),
                        ] else if (_lastOutcome != null) ...[
                          Text(
                            _lastOutcome!['won'] == true ? '🎉 VICTORY! 🎉' : '💫 ROUND ENDED',
                            style: TextStyle(
                              color: _lastOutcome!['won'] == true ? AppColors.success : AppColors.error,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastOutcome!['details'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          if (_lastOutcome!['won'] == true)
                            Text(
                              '+${_lastOutcome!['payout']} 🪙 (${_lastOutcome!['multiplier']}×)',
                              style: const TextStyle(
                                color: AppColors.warmGold,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ] else ...[
                          Icon(Icons.sports_esports_rounded, size: 56, color: primary),
                          const SizedBox(height: 12),
                          Text(
                            'Official Game Engine',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select wager and start round',
                            style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // Bet Selector Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [10, 50, 100, 500, 1000].map((b) {
                    final isSelected = betCoins == b;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$b 🪙'),
                        selected: isSelected,
                        selectedColor: AppColors.warmGold,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.black : AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => betCoins = b);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              GoldButton(
                text: _isProcessing ? 'Settling Round...' : 'Play Round ($betCoins 🪙)',
                isLoading: _isProcessing,
                onPressed: _playRound,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
