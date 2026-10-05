import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/wallet_provider.dart';

class RocketCrashView extends StatefulWidget {
  final int wager;
  const RocketCrashView({super.key, required this.wager});

  @override
  State<RocketCrashView> createState() => _RocketCrashViewState();
}

class _RocketCrashViewState extends State<RocketCrashView> with TickerProviderStateMixin {
  late int selectedBet;
  bool isFlying = false;
  bool hasCashedOut = false;
  bool isCrashed = false;
  double currentMultiplier = 1.00;
  double crashPoint = 2.50;
  double autoCashOutTarget = 2.00; // Auto Cash Out Target Multiplier
  double cashedMultiplier = 0.00;
  int payoutCoins = 0;
  Timer? _gameTimer;

  final List<Map<String, dynamic>> _liveBets = [
    {'name': 'Krypton', 'bet': 250, 'cashed': null},
    {'name': 'CyberCat', 'bet': 100, 'cashed': 2.45},
    {'name': 'NeonSoul', 'bet': 500, 'cashed': 4.10},
    {'name': 'Danial', 'bet': 1000, 'cashed': null},
  ];

  @override
  void initState() {
    super.initState();
    selectedBet = widget.wager;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startLaunch() {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < selectedBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance! Please recharge coins.')),
      );
      return;
    }

    wallet.spendCoins(selectedBet, 'Rocket Crash Launch Bet');

    final rand = Random();
    crashPoint = (1.15 + rand.nextDouble() * rand.nextDouble() * 14.0);

    setState(() {
      isFlying = true;
      isCrashed = false;
      hasCashedOut = false;
      currentMultiplier = 1.00;
      cashedMultiplier = 0.00;
      payoutCoins = 0;
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        currentMultiplier += 0.03 + (currentMultiplier * 0.015);

        // Check Auto Cash-Out condition
        if (!hasCashedOut && currentMultiplier >= autoCashOutTarget && currentMultiplier < crashPoint) {
          _cashOut();
        }

        // Check Crash condition
        if (currentMultiplier >= crashPoint) {
          isFlying = false;
          isCrashed = true;
          currentMultiplier = crashPoint;
          _gameTimer?.cancel();
        }
      });
    });
  }

  void _cashOut() {
    if (!isFlying || hasCashedOut || isCrashed) return;

    final wallet = context.read<WalletProvider>();
    cashedMultiplier = currentMultiplier;
    payoutCoins = (selectedBet * cashedMultiplier).toInt();

    wallet.earnCoins(payoutCoins, 'Rocket Cash Out Win');

    setState(() {
      hasCashedOut = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Column(
      children: [
        // Main Rocket Canvas Chart
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E21),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Custom Paint Rocket Curve Chart
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: RocketCurvePainter(
                        progress: (currentMultiplier - 1.0) / 10.0,
                        isCrashed: isCrashed,
                        isDark: isDark,
                        primaryColor: primary,
                      ),
                    ),
                  ),
                ),

                // Central Floating Multiplier Display
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCrashed
                            ? 'CRASHED AT'
                            : (hasCashedOut ? 'CASHED OUT!' : 'CURRENT MULTIPLIER'),
                        style: TextStyle(
                          color: isCrashed
                              ? AppColors.error
                              : (hasCashedOut ? AppColors.success : Colors.white70),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${currentMultiplier.toStringAsFixed(2)}x',
                        style: TextStyle(
                          color: isCrashed
                              ? AppColors.error
                              : (hasCashedOut ? AppColors.warmGold : Colors.cyanAccent),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: isCrashed ? Colors.red : Colors.cyan,
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      if (hasCashedOut) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: Text(
                            '+$payoutCoins Coins (${cashedMultiplier.toStringAsFixed(2)}x)',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bet Controls & Auto Cash-Out Selector
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                // Auto Cash-Out Target Multiplier Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Auto Target:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [1.5, 2.0, 3.0, 5.0, 10.0].map((target) {
                            final isSelected = autoCashOutTarget == target;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ChoiceChip(
                                label: Text('${target.toStringAsFixed(1)}x'),
                                selected: isSelected,
                                selectedColor: Colors.cyanAccent,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (val) {
                                  if (val && !isFlying) setState(() => autoCashOutTarget = target);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Bet Amount Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [10, 50, 100, 500, 1000].map((b) {
                      final isSelected = selectedBet == b;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('$b 🪙'),
                          selected: isSelected,
                          selectedColor: AppColors.warmGold,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val && !isFlying) setState(() => selectedBet = b);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Launch / Manual Cash Out Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isFlying
                        ? (hasCashedOut ? null : _cashOut)
                        : _startLaunch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFlying
                          ? (hasCashedOut ? Colors.grey.shade800 : AppColors.warmGold)
                          : primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: (isFlying ? AppColors.warmGold : primary).withValues(alpha: 0.5),
                    ),
                    child: Text(
                      isFlying
                          ? (hasCashedOut
                              ? 'CASHED OUT (${cashedMultiplier.toStringAsFixed(2)}x)'
                              : 'CASH OUT (${(selectedBet * currentMultiplier).toInt()} 🪙)')
                          : 'LAUNCH ROCKET ($selectedBet 🪙)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Live Players Feed
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(isDark),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Live Players (${_liveBets.length})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            Text(
                              'Target: ${autoCashOutTarget.toStringAsFixed(1)}x',
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _liveBets.length,
                            itemBuilder: (context, idx) {
                              final item = _liveBets[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 9,
                                          backgroundColor: primary.withValues(alpha: 0.3),
                                          child: Text(
                                            (item['name'] as String)[0],
                                            style: const TextStyle(fontSize: 9, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(item['name'] as String, style: const TextStyle(fontSize: 11)),
                                      ],
                                    ),
                                    Text(
                                      item['cashed'] != null
                                          ? '${item['cashed']}x (+${(item['bet'] * (item['cashed'] as double)).toInt()} 🪙)'
                                          : '${item['bet']} 🪙',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: item['cashed'] != null ? AppColors.success : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RocketCurvePainter extends CustomPainter {
  final double progress;
  final bool isCrashed;
  final bool isDark;
  final Color primaryColor;

  RocketCurvePainter({
    required this.progress,
    required this.isCrashed,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double j = 0; j < size.height; j += 40) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), gridPaint);
    }

    final p = progress.clamp(0.05, 0.95);
    final startOffset = Offset(20, size.height - 30);
    final controlPoint = Offset(size.width * 0.4, size.height - 30);
    final endOffset = Offset(
      20 + (size.width - 50) * p,
      (size.height - 30) - (size.height - 60) * sin(p * pi / 2),
    );

    final path = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, endOffset.dx, endOffset.dy);

    final curvePaint = Paint()
      ..color = isCrashed ? Colors.redAccent : Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, curvePaint);

    if (isCrashed) {
      final burstPaint = Paint()..color = Colors.redAccent.withValues(alpha: 0.8);
      canvas.drawCircle(endOffset, 18, burstPaint);
    } else {
      final glowPaint = Paint()..color = Colors.cyan.withValues(alpha: 0.4);
      canvas.drawCircle(endOffset, 12, glowPaint);

      final textPainter = TextPainter(
        text: const TextSpan(text: '🚀', style: TextStyle(fontSize: 24)),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, endOffset - const Offset(12, 12));
    }
  }

  @override
  bool shouldRepaint(covariant RocketCurvePainter oldDelegate) => true;
}
