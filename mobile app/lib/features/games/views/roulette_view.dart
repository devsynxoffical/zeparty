import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class RouletteView extends StatefulWidget {
  final int wager;
  const RouletteView({super.key, required this.wager});

  @override
  State<RouletteView> createState() => _RouletteViewState();
}

class _RouletteViewState extends State<RouletteView> with SingleTickerProviderStateMixin {
  late int selectedBet;
  String selectedType = 'RED'; // RED, BLACK, EVEN, ODD, 1-18, 19-36
  bool isSpinning = false;
  double wheelRotation = 0.0;
  int? winningNumber;
  String? resultText;

  final List<int> redNumbers = [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36];

  @override
  void initState() {
    super.initState();
    selectedBet = widget.wager;
  }

  void _spinRoulette() {
    if (isSpinning) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < selectedBet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient coins balance!')));
      return;
    }

    wallet.spendCoins(selectedBet, 'Roulette Bet Placement');

    setState(() {
      isSpinning = true;
      resultText = null;
      winningNumber = null;
    });

    final rand = Random();
    final targetNum = rand.nextInt(37);
    final isRedWin = redNumbers.contains(targetNum);

    Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) return;
      setState(() {
        wheelRotation += 0.28;
      });

      if (wheelRotation >= 18.0) {
        timer.cancel();
        setState(() {
          isSpinning = false;
          wheelRotation = 0.0;
          winningNumber = targetNum;
        });

        bool won = false;
        if (selectedType == 'RED' && isRedWin) won = true;
        if (selectedType == 'BLACK' && !isRedWin && targetNum != 0) won = true;
        if (selectedType == 'EVEN' && targetNum % 2 == 0 && targetNum != 0) won = true;
        if (selectedType == 'ODD' && targetNum % 2 != 0) won = true;
        if (selectedType == '1-18' && targetNum >= 1 && targetNum <= 18) won = true;
        if (selectedType == '19-36' && targetNum >= 19 && targetNum <= 36) won = true;

        if (won) {
          final payout = selectedBet * 2;
          wallet.earnCoins(payout, 'Roulette Win Payout');
          setState(() {
            resultText = '🎉 WINNER! Ball landed on $targetNum (${targetNum == 0 ? "GREEN" : (isRedWin ? "RED" : "BLACK")}). Won $payout 🪙!';
          });
        } else {
          setState(() {
            resultText = '💥 Ball landed on $targetNum (${targetNum == 0 ? "GREEN" : (isRedWin ? "RED" : "BLACK")}). Better luck next spin!';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF1E3A2B), Color(0xFF07140D)],
          radius: 0.9,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // European Roulette Wheel Header Canvas
          Expanded(
            flex: 5,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RepaintBoundary(
                    child: Transform.rotate(
                      angle: wheelRotation,
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2C1A0E),
                          border: Border.all(color: Colors.amber, width: 6),
                          boxShadow: [
                            BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Ring Cells Graphic
                            for (int i = 0; i < 12; i++)
                              Transform.rotate(
                                angle: (i * pi / 6),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: i == 0 ? Colors.green : (i % 2 == 0 ? Colors.red : Colors.black),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.amber.shade200, width: 1),
                                    ),
                                  ),
                                ),
                              ),
                            // Center Brass Spindle
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Colors.amber, Color(0xFF8B6508)]),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Center(
                                child: Text(
                                  '🎰\nROULETTE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (winningNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                      ),
                      child: Text(
                        'RESULT: $winningNumber (${winningNumber == 0 ? "GREEN 0" : (redNumbers.contains(winningNumber) ? "RED" : "BLACK")})',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (resultText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                resultText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

          // Green Felt Betting Grid Options
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2918),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      _betChip('RED (2x)', 'RED', Colors.redAccent),
                      _betChip('BLACK (2x)', 'BLACK', const Color(0xFF1F1F1F)),
                    ],
                  ),
                  Row(
                    children: [
                      _betChip('EVEN (2x)', 'EVEN', Colors.blueAccent),
                      _betChip('ODD (2x)', 'ODD', Colors.deepOrangeAccent),
                    ],
                  ),
                  Row(
                    children: [
                      _betChip('1 - 18 (2x)', '1-18', Colors.teal),
                      _betChip('19 - 36 (2x)', '19-36', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Spin Control Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSpinning ? null : _spinRoulette,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: Text(
                  isSpinning ? 'SPINNING WHEEL...' : 'SPIN ROULETTE ($selectedBet 🪙)',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _betChip(String label, String typeKey, Color color) {
    final isSelected = selectedType == typeKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedType = typeKey),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.amber : Colors.white24, width: isSelected ? 2.5 : 1),
            boxShadow: isSelected ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.5), blurRadius: 8)] : null,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }
}
