import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class BountyFootballView extends StatefulWidget {
  final int wager;
  const BountyFootballView({super.key, required this.wager});

  @override
  State<BountyFootballView> createState() => _BountyFootballViewState();
}

class _BountyFootballViewState extends State<BountyFootballView> with SingleTickerProviderStateMixin {
  late int selectedBet;
  String selectedCorner = 'TOP LEFT';
  double oddsMultiplier = 4.0;
  bool isKicking = false;
  String? resultText;
  Offset? targetSwipePos;

  late AnimationController _kickController;
  late Animation<double> _ballYAnimation;
  late Animation<double> _ballScaleAnimation;

  final Map<String, double> cornerOdds = {
    'TOP LEFT': 4.0,
    'TOP RIGHT': 4.0,
    'BOTTOM LEFT': 2.5,
    'BOTTOM RIGHT': 2.5,
    'CENTER GOAL': 1.8,
  };

  @override
  void initState() {
    super.initState();
    selectedBet = widget.wager;
    _kickController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ballYAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _kickController, curve: Curves.easeOut));
    _ballScaleAnimation = Tween<double>(begin: 1.0, end: 0.55).animate(CurvedAnimation(parent: _kickController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _kickController.dispose();
    super.dispose();
  }

  void _kickPenaltyAtPos(Offset pos) {
    if (isKicking) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < selectedBet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance!')));
      return;
    }

    // Deduct wager
    wallet.spendCoins(selectedBet, 'Football Penalty Kick');

    setState(() {
      isKicking = true;
      targetSwipePos = pos;
      resultText = null;
    });

    _kickController.forward(from: 0.0);

    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final rand = Random();
      final isGoal = rand.nextDouble() > 0.40;

      if (isGoal) {
        final double mult = cornerOdds[selectedCorner] ?? 2.5;
        final payout = (selectedBet * mult).toInt();
        wallet.earnCoins(payout, 'Football Penalty Goal Payout');
        setState(() {
          isKicking = false;
          resultText = '⚽ GOAL! Clean Shot into $selectedCorner (${mult}x)! Won $payout 🪙!';
        });
      } else {
        setState(() {
          isKicking = false;
          resultText = '🧤 SAVED! Goalkeeper dived and blocked your $selectedCorner shot!';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF03140A), Color(0xFF0B331A)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Goal Net Stadium Drag / Swipe Arena
          Expanded(
            flex: 5,
            child: GestureDetector(
              onPanUpdate: (details) {
                if (!isKicking) {
                  _kickPenaltyAtPos(details.localPosition);
                }
              },
              onTapDown: (details) {
                if (!isKicking) {
                  _kickPenaltyAtPos(details.localPosition);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF051C0F),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.greenAccent, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 16)],
                ),
                child: Stack(
                  children: [
                    // Goal Net Grid Pattern Lines
                    Positioned.fill(
                      child: CustomPaint(painter: GoalNetPainter()),
                    ),

                    // Goalkeeper Center
                    Align(
                      alignment: const Alignment(0.0, -0.4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        transform: isKicking ? Matrix4.translationValues(selectedCorner.contains('LEFT') ? -70 : 70, 0, 0) : Matrix4.identity(),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🧤', style: TextStyle(fontSize: 48)),
                            Text('GOALKEEPER', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                    // Target Spot Overlay Guides
                    Positioned(top: 20, left: 20, child: _targetSpot('TOP LEFT')),
                    Positioned(top: 20, right: 20, child: _targetSpot('TOP RIGHT')),
                    Positioned(bottom: 50, left: 20, child: _targetSpot('BOTTOM LEFT')),
                    Positioned(bottom: 50, right: 20, child: _targetSpot('BOTTOM RIGHT')),
                    Positioned(top: 90, left: MediaQuery.of(context).size.width * 0.4, child: _targetSpot('CENTER GOAL')),

                    // Football Trajectory Animation
                    AnimatedBuilder(
                      animation: _kickController,
                      builder: (context, child) {
                        final double yPos = _ballYAnimation.value * 160 + 10;
                        final double scale = _ballScaleAnimation.value;
                        return Positioned(
                          bottom: yPos,
                          left: targetSwipePos != null
                              ? targetSwipePos!.dx.clamp(20.0, MediaQuery.of(context).size.width - 60)
                              : MediaQuery.of(context).size.width * 0.5 - 35,
                          child: Transform.scale(
                            scale: scale,
                            child: const Text('⚽', style: TextStyle(fontSize: 44)),
                          ),
                        );
                      },
                    ),

                    // Swipe Prompt Overlay
                    Positioned(
                      top: 6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '👆 SWIPE FINGER ON GOAL NET TO SHOOT',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (resultText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: Text(
                  resultText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),

          // Odds & Target Selection Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: cornerOdds.entries.map((entry) {
                final isChosen = selectedCorner == entry.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text('${entry.key} (${entry.value}x)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isChosen ? Colors.black : Colors.white)),
                    selected: isChosen,
                    selectedColor: Colors.greenAccent,
                    onSelected: (val) {
                      if (val && !isKicking) {
                        setState(() {
                          selectedCorner = entry.key;
                          oddsMultiplier = entry.value;
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Kick Button & Wager Selection
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [10, 50, 100, 500, 1000].map((b) {
                      final isSelected = selectedBet == b;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$b 🪙'),
                          selected: isSelected,
                          selectedColor: Colors.amber,
                          labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                          onSelected: (val) {
                            if (val && !isKicking) setState(() => selectedBet = b);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isKicking ? null : () => _kickPenaltyAtPos(const Offset(160, 60)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: Text(
                      isKicking ? 'SHOOTING PENALTY...' : 'SWIPE OR TAP TO SHOOT ($selectedBet 🪙)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _targetSpot(String cornerKey) {
    final isSelected = selectedCorner == cornerKey;
    final odds = cornerOdds[cornerKey] ?? 2.5;
    return GestureDetector(
      onTap: () {
        if (!isKicking) {
          setState(() {
            selectedCorner = cornerKey;
            oddsMultiplier = odds;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent.withValues(alpha: 0.35) : Colors.black54,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white30, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.my_location_rounded, color: isSelected ? Colors.greenAccent : Colors.white54, size: 20),
            Text('${odds}x', style: TextStyle(color: isSelected ? Colors.greenAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class GoalNetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final netPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 24) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), netPaint);
    }
    for (double j = 0; j < size.height; j += 24) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), netPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
