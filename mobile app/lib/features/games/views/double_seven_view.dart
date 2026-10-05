import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class DoubleSevenView extends StatefulWidget {
  final int wager;
  const DoubleSevenView({super.key, required this.wager});

  @override
  State<DoubleSevenView> createState() => _DoubleSevenViewState();
}

class _DoubleSevenViewState extends State<DoubleSevenView> {
  late int betAmount;
  bool isSpinning = false;
  List<String> reels = ['7️⃣', '7️⃣', '7️⃣'];
  String? resultText;

  @override
  void initState() {
    super.initState();
    betAmount = widget.wager;
  }

  void _spinRetroSlot() {
    if (isSpinning) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient coins balance!')));
      return;
    }

    wallet.spendCoins(betAmount, 'Double Seven 77 Slot Spin');

    setState(() {
      isSpinning = true;
      resultText = null;
    });

    final symbols = ['7️⃣', '💎', '🔔', 'BAR', '🍒'];
    final rand = Random();
    int ticks = 0;

    Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (!mounted) return;
      setState(() {
        reels = [symbols[rand.nextInt(symbols.length)], symbols[rand.nextInt(symbols.length)], symbols[rand.nextInt(symbols.length)]];
      });

      ticks++;
      if (ticks >= 15) {
        timer.cancel();
        final is777 = reels.every((r) => r == '7️⃣');
        final isMatch = reels[0] == reels[1] || reels[1] == reels[2] || reels[0] == reels[2];

        if (is777) {
          final payout = betAmount * 77;
          wallet.earnCoins(payout, 'Double Seven 777 Mega Jackpot');
          setState(() {
            isSpinning = false;
            resultText = '🔥 7️⃣-7️⃣-7️⃣ LUCKY SEVEN JACKPOT! Won $payout 🪙!';
          });
        } else if (isMatch) {
          final payout = betAmount * 3;
          wallet.earnCoins(payout, 'Double Seven Match Payout');
          setState(() {
            isSpinning = false;
            resultText = '✨ DOUBLE MATCH! Won $payout 🪙!';
          });
        } else {
          setState(() {
            isSpinning = false;
            resultText = '💫 Better luck next spin!';
          });
        }
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
          colors: [Color(0xFF2E004F), Color(0xFF0F001D)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Neon Arcade Header Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.pinkAccent, width: 2),
              boxShadow: const [BoxShadow(color: Colors.pinkAccent, blurRadius: 16)],
            ),
            child: const Text(
              '7️⃣ DOUBLE SEVEN (77) 7️⃣',
              style: TextStyle(color: Colors.pinkAccent, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2),
            ),
          ),

          const Spacer(),

          // 3 Mechanical Reels Cabinet Frame
          RepaintBoundary(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF160033),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.amber, width: 3),
                boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 24)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: reels.map((symbol) {
                  return Container(
                    width: 78,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF38006B), Color(0xFF1D0038)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.6), width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                    ),
                    child: Center(
                      child: Text(symbol, style: const TextStyle(fontSize: 42)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Spacer(),

          if (resultText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                resultText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),

          // Bet Amount & Spin Button Footer
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
                          selectedColor: Colors.pinkAccent,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
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
                    onPressed: isSpinning ? null : _spinRetroSlot,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                      shadowColor: Colors.pinkAccent.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      isSpinning ? 'SPINNING SEVENS...' : 'SPIN DOUBLE 77 ($betAmount 🪙)',
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
