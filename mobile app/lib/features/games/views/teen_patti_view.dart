import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/wallet_provider.dart';

class TeenPattiView extends StatefulWidget {
  final int wager;
  const TeenPattiView({super.key, required this.wager});

  @override
  State<TeenPattiView> createState() => _TeenPattiViewState();
}

class _TeenPattiViewState extends State<TeenPattiView> with TickerProviderStateMixin {
  late int currentChaal;
  bool isBlind = true;
  bool isDealt = false;
  List<Map<String, String>> myCards = [];
  String rankDescription = 'Tap DEAL to start round';
  int totalPotPool = 0;
  String? resultText;
  int? winnerIndex;

  final List<Map<String, dynamic>> _tablePlayers = [
    {'name': 'Sophia', 'avatar': '👩‍🦰', 'chips': 12500, 'cards': ['🎴', '🎴', '🎴'], 'isFolded': false},
    {'name': 'Alex', 'avatar': '🧔', 'chips': 8400, 'cards': ['🎴', '🎴', '🎴'], 'isFolded': false},
    {'name': 'YOU', 'avatar': '👑', 'chips': 0, 'cards': [], 'isFolded': false},
    {'name': 'Danial', 'avatar': '👨‍💼', 'chips': 19200, 'cards': ['🎴', '🎴', '🎴'], 'isFolded': false},
  ];

  @override
  void initState() {
    super.initState();
    currentChaal = widget.wager;
  }

  void _dealHand() {
    final wallet = context.read<WalletProvider>();
    if (wallet.coins < currentChaal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient coins!')));
      return;
    }

    wallet.spendCoins(currentChaal, 'Teen Patti Ante Bet');

    final rand = Random();
    final deck = [
      {'val': 'A', 'suit': '♠', 'color': 'black'},
      {'val': 'K', 'suit': '♠', 'color': 'black'},
      {'val': 'Q', 'suit': '♠', 'color': 'black'},
      {'val': 'A', 'suit': '♥', 'color': 'red'},
      {'val': 'K', 'suit': '♥', 'color': 'red'},
      {'val': '10', 'suit': '♦', 'color': 'red'},
      {'val': 'J', 'suit': '♣', 'color': 'black'},
      {'val': '9', 'suit': '♠', 'color': 'black'},
      {'val': 'A', 'suit': '♦', 'color': 'red'},
    ];

    deck.shuffle(rand);

    setState(() {
      isDealt = true;
      isBlind = true;
      resultText = null;
      winnerIndex = null;
      totalPotPool = currentChaal * 4;
      myCards = [deck[0], deck[1], deck[2]];
      rankDescription = 'Cards Sealed (BLIND)';
      for (var p in _tablePlayers) {
        p['isFolded'] = false;
      }
    });
  }

  void _seeCards() {
    if (!isDealt || !isBlind) return;
    setState(() {
      isBlind = false;
      final isFlush = myCards[0]['suit'] == myCards[1]['suit'] && myCards[1]['suit'] == myCards[2]['suit'];
      final isPair = myCards[0]['val'] == myCards[1]['val'] || myCards[1]['val'] == myCards[2]['val'];

      if (myCards[0]['val'] == myCards[1]['val'] && myCards[1]['val'] == myCards[2]['val']) {
        rankDescription = '🔥 TRAIL / SET 3-OF-A-KIND';
      } else if (isFlush) {
        rankDescription = '✨ COLOR / FLUSH HAND';
      } else if (isPair) {
        rankDescription = '🎯 PAIR HAND';
      } else {
        rankDescription = '🎴 HIGH CARD (${myCards[0]['val']}${myCards[0]['suit']})';
      }
    });
  }

  void _chaalBet() {
    if (!isDealt) return;
    final wallet = context.read<WalletProvider>();
    int betAmount = isBlind ? currentChaal : currentChaal * 2;

    if (wallet.coins < betAmount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Insufficient balance for Chaal!')));
      return;
    }

    wallet.spendCoins(betAmount, 'Teen Patti Chaal Bet');

    setState(() {
      totalPotPool += betAmount * 3;
    });
  }

