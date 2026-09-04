import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

class DiceGameScreen extends StatefulWidget {
  final int wager;
  const DiceGameScreen({super.key, required this.wager});

  @override
  State<DiceGameScreen> createState() => _DiceGameScreenState();
}

class _DiceGameScreenState extends State<DiceGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _diceVal = 1;
  bool _isRolling = false;
  int _selectedTarget = 4; // Predict 4, 5 or 6 to win

  @override
  void initState() {
    super.initState();
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

  void _rollDice() async {
    final gameProvider = context.read<GameProvider>();
    final walletProvider = context.read<WalletProvider>();

    final session = await gameProvider.startSession(
      walletProvider: walletProvider,
      gameId: 'dice_lucky_roll',
      gameType: 'Dice Roll',
      entryCoins: widget.wager,
    );

    if (session == null) return;

    setState(() {
      _isRolling = true;
    });

    _animController.forward(from: 0.0);

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _diceVal = Random().nextInt(6) + 1;
      });
      if (!_animController.isAnimating) {
        timer.cancel();
        final finalVal = Random().nextInt(6) + 1;
        final won = finalVal >= _selectedTarget;
        final multiplier = won ? 2 : 0;

        setState(() {
          _diceVal = finalVal;
          _isRolling = false;
        });

        gameProvider.completeSession(
          walletProvider: walletProvider,
          multiplier: multiplier,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final gameProvider = context.watch<GameProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('🎲 Lucky Dice Roll', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Predict High Roll (≥ $_selectedTarget) to Win 2x Coins!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 32),

            // Animated Dice Container
            RotationTransition(
              turns: Tween(begin: 0.0, end: 4.0).animate(
                CurvedAnimation(parent: _animController, curve: Curves.easeInOutBack),
              ),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  gradient: AppColors.getAccentGradient(isDark),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppColors.primaryGlow(isDark, alpha: 0.4, blur: 20),
                ),
                child: Center(
                  child: Text(
                    '$_diceVal',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onPrimary(isDark: isDark),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Status / Result message
            Text(
              gameProvider.gameMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.warmGold,
              ),
            ),

            const SizedBox(height: 40),

            // Target selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [3, 4, 5].map((target) {
                final isSelected = _selectedTarget == target;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text('Roll ≥ $target'),
                    selected: isSelected,
                    selectedColor: AppColors.warmGold,
                    onSelected: _isRolling
                        ? null
                        : (_) {
                            setState(() {
                              _selectedTarget = target;
                            });
                          },
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmGold,
                  foregroundColor: AppColors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isRolling ? null : _rollDice,
                child: Text(
                  _isRolling ? 'Rolling...' : 'Roll Dice (🪙 ${widget.wager})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
