import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/noble_badge_helper.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/user_model.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _equippedTitleName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    _equippedTitleName ??= (user.nobleTitle != null && user.nobleTitle!.isNotEmpty && user.nobleTitle != 'none')
        ? user.nobleTitle
        : (user.svipLevel > 0 ? 'SVIP ${user.svipLevel}' : null);

    final nobleItems = _buildNobleTitles(user);
    final svipItems = _buildSvipTitles(user);
    final roleItems = _buildRoleTitles(user);
    final customItems = _buildCustomTitles(user);

    final allItems = [...customItems, ...nobleItems, ...svipItems, ...roleItems];

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        title: Text(
          'My Titles',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.getTextPrimary(isDark)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'All Titles'),
            Tab(text: 'Nobility'),
            Tab(text: 'SVIP Honors'),
            Tab(text: 'Privileges & Roles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTitleList(allItems, user, isDark, primary),
          _buildTitleList(nobleItems, user, isDark, primary),
          _buildTitleList(svipItems, user, isDark, primary),
          _buildTitleList([...roleItems, ...customItems], user, isDark, primary),
        ],
      ),
    );
  }

  List<_TitleModel> _buildNobleTitles(UserModel user) {
    final currentNobleTier = NobleBadgeHelper.getTierFromTitle(user.nobleTitle);
    final nobleRanks = [
      {'name': 'Emperor', 'tier': NobleTier.emperor, 'badge': 'assets/nobles/emperor_badge.webp', 'color': const Color(0xFFFFD700), 'req': 'Aristocracy Tier: Emperor'},
      {'name': 'King', 'tier': NobleTier.king, 'badge': 'assets/nobles/king_badge.webp', 'color': const Color(0xFFD4AF37), 'req': 'Aristocracy Tier: King'},
      {'name': 'Prince', 'tier': NobleTier.prince, 'badge': 'assets/nobles/king_badge.webp', 'color': const Color(0xFFE040FB), 'req': 'Aristocracy Tier: Prince'},
      {'name': 'Duke', 'tier': NobleTier.duke, 'badge': 'assets/nobles/duke_badge.webp', 'color': const Color(0xFF8E24AA), 'req': 'Aristocracy Tier: Duke'},
      {'name': 'Marquis', 'tier': NobleTier.marquis, 'badge': 'assets/nobles/marquis_badge.webp', 'color': const Color(0xFFC2185B), 'req': 'Aristocracy Tier: Marquis'},
      {'name': 'Count', 'tier': NobleTier.earl, 'badge': 'assets/nobles/count_badge.webp', 'color': const Color(0xFF1E88E5), 'req': 'Aristocracy Tier: Count'},
      {'name': 'Viscount', 'tier': NobleTier.viscount, 'badge': 'assets/nobles/viscount_badge.webp', 'color': const Color(0xFFFB8C00), 'req': 'Aristocracy Tier: Viscount'},
      {'name': 'Baron', 'tier': NobleTier.knight, 'badge': 'assets/nobles/baron_badge.webp', 'color': const Color(0xFF78909C), 'req': 'Aristocracy Tier: Baron / Knight'},
    ];

    return nobleRanks.map((r) {
      final tier = r['tier'] as NobleTier;
      final isUnlocked = currentNobleTier != NobleTier.none && currentNobleTier.index >= tier.index;
      return _TitleModel(
        name: r['name'] as String,
        category: 'Nobility',
        badgeAsset: r['badge'] as String,
        color: r['color'] as Color,
        requirement: r['req'] as String,
        isUnlocked: isUnlocked,
      );
    }).toList();
  }

  List<_TitleModel> _buildSvipTitles(UserModel user) {
    final svipLevel = user.svipLevel;
    final svipList = <_TitleModel>[];

    for (int lvl = 1; lvl <= 9; lvl++) {
      final badgeAsset = NobleBadgeHelper.getBadgeAsset('SVIP $lvl') ?? 'assets/svip/svip1_badge.webp';
      final isUnlocked = svipLevel >= lvl;
      svipList.add(_TitleModel(
        name: 'SVIP $lvl',
        category: 'SVIP',
        badgeAsset: badgeAsset,
        color: lvl >= 7 ? const Color(0xFFFF4081) : (lvl >= 4 ? const Color(0xFF9C27B0) : const Color(0xFF3F51B5)),
        requirement: 'Requires SVIP Level $lvl Status',
        isUnlocked: isUnlocked,
      ));
    }

    return svipList;
  }

  List<_TitleModel> _buildRoleTitles(UserModel user) {
    return [
      _TitleModel(
        name: 'Official Host',
        category: 'Privilege',
        badgeAsset: 'assets/roles/host_badge.webp',
        color: const Color(0xFFFF5722),
        requirement: 'Verified Live Broadcaster',
        isUnlocked: user.isHost,
      ),
      _TitleModel(
        name: 'Coin Seller',
        category: 'Privilege',
        badgeAsset: 'assets/roles/coins_saller_tag.webp',
        color: const Color(0xFFFFB300),
        requirement: 'Official Reseller Authorization',
        isUnlocked: user.isSeller,
      ),
      _TitleModel(
        name: 'Agency Director',
        category: 'Privilege',
        badgeAsset: 'assets/roles/agency_tag.webp',
        color: const Color(0xFF00ACC1),
        requirement: 'Authorized Agency Guild',
        isUnlocked: user.isAgency,
      ),
      _TitleModel(
        name: 'BD Center',
        category: 'Privilege',
        badgeAsset: 'assets/roles/bd_tag.webp',
        color: const Color(0xFF43A047),
        requirement: 'Business Development Agent',
        isUnlocked: user.isBd,
      ),
      _TitleModel(
        name: 'Platform Admin',
        category: 'Privilege',
        badgeAsset: 'assets/roles/admin_badge.webp',
        color: const Color(0xFFE53935),
        requirement: 'Platform Administrator Privilege',
        isUnlocked: user.role == UserRole.admin,
      ),
    ];
  }

  List<_TitleModel> _buildCustomTitles(UserModel user) {
    if (user.customTitles.isEmpty) return [];
    return user.customTitles.map((t) {
      return _TitleModel(
        name: t,
        category: 'Special',
        badgeAsset: null,
        color: const Color(0xFFE91E63),
        requirement: 'Exclusively Assigned by Platform',
        isUnlocked: true,
      );
    }).toList();
  }

  Widget _buildTitleList(List<_TitleModel> items, UserModel user, bool isDark, Color primary) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.military_tech_outlined, size: 56, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No titles available in this category',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isEquipped = _equippedTitleName != null &&
            _equippedTitleName!.toLowerCase().trim() == item.name.toLowerCase().trim();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isEquipped
                  ? primary
                  : (item.isUnlocked ? item.color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05)),
              width: isEquipped ? 1.8 : 1.0,
            ),
            boxShadow: isEquipped
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Badge or Icon
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: item.isUnlocked
                        ? item.color.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.isUnlocked ? item.color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: item.badgeAsset != null
                      ? Image.asset(
                          item.badgeAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.military_tech,
                            color: item.isUnlocked ? item.color : Colors.grey,
                            size: 26,
                          ),
                        )
                      : Icon(
                          Icons.military_tech,
                          color: item.isUnlocked ? item.color : Colors.grey,
                          size: 26,
                        ),
                ),
                const SizedBox(width: 14),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                color: item.isUnlocked ? AppColors.getTextPrimary(isDark) : Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: item.isUnlocked ? 0.2 : 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                color: item.isUnlocked ? item.color : Colors.grey,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.requirement,
                        style: TextStyle(
                          color: item.isUnlocked ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Action Button
                if (item.isUnlocked)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _equippedTitleName = item.name;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Equipped "${item.name}" Title'),
                          backgroundColor: primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped ? Colors.grey[800] : primary,
                      foregroundColor: isEquipped ? Colors.white70 : AppColors.onPrimary(isDark: isDark),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(70, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: isEquipped ? 0 : 2,
                    ),
                    child: Text(
                      isEquipped ? 'Equipped' : 'Equip',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TitleModel {
  final String name;
  final String category;
  final String? badgeAsset;
  final Color color;
  final String requirement;
  final bool isUnlocked;

  const _TitleModel({
    required this.name,
    required this.category,
    this.badgeAsset,
    required this.color,
    required this.requirement,
    required this.isUnlocked,
  });
}
