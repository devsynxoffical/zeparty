import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

class CoinFlipGameScreen extends StatefulWidget {
  final int wager;
  const CoinFlipGameScreen({super.key, required this.wager});

  @override
  State<CoinFlipGameScreen> createState() => _CoinFlipGameScreenState();
}

class _CoinFlipGameScreenState extends State<CoinFlipGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  String _chosenSide = 'Heads'; // 'Heads' or 'Tails'
  String _currentFace = '🪙';
  bool _isFlipping = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCoin() async {
    final gameProvider = context.read<GameProvider>();
    final walletProvider = context.read<WalletProvider>();

    final session = await gameProvider.startSession(
      walletProvider: walletProvider,
      gameId: 'coin_flip_double',
      gameType: 'Coin Flip',
      entryCoins: widget.wager,
    );

    if (session == null) return;

    setState(() {
      _isFlipping = true;
    });

    _flipController.forward(from: 0.0);

    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentFace = Random().nextBool() ? '👑' : '🦅';
      });
      if (!_flipController.isAnimating) {
        timer.cancel();
        final landedSide = Random().nextBool() ? 'Heads' : 'Tails';
        final won = _chosenSide == landedSide;
        final multiplier = won ? 2 : 0;

        setState(() {
          _currentFace = landedSide == 'Heads' ? '👑' : '🦅';
          _isFlipping = false;
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
        title: const Text('🪙 Double-or-Nothing Flip', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Pick Heads or Tails & Double Your Wager!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 36),

            // Animated Coin Widget
            RotationTransition(
              turns: Tween(begin: 0.0, end: 6.0).animate(
                CurvedAnimation(parent: _flipController, curve: Curves.easeOutCubic),
              ),
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: AppColors.getAccentGradient(isDark),
                  shape: BoxShape.circle,
                  boxShadow: AppColors.primaryGlow(isDark, alpha: 0.5, blur: 24),
                ),
                child: Center(
                  child: Text(
                    _currentFace,
                    style: const TextStyle(fontSize: 72),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Status message
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

            // Side Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['Heads', 'Tails'].map((side) {
                final isSelected = _chosenSide == side;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ChoiceChip(
                    avatar: Text(side == 'Heads' ? '👑' : '🦅'),
                    label: Text(side),
                    selected: isSelected,
                    selectedColor: AppColors.warmGold,
                    onSelected: _isFlipping
                        ? null
                        : (_) {
                            setState(() {
                              _chosenSide = side;
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
                onPressed: _isFlipping ? null : _flipCoin,
                child: Text(
                  _isFlipping ? 'Flipping Coin...' : 'Flip Coin (🪙 ${widget.wager})',
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
