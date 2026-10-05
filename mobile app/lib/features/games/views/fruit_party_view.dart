import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class FruitPartyView extends StatefulWidget {
  final int wager;
  const FruitPartyView({super.key, required this.wager});

  @override
  State<FruitPartyView> createState() => _FruitPartyViewState();
}

class _FruitPartyViewState extends State<FruitPartyView> with SingleTickerProviderStateMixin {
  late int betAmount;
  bool isSpinning = false;
  final List<String> symbols = ['🍉', '🍇', '🍒', '🔔', '7️⃣', '💎'];
  late List<String> reelResults;
  String? winStatus;
  int winPayout = 0;

  @override
  void initState() {
    super.initState();
    betAmount = widget.wager;
    reelResults = ['🍉', '🍒', '7️⃣', '🔔', '💎'];
  }

  void _spinSlot() {
    if (isSpinning) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient coins balance!')),
      );
      return;
    }

    wallet.spendCoins(betAmount, 'Fruit Party Slot Spin');

    setState(() {
      isSpinning = true;
      winStatus = null;
      winPayout = 0;
    });

    final rand = Random();
    int ticks = 0;

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        reelResults = List.generate(5, (_) => symbols[rand.nextInt(symbols.length)]);
      });

      ticks++;
      if (ticks >= 15) {
        timer.cancel();

        // Calculate wins: 3 matching = 3x, 4 matching = 10x, 5 matching = MEGA JACKPOT 50x
        final counts = <String, int>{};
        for (var s in reelResults) {
          counts[s] = (counts[s] ?? 0) + 1;
        }

        int maxMatch = counts.values.fold(1, max);
        double multiplier = 0;

        if (maxMatch >= 5) {
          multiplier = 50.0;
          winStatus = '🎰 MEGA JACKPOT WIN! (50x)';
        } else if (maxMatch == 4) {
          multiplier = 10.0;
          winStatus = '🌟 BIG WIN! (10x)';
        } else if (maxMatch == 3) {
          multiplier = 3.0;
          winStatus = '🍒 TRIPLE MATCH! (3x)';
        } else {
          winStatus = '💫 NO MATCH - TRY AGAIN!';
        }

        if (multiplier > 0) {
          winPayout = (betAmount * multiplier).toInt();
          wallet.earnCoins(winPayout, 'Fruit Party Slot Win');
        }

        setState(() {
          isSpinning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF19002E),
      child: Column(
        children: [
          // Super Jackpot Golden Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.amber, blurRadius: 16, spreadRadius: 1),
              ],
            ),
            child: const Column(
              children: [
                Text(
                  '✨ SUPER JACKPOT ✨',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                SizedBox(height: 2),
                Text(
                  '50,000.00 🪙',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 28),
                ),
              ],
            ),
          ),

          // 5-Reel Slot Grid
          Expanded(
            child: RepaintBoundary(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F001D),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.purpleAccent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.purple, blurRadius: 20, spreadRadius: 1),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: reelResults.map((symbol) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 52,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF28004D),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(
                            symbol,
                            style: const TextStyle(fontSize: 34),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          if (winStatus != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                winStatus!,
                style: TextStyle(
                  color: winPayout > 0 ? Colors.amberAccent : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),

          // Spin Control Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [10, 50, 100, 500, 1000].map((b) {
                      final isSelected = betAmount == b;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$b 🪙'),
                          selected: isSelected,
                          selectedColor: Colors.purpleAccent,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val && !isSpinning) setState(() => betAmount = b);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isSpinning ? null : _spinSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                      shadowColor: Colors.purpleAccent.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      isSpinning ? 'SPINNING REELS...' : 'SPIN SLOT ($betAmount 🪙)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
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
}
