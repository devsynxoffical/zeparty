import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/gift_model.dart';

class GiftAnimationOverlay extends StatefulWidget {
  const GiftAnimationOverlay({super.key});

  @override
  State<GiftAnimationOverlay> createState() => GiftAnimationOverlayState();
}

class GiftAnimationOverlayState extends State<GiftAnimationOverlay> with SingleTickerProviderStateMixin {
  GiftModel? _currentGift;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _opacityAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void playGiftAnimation(GiftModel gift) {
    _hideTimer?.cancel();
    setState(() {
      _currentGift = gift;
    });
    _animController.forward(from: 0.0);
    _hideTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _animController.reverse().then((_) {
          setState(() {
            _currentGift = null;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.getAccentGradient(isDark),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppColors.primaryGlow(isDark, alpha: 0.5, blur: 24, spread: 4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_currentGift!.icon, style: const TextStyle(fontSize: 48)),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'SPECIAL GIFT SENT!',
                            style: TextStyle(
                              color: AppColors.darkBackground,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            _currentGift!.name,
                            style: const TextStyle(
                              color: AppColors.darkBackground,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '${_currentGift!.diamondPrice} Diamonds 💎',
                            style: const TextStyle(
                              color: AppColors.darkBackground,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
