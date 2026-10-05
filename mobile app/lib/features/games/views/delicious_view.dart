import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class DeliciousView extends StatefulWidget {
  final int wager;
  const DeliciousView({super.key, required this.wager});

  @override
  State<DeliciousView> createState() => _DeliciousViewState();
}

class _DeliciousViewState extends State<DeliciousView> {
  late int betAmount;
  bool isMatching = false;
  List<String> candyGrid = ['🍰', '🍩', '🧁', '🍦', '🍨', '🍬', '🍭', '🎂', '🍩'];
  String? resultText;

  @override
  void initState() {
    super.initState();
    betAmount = widget.wager;
  }

  void _matchBakery() {
    if (isMatching) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance!')));
      return;
    }

    wallet.spendCoins(betAmount, 'Delicious Bakery Match');

    setState(() {
      isMatching = true;
      resultText = null;
    });

    final items = ['🍰', '🍩', '🧁', '🍦', '🍨', '🍬', '🍭', '🎂'];
    final rand = Random();

    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        candyGrid = List.generate(9, (_) => items[rand.nextInt(items.length)]);
        isMatching = false;
      });

      final countMap = <String, int>{};
      for (var c in candyGrid) {
        countMap[c] = (countMap[c] ?? 0) + 1;
      }

      int maxCombo = countMap.values.fold(1, max);
      if (maxCombo >= 4) {
        final payout = betAmount * 5;
        wallet.earnCoins(payout, 'Delicious Sweet Combo Win');
        setState(() {
          resultText = '🎂 DELICIOUS SWEET COMBO! Matched $maxCombo Items! Won $payout 🪙!';
        });
      } else {
        setState(() {
          resultText = '🍩 Sweet drop complete! Try another match!';
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
          colors: [Color(0xFF38082A), Color(0xFF14020E)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Header Title Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.pinkAccent]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.orangeAccent, blurRadius: 14)],
            ),
            child: const Text(
              '🍰 DELICIOUS SWEETS MATCH 🍩',
              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),

          const SizedBox(height: 16),

          // Candy Grid Box
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF26051C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4), width: 2),
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: candyGrid.length,
                itemBuilder: (context, idx) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A0E37),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.4)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                    ),
                    child: Center(
                      child: Text(candyGrid[idx], style: const TextStyle(fontSize: 38)),
                    ),
                  );
                },
              ),
            ),
          ),

          if (resultText != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                resultText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),

          // Action Button Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isMatching ? null : _matchBakery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: Text(
                  isMatching ? 'MATCHING SWEETS...' : 'DROP SWEETS ($betAmount 🪙)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
