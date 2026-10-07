import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

class RpWalletSheet extends StatefulWidget {
  final VoidCallback? onOpenShop;

  const RpWalletSheet({
    super.key,
    this.onOpenShop,
  });

  static void show(BuildContext context, {VoidCallback? onShop}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RpWalletSheet(
        onOpenShop: onShop,
      ),
    );
  }

  @override
  State<RpWalletSheet> createState() => _RpWalletSheetState();
}

class _RpWalletSheetState extends State<RpWalletSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _boosters = [
    {
      'id': 'booster_fishing_cannon',
      'name': 'Double Cannon',
      'game': 'Fishing',
      'rp': 150,
      'coins': 50,
      'gradient': [Color(0xFF2FD3E6), Color(0xFF0C6A8C)],
    },
    {
      'id': 'booster_fruit_moves',
      'name': 'Extra Moves',
      'game': 'Fruit Match',
      'rp': 100,
      'coins': 30,
      'gradient': [Color(0xFFFFB45C), Color(0xFFE8641C)],
    },
    {
      'id': 'booster_rocket_slow',
      'name': 'Slow Motion',
      'game': 'Rocket',
      'rp': 200,
      'coins': 60,
      'gradient': [Color(0xFFFF8A8A), Color(0xFFA81818)],
    },
    {
      'id': 'booster_lion_shield',
      'name': 'Lion Shield',
      'game': 'Lion',
      'rp': 150,
      'coins': 50,
      'gradient': [Color(0xFFFFD27A), Color(0xFFE8891C)],
    },
    {
      'id': 'booster_seven_undo',
      'name': 'Undo x3',
      'game': 'Seven',
      'rp': 100,
      'coins': 25,
      'gradient': [Color(0xFFC39BFF), Color(0xFF6A3BD6)],
    },
    {
      'id': 'booster_lion_boost',
      'name': 'Sprint Boost',
      'game': 'Lion',
      'rp': 120,
      'coins': 40,
      'gradient': [Color(0xFFC8FFE8), Color(0xFF3FB890)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buyBooster(BuildContext context, Map<String, dynamic> booster, bool withRp) {
    final gameProvider = context.read<GameProvider>();
    final walletProvider = context.read<WalletProvider>();
    final boosterId = booster['id'] as String;
    final boosterName = booster['name'] as String;

    if (withRp) {
      final rpCost = booster['rp'] as int;
      if (gameProvider.rpBalance < rpCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text('Insufficient RP balance! Play games to earn more.')),
        );
        return;
      }
      final success = gameProvider.purchaseBooster(
        wallet: walletProvider,
        boosterId: boosterId,
        boosterName: boosterName,
        rpCost: rpCost,
      );
      if (success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFF2FBF71), content: Text('Unlocked $boosterName with $rpCost RP!')),
        );
      }
    } else {
      final coinsCost = booster['coins'] as int;
      if (walletProvider.coins < coinsCost) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.redAccent, content: Text('Insufficient coins balance!')),
        );
        return;
      }
      final success = gameProvider.purchaseBooster(
        wallet: walletProvider,
        boosterId: boosterId,
        boosterName: boosterName,
        coinsCost: coinsCost,
      );
      if (success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFF2FBF71), content: Text('Unlocked $boosterName with $coinsCost Coins!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final rpBalance = gameProvider.rpBalance;
    final capUsedToday = gameProvider.dailyRpEarned;
    final dailyCap = gameProvider.dailyRpCap;
    final capProgress = (capUsedToday / dailyCap).clamp(0.0, 1.0);
    final transactions = gameProvider.rpTransactions;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0A12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFFEDEDF2), size: 20),
                ),
                const Text(
                  'Reward Points',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    color: Color(0xFFEDEDF2),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gold Balance Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFF5B942).withOpacity(0.22),
                          const Color(0xFF7C4DFF).withOpacity(0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Icon(Icons.star, color: Color(0xFFF5B942), size: 24),
                            const SizedBox(width: 8),
                            Text(
                              _formatNumber(rpBalance),
                              style: const TextStyle(
                                fontFamily: 'Sora',
                                color: Color(0xFFEDEDF2),
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                shadows: [Shadow(color: Color(0xFFF5B942), blurRadius: 24)],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'RP',
                              style: TextStyle(
                                color: Color(0xFFA69FC0),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Reward Points earned through skill games',
                          style: TextStyle(color: Color(0xFFA69FC0), fontSize: 11.5),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: capProgress,
                            minHeight: 8,
                            backgroundColor: Colors.black38,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5B942)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Daily cap: $capUsedToday / $dailyCap RP',
                          style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // History Box
                  const Text(
                    'Recent Activity',
                    style: TextStyle(color: Color(0xFFEDEDF2), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16121F),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: transactions.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text('No game reward points transactions yet.', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            ),
                          )
                        : Column(
                            children: transactions.take(5).map((tx) {
                              final amount = tx['amount'] as int? ?? 0;
                              final isEarn = (tx['type'] == 'earn') || amount > 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tx['title'] ?? 'Game Reward',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Color(0xFFEDEDF2), fontWeight: FontWeight.w700, fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      isEarn ? '+$amount RP' : '$amount RP',
                                      style: TextStyle(
                                        color: isEarn ? const Color(0xFF9FE8C8) : const Color(0xFFE8265C),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Boosters & Game Tools
                  const Text(
                    'Game Boosters',
                    style: TextStyle(color: Color(0xFFEDEDF2), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _boosters.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                    ),
                    itemBuilder: (context, index) {
                      final item = _boosters[index];
                      final grad = item['gradient'] as List<Color>;
                      final isUnlocked = gameProvider.unlockedBoosters.contains(item['id']);

                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16121F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUnlocked ? const Color(0xFF9FE8C8).withOpacity(0.4) : Colors.white.withOpacity(0.10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: grad),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  isUnlocked ? '✓ UNLOCKED' : item['name'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isUnlocked ? 11 : 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item['name'],
                              style: const TextStyle(color: Color(0xFFEDEDF2), fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              item['game'],
                              style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 10),
                            ),
                            const Spacer(),
                            if (isUnlocked)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9FE8C8).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Text('Active', style: TextStyle(color: Color(0xFF9FE8C8), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _buyBooster(context, item, true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5B942).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.5)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${item['rp']} RP',
                                            style: const TextStyle(color: Color(0xFFF5B942), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _buyBooster(context, item, false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${item['coins']} 🪙',
                                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int val) {
    final s = val.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }
}
