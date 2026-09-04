import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SpinWheelGameWidget extends StatefulWidget {
  final bool isSpinning;
  final double winMultiplier;
  final VoidCallback onSpin;

  const SpinWheelGameWidget({
    super.key,
    required this.isSpinning,
    required this.winMultiplier,
    required this.onSpin,
  });

  @override
  State<SpinWheelGameWidget> createState() => _SpinWheelGameWidgetState();
}

class _SpinWheelGameWidgetState extends State<SpinWheelGameWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void didUpdateWidget(covariant SpinWheelGameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning && !oldWidget.isSpinning) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final angle = _animation.value * (pi * 12);
                return Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.getAccentGradient(isDark),
                      boxShadow: AppColors.primaryGlow(isDark, alpha: 0.5, blur: 20, spread: 4),
                      border: Border.all(color: AppColors.getBorderStrong(isDark), width: 4),
                    ),
                    child: Stack(
                      children: [
                        for (int i = 0; i < 6; i++)
                          Transform.rotate(
                            angle: (i * pi / 3),
                            child: const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(top: 20),
                                child: Text('💎', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Icon(Icons.arrow_drop_down_circle_rounded, color: primary, size: 44),
          ],
        ),
      ],
    );
  }
}
