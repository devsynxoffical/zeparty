import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class GreedyLionView extends StatefulWidget {
  final int wager;
  const GreedyLionView({super.key, required this.wager});

  @override
  State<GreedyLionView> createState() => _GreedyLionViewState();
}

class _GreedyLionViewState extends State<GreedyLionView> {
  late int selectedBet;
  int activeIndex = 0;
  bool isSpinning = false;
  String? resultText;
  int selectedAnimalIdx = 0;
  Map<String, dynamic>? winningAnimal;

  final List<Map<String, dynamic>> animals = [
    {'name': 'Lion', 'icon': '🦁', 'mult': 12, 'color': Colors.amber},
    {'name': 'Panda', 'icon': '🐼', 'mult': 8, 'color': Colors.white},
    {'name': 'Monkey', 'icon': '🐵', 'mult': 6, 'color': Colors.brown},
    {'name': 'Rabbit', 'icon': '🐰', 'mult': 4, 'color': Colors.pinkAccent},
    {'name': 'Elephant', 'icon': '🐘', 'mult': 10, 'color': Colors.blueGrey},
    {'name': 'Fox', 'icon': '🦊', 'mult': 5, 'color': Colors.orangeAccent},
    {'name': 'Eagle', 'icon': '🦅', 'mult': 8, 'color': Colors.cyanAccent},
    {'name': 'Peacock', 'icon': '🦚', 'mult': 6, 'color': Colors.tealAccent},
  ];

  @override
  void initState() {
    super.initState();
    selectedBet = widget.wager;
    winningAnimal = animals[0];
  }

  void _spinRing() {
    if (isSpinning) return;

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < selectedBet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient coins balance!')));
      return;
    }

    wallet.spendCoins(selectedBet, 'Greedy Lion Safari Bet');

    setState(() {
      isSpinning = true;
      resultText = null;
    });

    final rand = Random();
    final winningIdx = rand.nextInt(animals.length);
    int stepCount = 0;

    Timer.periodic(const Duration(milliseconds: 75), (timer) {
      if (!mounted) return;
      setState(() {
        activeIndex = (activeIndex + 1) % animals.length;
        winningAnimal = animals[activeIndex]; // Update center icon as ring spins
      });

      stepCount++;
      if (stepCount >= 24 + winningIdx) {
        timer.cancel();
        final winner = animals[winningIdx];
        setState(() {
          isSpinning = false;
          activeIndex = winningIdx;
          winningAnimal = winner; // Display exact winning animal icon & name in center
        });

        if (selectedAnimalIdx == winningIdx) {
          final payout = (selectedBet * (winner['mult'] as int)).toInt();
          wallet.earnCoins(payout, 'Greedy Lion Win Payout');
          setState(() {
            resultText = '🎉 CONGRATS! ${winner['icon']} ${winner['name']} Won (${winner['mult']}x)! You won $payout 🪙!';
          });
        } else {
          setState(() {
            resultText = '💥 ${winner['icon']} ${winner['name']} Won (${winner['mult']}x). Try another animal!';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCenterAnimal = winningAnimal ?? animals[activeIndex];

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF0F3B25), Color(0xFF03140C)],
          radius: 0.9,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Central Circular Safari Ring Header with Dynamic Winning Animal Display
          Expanded(
            flex: 5,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Safari Ring Frame with glowing LED indicators
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B2919),
                      border: Border.all(color: Colors.amber, width: 4),
                      boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 20)],
                    ),
                    child: Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF165234),
                          border: Border.all(color: Colors.amber, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              currentCenterAnimal['icon'] as String,
                              style: const TextStyle(fontSize: 48),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isSpinning ? 'SPINNING...' : 'WINNER: ${currentCenterAnimal['name']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                            Text(
                              '${currentCenterAnimal['mult']}x MULTIPLIER',
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 8 Animal Cards around the Circular Ring
                  for (int i = 0; i < animals.length; i++)
                    Transform.translate(
                      offset: Offset(
                        105 * cos(i * 2 * pi / animals.length - pi / 2),
                        105 * sin(i * 2 * pi / animals.length - pi / 2),
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => selectedAnimalIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeIndex == i
                                ? Colors.amber
                                : (selectedAnimalIdx == i ? Colors.greenAccent : const Color(0xFF082115)),
                            border: Border.all(
                              color: activeIndex == i ? Colors.white : (selectedAnimalIdx == i ? Colors.green : Colors.amber.withValues(alpha: 0.4)),
                              width: 2,
                            ),
                            boxShadow: activeIndex == i ? [const BoxShadow(color: Colors.amber, blurRadius: 14)] : null,
                          ),
                          child: Center(
                            child: Text(animals[i]['icon'] as String, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
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

          // Animal Selection Grid at Bottom
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF082618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: animals.length,
                itemBuilder: (context, idx) {
                  final item = animals[idx];
                  final isChosen = selectedAnimalIdx == idx;
                  final isActive = activeIndex == idx;

                  return GestureDetector(
                    onTap: () => setState(() => selectedAnimalIdx = idx),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isChosen ? Colors.greenAccent.withValues(alpha: 0.25) : const Color(0xFF0E3D27),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive ? Colors.amber : (isChosen ? Colors.greenAccent : Colors.white12),
                          width: isChosen || isActive ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item['icon'] as String, style: const TextStyle(fontSize: 20)),
                          const SizedBox(height: 2),
                          Text('${item['name']}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text('${item['mult']}x', style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Spin Button & Bet Selector Chips
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
                            if (val && !isSpinning) setState(() => selectedBet = b);
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
                    onPressed: isSpinning ? null : _spinRing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: Text(
                      isSpinning ? 'SPINNING SAFARI RING...' : 'SPIN SAFARI RING ($selectedBet 🪙)',
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
}
