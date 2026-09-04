import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/lucky_gift_model.dart';
import '../../../../providers/lucky_gift_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/auth_provider.dart';

class GiftShowcaseScreen extends StatefulWidget {
  const GiftShowcaseScreen({super.key});

  @override
  State<GiftShowcaseScreen> createState() => _GiftShowcaseScreenState();
}

class _GiftShowcaseScreenState extends State<GiftShowcaseScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(isDark),
          title: Text('Gift Center & Gallery', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
          iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
          bottom: TabBar(
            labelColor: primary,
            unselectedLabelColor: AppColors.getTextSecondary(isDark),
            indicatorColor: primary,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Gift Showcase'),
              Tab(text: 'Gift Wall'),
              Tab(text: '🍀 Lucky Gifts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGiftShowcase(isDark),
            _buildGiftWall(isDark),
            _buildLuckyGiftsTab(context, isDark, primary),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftShowcase(bool isDark) {
    final gifts = [
      {'name': 'Rose', 'icon': '🌹', 'count': 1420, 'rarity': 'Common', 'level': 'Lv. 1'},
      {'name': 'Diamond', 'icon': '💎', 'count': 56, 'rarity': 'Rare', 'level': 'Lv. 3'},
      {'name': 'Crown', 'icon': '👑', 'count': 12, 'rarity': 'Epic', 'level': 'Lv. 5'},
      {'name': 'Heart', 'icon': '❤️', 'count': 890, 'rarity': 'Common', 'level': 'Lv. 2'},
      {'name': 'Rocket', 'icon': '🚀', 'count': 5, 'rarity': 'Legendary', 'level': 'Lv. 6'},
      {'name': 'Star', 'icon': '⭐', 'count': 320, 'rarity': 'Uncommon', 'level': 'Lv. 2'},
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.getCard(isDark),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Unique Gifts', '6', isDark),
              _buildStatColumn('Total Received', '2.7K', isDark),
              _buildStatColumn('Showcase Lv.', '4', isDark),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final gift = gifts[index];
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(gift['icon'] as String, style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 6),
                    Text(gift['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    Text('x${gift['count']}', style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGiftWall(bool isDark) {
    return Center(child: Text('Gift Wall Collection', style: TextStyle(color: AppColors.getTextPrimary(isDark))));
  }

  // ── Module 20: Lucky Gifts Category & Send Flow ──
  Widget _buildLuckyGiftsTab(BuildContext context, bool isDark, Color primary) {
    final luckyProv = context.watch<LuckyGiftProvider>();
    final wallet = context.watch<WalletProvider>();
    final authUser = context.watch<AuthProvider>().currentUser;
    final gifts = luckyProv.luckyGifts;
    final marquee = luckyProv.roomMarqueeAnnouncements;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFFFF416C)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.casino_rounded, color: Colors.amberAccent, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lucky Gifts Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Send Lucky Gifts to win up to 1000× Coin Jackpots!', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Room Marquee Announcements (if any win >= 10x)
          if (marquee.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent)),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      marquee.first['text'] as String,
                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Text('Available Lucky Gifts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: gifts.length,
            itemBuilder: (ctx, idx) {
              final g = gifts[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                      child: Text(g.badge, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9)),
                    ),
                    const SizedBox(height: 2),
                    Text(g.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 2),
                    Text(
                      g.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.getTextPrimary(isDark)),
                    ),
                    Text(
                      '${g.coinPrice} Coins',
                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: () => _showLuckyGiftInfoDialog(context, g),
                          child: const Icon(Icons.info_outline, size: 18, color: Colors.blueAccent),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(40, 26),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final res = await luckyProv.sendLuckyGift(
                              gift: g,
                              senderId: authUser.id,
                              senderName: authUser.name,
                              recipientId: 'user_1002',
                              recipientName: 'Sophia Rose',
                              quantity: 1,
                              wallet: wallet,
                            );

                            if (res != null) {
                              messenger.showSnackBar(SnackBar(
                                content: Text('🎰 Lucky Result: Won ${res.multiplierWon}× (${res.coinsWon} Coins)!'),
                                backgroundColor: res.multiplierWon >= 10 ? Colors.amber.shade800 : Colors.green,
                              ));
                            } else {
                              messenger.showSnackBar(const SnackBar(content: Text('❌ Insufficient coin balance!'), backgroundColor: Colors.redAccent));
                            }
                          },
                          child: const Text('Send', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildStatColumn(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
      ],
    );
  }

  void _showLuckyGiftInfoDialog(BuildContext context, LuckyGiftModel gift) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: Row(
          children: [
            Text(gift.icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text('${gift.name} Multipliers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price: ${gift.coinPrice} Coins per gift', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Server Authoritative Multiplier Table:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            ...gift.rewardTable.map((t) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Text('${(t.probability * 100).toStringAsFixed(0)}% chance', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
        ],
      ),
    );
  }
}