  void _packFold() {
    if (!isDealt) return;
    setState(() {
      isDealt = false;
      _tablePlayers[2]['isFolded'] = true;
      resultText = '💔 YOU FOLDED HAND';
    });
  }

  void _showWinner() {
    if (!isDealt) return;
    final wallet = context.read<WalletProvider>();
    final winCoins = totalPotPool;
    wallet.earnCoins(winCoins, 'Teen Patti Showdown Payout');

    setState(() {
      winnerIndex = 2; // User wins
      resultText = '🏆 SHOWDOWN! You won $winCoins 🪙 Pot!';
      isDealt = false;
      totalPotPool = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF0F4D2A), Color(0xFF041B0E)],
        ),
      ),
      child: Column(
        children: [
          // Table Pot Header
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.amber, blurRadius: 12)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAL POT: $totalPotPool 🪙',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          // Main Table Arena & Player Seating
          Expanded(
            child: Stack(
              children: [
                // Oval Poker Felt Table Outline with Gold Trim
                Center(
                  child: Container(
                    width: double.infinity,
                    height: 250,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C3D21),
                      borderRadius: BorderRadius.circular(125),
                      border: Border.all(color: Colors.amber, width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 2),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              rankDescription,
                              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Cards Render Arena
                          RepaintBoundary(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: isDealt && myCards.isNotEmpty
                                  ? myCards.map((c) => _buildCardWidget(c, isBlind)).toList()
                                  : [
                                      _buildCardWidget({'val': '?', 'suit': '🎴', 'color': 'black'}, true),
                                      _buildCardWidget({'val': '?', 'suit': '🎴', 'color': 'black'}, true),
                                      _buildCardWidget({'val': '?', 'suit': '🎴', 'color': 'black'}, true),
                                    ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Player Avatars around Table
                Positioned(top: 10, left: 20, child: _buildPlayerAvatar(_tablePlayers[0], false)),
                Positioned(top: 10, right: 20, child: _buildPlayerAvatar(_tablePlayers[1], false)),
                Positioned(bottom: 10, left: 20, child: _buildPlayerAvatar(_tablePlayers[3], false)),
                Positioned(bottom: 10, right: 20, child: _buildPlayerAvatar(_tablePlayers[2], true)),
              ],
            ),
          ),

          if (resultText != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber),
                ),
                child: Text(
                  resultText!,
                  style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),

          // Control Action Buttons Bar
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton('SEE CARDS', isDealt && isBlind ? _seeCards : null, Colors.blueAccent),
                    _buildActionButton('CHAAL (2x)', isDealt ? _chaalBet : null, Colors.orangeAccent),
                    _buildActionButton('PACK (FOLD)', isDealt ? _packFold : null, Colors.redAccent),
                    _buildActionButton('SHOW', isDealt ? _showWinner : null, Colors.purpleAccent),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isDealt ? null : _dealHand,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: Text(
                      isDealt ? 'ROUND IN PROGRESS...' : 'DEAL HAND ($currentChaal 🪙)',
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

  Widget _buildCardWidget(Map<String, String> card, bool blind) {
    final isRed = card['color'] == 'red';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 58,
      height: 86,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: blind ? const Color(0xFF1E3A8A) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: blind ? Colors.cyanAccent : Colors.grey.shade300, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: blind
          ? const Center(child: Text('🎴', style: TextStyle(fontSize: 28)))
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    '${card['val']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isRed ? Colors.red : Colors.black,
                    ),
                  ),
                ),
                Text(
                  '${card['suit']}',
                  style: TextStyle(
                    fontSize: 24,
                    color: isRed ? Colors.red : Colors.black,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '${card['val']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isRed ? Colors.red : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPlayerAvatar(Map<String, dynamic> player, bool isMe) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isMe ? Colors.amber.withValues(alpha: 0.2) : Colors.black54,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? Colors.amber : Colors.white24),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isMe ? Colors.amber : Colors.grey.shade800,
            child: Text(player['avatar'] as String, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 2),
          Text(player['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, VoidCallback? onPressed, Color color) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
