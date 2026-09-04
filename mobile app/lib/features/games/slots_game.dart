import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class SlotsGameWidget extends StatefulWidget {
  final bool isPlaying;
  final Function(int winAmount) onFinished;

  const SlotsGameWidget({
    super.key,
    required this.isPlaying,
    required this.onFinished,
  });

  @override
  State<SlotsGameWidget> createState() => _SlotsGameWidgetState();
}

class _SlotsGameWidgetState extends State<SlotsGameWidget> {
  final List<String> _symbols = ['🍒', '🍋', '🍇', '💎', '🔔', '7️⃣'];
  String _reel1 = '💎';
  String _reel2 = '💎';
  String _reel3 = '💎';
  Timer? _timer;

  @override
  void didUpdateWidget(covariant SlotsGameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _startSpinning();
    }
  }

  void _startSpinning() {
    int ticks = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final rand = Random();
      setState(() {
        _reel1 = _symbols[rand.nextInt(_symbols.length)];
        _reel2 = _symbols[rand.nextInt(_symbols.length)];
        _reel3 = _symbols[rand.nextInt(_symbols.length)];
      });
      ticks++;
      if (ticks > 25) {
        t.cancel();
        int win = 0;
        if (_reel1 == _reel2 && _reel2 == _reel3) {
          win = _reel1 == '7️⃣' ? 1000 : 500;
        } else if (_reel1 == _reel2 || _reel2 == _reel3 || _reel1 == _reel3) {
          win = 100;
        }
        widget.onFinished(win);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderStrong(isDark), width: 3),
        boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildReel(_reel1),
          _buildReel(_reel2),
          _buildReel(_reel3),
        ],
      ),
    );
  }

  Widget _buildReel(String symbol) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 70,
      height: 90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderStrong(isDark)),
      ),
      child: Center(
        child: Text(
          symbol,
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}
