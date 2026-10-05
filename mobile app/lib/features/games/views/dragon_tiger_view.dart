import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class DragonTigerView extends StatefulWidget {
  final int wager;
  const DragonTigerView({super.key, required this.wager});

  @override
  State<DragonTigerView> createState() => _DragonTigerViewState();
}

class _DragonTigerViewState extends State<DragonTigerView> {
  late int selectedChip;
  String? selectedZone; // 'dragon', 'tie', 'tiger'
  bool isDealing = false;
  String? dragonCard;
  String? tigerCard;
  String? resultText;
  int payoutCoins = 0;

  @override
  void initState() {
    super.initState();
    selectedChip = widget.wager;
  }

  void _placeBet(String zone) {
    if (isDealing) return;
    setState(() => selectedZone = zone);
  }

  void _dealRound() {
    if (selectedZone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Dragon, Tie, or Tiger to place your bet!')),
      );
      return;
    }

    final wallet = context.read<WalletProvider>();
    if (wallet.coins < selectedChip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance!')),
      );
      return;
    }

    wallet.spendCoins(selectedChip, 'Dragon Tiger Bet');

    setState(() {
      isDealing = true;
      dragonCard = null;
      tigerCard = null;
      resultText = null;
    });

    final cards = ['A♠', 'K♥', 'Q♦', 'J♣', '10♠', '9♥', '8♦', '7♣', '6♠', '5♥'];
    final rand = Random();

    Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        dragonCard = cards[rand.nextInt(cards.length)];
      });
    });

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final dCard = dragonCard ?? 'K♠';
      final tCard = cards[rand.nextInt(cards.length)];

      setState(() {
        tigerCard = tCard;
        isDealing = false;
      });

      final dVal = _getCardValue(dCard);
      final tVal = _getCardValue(tCard);

      String winner = 'tie';
      if (dVal > tVal) {
        winner = 'dragon';
      } else if (tVal > dVal) {
        winner = 'tiger';
      }

      int multiplier = 0;
      if (selectedZone == winner) {
        multiplier = (winner == 'tie') ? 8 : 2;
        payoutCoins = selectedChip * multiplier;
        wallet.earnCoins(payoutCoins, 'Dragon Tiger Win');
        setState(() {
          resultText = '🎉 YOU WON $payoutCoins COINS! (${winner.toUpperCase()} WINS)';
        });
      } else {
        payoutCoins = 0;
        setState(() {
          resultText = '💥 ROUND ENDED (${winner.toUpperCase()} WINS)';
        });
      }
    });
  }

  int _getCardValue(String card) {
    if (card.startsWith('A')) return 1;
    if (card.startsWith('K')) return 13;
    if (card.startsWith('Q')) return 12;
    if (card.startsWith('J')) return 11;
    return int.tryParse(card.replaceAll(RegExp(r'[^0-9]'), '')) ?? 10;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A0006),
      child: Column(
        children: [
          // Header Arena: Dragon & Tiger Emblems
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildEmblem('🐉 DRAGON', Colors.redAccent),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: const Text('ROUND 15s', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                _buildEmblem('🐅 TIGER', Colors.orangeAccent),
              ],
            ),
          ),

          // Cards Dealing Table Center
          Expanded(
            flex: 4,
            child: RepaintBoundary(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCardSlot('DRAGON CARD', dragonCard, Colors.redAccent),
                  const Text('VS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.amberAccent)),
                  _buildCardSlot('TIGER CARD', tigerCard, Colors.orangeAccent),
                ],
              ),
            ),
          ),

          // Result Announcement Bar
          if (resultText != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber, width: 1.5),
              ),
              child: Text(
                resultText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),

          // Betting Zones: Dragon (1:1), Tie (8:1), Tiger (1:1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(child: _buildBetZone('DRAGON\n1:1', 'dragon', Colors.redAccent)),
                const SizedBox(width: 8),
                Expanded(child: _buildBetZone('TIE\n8:1', 'tie', Colors.purpleAccent)),
                const SizedBox(width: 8),
                Expanded(child: _buildBetZone('TIGER\n1:1', 'tiger', Colors.amberAccent)),
              ],
            ),
          ),

          // Chips Tray & Deal Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [10, 50, 100, 500, 1000].map((chip) {
                      final isSelected = selectedChip == chip;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('$chip 🪙'),
                          selected: isSelected,
                          selectedColor: Colors.amber,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (val) {
                            if (val && !isDealing) setState(() => selectedChip = chip);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isDealing ? null : _dealRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isDealing ? 'DEALING CARDS...' : 'DEAL CARDS ($selectedChip 🪙)',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildEmblem(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color),
      ),
      child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildCardSlot(String label, String? cardText, Color color) {
    return Container(
      width: 110,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF1E0005),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12)],
      ),
      child: cardText == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.style_rounded, color: color, size: 36),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : Center(
              child: Text(
                cardText,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildBetZone(String title, String zoneKey, Color color) {
    final isSelected = selectedZone == zoneKey;
    return GestureDetector(
      onTap: () => _placeBet(zoneKey),
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.3) : const Color(0xFF180004),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.4), width: isSelected ? 2.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$selectedChip 🪙', style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
