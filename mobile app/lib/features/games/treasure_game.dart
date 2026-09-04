import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class TreasureGameWidget extends StatefulWidget {
  final bool isPlaying;
  final Function(int coinsWon) onChestOpened;

  const TreasureGameWidget({
    super.key,
    required this.isPlaying,
    required this.onChestOpened,
  });

  @override
  State<TreasureGameWidget> createState() => _TreasureGameWidgetState();
}

class _TreasureGameWidgetState extends State<TreasureGameWidget> {
  final List<bool> _opened = [false, false, false];
  final List<int> _rewards = [0, 0, 0];

  void _openChest(int index) {
    if (_opened[index] || widget.isPlaying) return;

    final rand = Random();
    final coins = (rand.nextInt(5) + 1) * 200;

    setState(() {
      _opened[index] = true;
      _rewards[index] = coins;
    });

    widget.onChestOpened(coins);
  }

  void reset() {
    setState(() {
      _opened[0] = false;
      _opened[1] = false;
      _opened[2] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (index) {
            final isOpened = _opened[index];
            final prize = _rewards[index];

            return GestureDetector(
              onTap: () => _openChest(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 90,
                height: 110,
                decoration: BoxDecoration(
                  gradient: isOpened ? AppColors.getPremiumGradient(isDark) : AppColors.getAccentGradient(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorderStrong(isDark), width: 2),
                  boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isOpened ? '🎉' : '📦',
                      style: const TextStyle(fontSize: 36),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isOpened ? '+$prize 🪙' : 'Tap Open',
                      style: TextStyle(
                        color: onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
