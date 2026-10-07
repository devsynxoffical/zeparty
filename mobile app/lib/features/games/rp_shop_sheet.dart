import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../providers/wallet_provider.dart';

class RpShopSheet extends StatefulWidget {
  const RpShopSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const RpShopSheet(),
    );
  }

  @override
  State<RpShopSheet> createState() => _RpShopSheetState();
}

class _RpShopSheetState extends State<RpShopSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _boosters = [
    {
      'id': 'double_cannon',
      'name': 'Double Cannon',
      'game': 'Fishing',
      'desc': 'Shoot 2 nets per shot for 1 run',
      'rp': 200,
      'coins': 50,
      'icon': Icons.filter_2,
      'color': Color(0xFF00C6FF),
    },
    {
      'id': 'freeze_net',
      'name': 'Freeze Net',
      'game': 'Fishing',
      'desc': 'One manual freeze per wave',
      'rp': 150,
      'coins': 40,
      'icon': Icons.ac_unit,
      'color': Color(0xFF80D8FF),
    },
    {
      'id': 'slow_power_bar',
      'name': 'Golden Sweet Spot Booster',
      'game': 'Football',
      'desc': 'Wider power bar sweet spot area',
      'rp': 150,
      'coins': 40,
      'icon': Icons.speed,
      'color': Color(0xFF38EF7D),
    },
    {
      'id': 'extra_moves',
      'name': 'Extra Moves (+5)',
      'game': 'Fruit Match',
      'desc': '+5 moves in any match level',
      'rp': 150,
      'coins': 30,
      'icon': Icons.add_circle,
      'color': Color(0xFFFF512F),
    },
    {
      'id': 'slow_motion',
      'name': 'Slow Motion (3x)',
      'game': 'Rocket Challenge',
      'desc': 'Slows precision zone for 0.5s',
      'rp': 250,
      'coins': 60,
      'icon': Icons.slow_motion_video,
      'color': Color(0xFF8E2DE2),
    },
    {
      'id': 'start_shield',
      'name': 'Start Shield',
      'game': 'Lion Adventure',
      'desc': 'Begin run with shield bubble',
      'rp': 150,
      'coins': 40,
      'icon': Icons.shield,
      'color': Color(0xFFFFB300),
    },
    {
      'id': 'puzzle_undo',
      'name': 'Undo (3x)',
      'game': 'Seven Puzzle',
      'desc': 'Undo your last placed tile move',
      'rp': 100,
      'coins': 25,
      'icon': Icons.undo,
      'color': Color(0xFFEAAFC8),
    },
  ];

  final List<Map<String, dynamic>> _cosmetics = [
    {
      'id': 'gold_striker_kit',
      'name': 'Gold Striker Kit',
      'game': 'Football',
      'desc': 'Exclusive golden jersey & boots',
      'rp': 800,
      'coins': 150,
      'icon': Icons.sports_soccer,
      'color': Color(0xFFFFD700),
    },
    {
      'id': 'crown_outfit',
      'name': 'King Lion Crown',
      'game': 'Lion Adventure',
      'desc': 'Royal crown outfit for Lion',
      'rp': 1200,
      'coins': 250,
      'icon': Icons.emoji_events,
      'color': Color(0xFFFFD700),
    },
    {
      'id': 'cosmic_trail',
      'name': 'Cosmic Rocket Trail',
      'game': 'Rocket Challenge',
      'desc': 'Glow in deep galaxy stardust',
      'rp': 800,
      'coins': 150,
      'icon': Icons.auto_awesome,
      'color': Color(0xFF00E5FF),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _buyWithRp(BuildContext context, Map<String, dynamic> item) {
    final gameProvider = context.read<GameProvider>();
    final cost = item['rp'] as int;
    final itemId = item['id'] as String;
    final name = item['name'] as String;

    if (gameProvider.rpBalance < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Not enough RP! Play games to earn more Reward Points.'),
        ),
      );
      return;
    }

    final success = gameProvider.spendRp(cost, name, itemId: itemId);
    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF38EF7D),
          content: Text('🎉 Successfully unlocked $name!'),
        ),
      );
    }
  }

  void _buyWithCoins(BuildContext context, Map<String, dynamic> item) {
    final gameProvider = context.read<GameProvider>();
    final walletProvider = context.read<WalletProvider>();
    final cost = item['coins'] as int;
    final itemId = item['id'] as String;
    final name = item['name'] as String;

    if (walletProvider.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Not enough Coins to complete this purchase!'),
        ),
      );
      return;
    }

    final success = gameProvider.purchaseBooster(
      wallet: walletProvider,
      boosterId: itemId,
      boosterName: name,
      coinsCost: cost,
    );
    if (success) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF38EF7D),
          content: Text('🎉 Successfully unlocked $name with Coins!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final userRp = gameProvider.rpBalance;
    final userCoins = walletProvider.coins;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0A12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFFE8265C), width: 1.5)),
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
          const SizedBox(height: 14),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.storefront_rounded, color: Color(0xFFE8265C), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'RP Item Shop',
                      style: TextStyle(
                        fontFamily: 'Sora',
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // User RP Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5B942).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFF5B942), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '$userRp RP',
                            style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // User Coins Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        '$userCoins 🪙',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFE8265C),
            labelColor: const Color(0xFFE8265C),
            unselectedLabelColor: const Color(0xFFA69FC0),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: '⚡ Boosters & Powerups'),
              Tab(text: '✨ Exclusive Cosmetics'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildItemList(_boosters, gameProvider),
                _buildItemList(_cosmetics, gameProvider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<Map<String, dynamic>> items, GameProvider gameProvider) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOwned = gameProvider.unlockedShopItems.contains(item['id']) ||
            gameProvider.unlockedBoosters.contains(item['id']);
        final color = item['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF16121F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOwned ? const Color(0xFF9FE8C8).withOpacity(0.4) : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Icon(item['icon'] as IconData, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item['name'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['game'],
                            style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['desc'],
                      style: const TextStyle(color: Color(0xFFA69FC0), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isOwned)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FE8C8).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF9FE8C8)),
                  ),
                  child: const Text('OWNED', style: TextStyle(color: Color(0xFF9FE8C8), fontWeight: FontWeight.bold, fontSize: 10.5)),
                )
              else
                Column(
                  children: [
                    GestureDetector(
                      onTap: () => _buyWithRp(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5B942).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF5B942).withOpacity(0.5)),
                        ),
                        child: Text(
                          '${item['rp']} RP',
                          style: const TextStyle(color: Color(0xFFF5B942), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _buyWithCoins(context, item),
                      child: Text(
                        '${item['coins']} 🪙',
                        style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
