import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/lucky_gift_model.dart';
import '../../../../models/gift_model.dart';
import '../../../../core/constants/animated_gifts_catalog.dart';
import '../../../../providers/lucky_gift_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/auth_provider.dart';

class GiftShowcaseScreen extends StatefulWidget {
  const GiftShowcaseScreen({super.key});

  @override
  State<GiftShowcaseScreen> createState() => _GiftShowcaseScreenState();
}

class _GiftShowcaseScreenState extends State<GiftShowcaseScreen> {
  String _selectedWallCategory = 'All';
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

  Widget _buildGiftIcon(String icon, {double size = 36}) {
    if (icon.startsWith('assets/')) {
      return Image.asset(
        icon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Text('🎁', style: TextStyle(fontSize: 24)),
      );
    } else if (icon.startsWith('http')) {
      return Image.network(
        icon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Text('🎁', style: TextStyle(fontSize: 24)),
      );
    }
    return Text(icon, style: TextStyle(fontSize: size * 0.75));
  }

  Widget _buildWallHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.amberAccent, size: 22),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }

  void _showGiftWallItemDialog(BuildContext context, GiftModel gift) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            _buildGiftIcon(gift.icon, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                gift.name,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(isDark)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(isDark),
                  shape: BoxShape.circle,
                ),
                child: _buildGiftIcon(gift.icon, size: 64),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Category:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                Text(gift.category, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Coin Value:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 14),
                    const SizedBox(width: 4),
                    Text('${gift.price} Coins', style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Animation:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                Text(gift.svgaAssetUrl != null ? 'Full MP4 Video' : 'Illustrated Reaction', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            if (gift.luckyBadge != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Jackpot Tier:', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13)),
                  Text(gift.luckyBadge!, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.getPrimary(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(d),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftWall(bool isDark) {
    final categories = ['All', 'Lucky', 'Classic', 'Event', 'Privileges', 'Special'];

    List<GiftModel> filteredGifts;
    if (_selectedWallCategory == 'Lucky') {
      filteredGifts = AnimatedGiftsCatalog.luckyGifts;
    } else if (_selectedWallCategory == 'Classic') {
      filteredGifts = AnimatedGiftsCatalog.classicGifts;
    } else if (_selectedWallCategory == 'Event') {
      filteredGifts = AnimatedGiftsCatalog.eventGifts;
    } else if (_selectedWallCategory == 'Privileges') {
      filteredGifts = AnimatedGiftsCatalog.privilegeGifts;
    } else if (_selectedWallCategory == 'Special') {
      filteredGifts = AnimatedGiftsCatalog.specialGifts;
    } else {
      filteredGifts = AnimatedGiftsCatalog.allGifts;
    }

    final totalValue = AnimatedGiftsCatalog.allGifts.fold<int>(0, (sum, g) => sum + g.price);

    return Column(
      children: [
        // Luxury Wall Header Banner
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A0845), Color(0xFF6441A5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWallHeaderStat('Total Gifts', '${AnimatedGiftsCatalog.allGifts.length}', Icons.card_giftcard),
              _buildWallHeaderStat('Lucky Gifts', '${AnimatedGiftsCatalog.luckyGifts.length}', Icons.casino),
              _buildWallHeaderStat('Wall Value', '${(totalValue / 1000).toStringAsFixed(0)}K 🪙', Icons.monetization_on),
            ],
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: categories.map((cat) {
              final isSelected = _selectedWallCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    cat == 'All'
                        ? 'All (${AnimatedGiftsCatalog.allGifts.length})'
                        : cat == 'Lucky'
                            ? '🍀 Lucky (${AnimatedGiftsCatalog.luckyGifts.length})'
                            : cat == 'Classic'
                                ? 'Classic (${AnimatedGiftsCatalog.classicGifts.length})'
                                : cat == 'Event'
                                    ? 'Event (${AnimatedGiftsCatalog.eventGifts.length})'
                                    : cat == 'Privileges'
                                        ? 'VIP (${AnimatedGiftsCatalog.privilegeGifts.length})'
                                        : 'Special (${AnimatedGiftsCatalog.specialGifts.length})',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.getTextSecondary(isDark),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.getPrimary(isDark),
                  backgroundColor: AppColors.getCard(isDark),
                  onSelected: (val) {
                    if (val) setState(() => _selectedWallCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Grid of gifts
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: filteredGifts.length,
            itemBuilder: (context, index) {
              final gift = filteredGifts[index];
              return InkWell(
                onTap: () => _showGiftWallItemDialog(context, gift),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getCard(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: gift.isLuckyGift
                          ? Colors.amber.withValues(alpha: 0.5)
                          : Colors.purple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGiftIcon(gift.icon, size: 40),
                            const SizedBox(height: 6),
                            Text(
                              gift.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 11),
                                const SizedBox(width: 3),
                                Text(
                                  '${gift.price}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (gift.luckyBadge != null || gift.label != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              gradient: (gift.luckyBadge?.contains('MAX') ?? false)
                                  ? const LinearGradient(colors: [Colors.purple, Colors.pink])
                                  : const LinearGradient(colors: [Colors.amber, Colors.orange]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gift.luckyBadge ?? gift.label ?? 'VIP',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
                      Text('Send Lucky Gifts to win up to 100,000× Coin Jackpots!', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
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

          Text('Available Lucky Gifts (${gifts.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
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
                      child: Text(g.badge, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 8)),
                    ),
                    const SizedBox(height: 2),
                    _buildGiftIcon(g.icon, size: 36),
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
            _buildGiftIcon(gift.icon, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${gift.name} Multipliers', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
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
