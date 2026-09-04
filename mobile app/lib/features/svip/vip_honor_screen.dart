import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/vip_honor_model.dart';
import '../../providers/vip_honor_provider.dart';
import '../../widgets/design/premium_card.dart';

class VIPHonorScreen extends StatefulWidget {
  const VIPHonorScreen({super.key});

  @override
  State<VIPHonorScreen> createState() => _VIPHonorScreenState();
}

class _VIPHonorScreenState extends State<VIPHonorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final honor = context.watch<VIPHonorProvider>();
    final hof = honor.hallOfFame;
    final rem = hof.remainingDuration;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'VIP Honor & Hall of Fame',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          tabs: const [
            Tab(text: 'VIP Rank'),
            Tab(text: 'Hall of Fame 🏆'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: VIP RANK ───
          _buildVipRankTab(honor, isDark, primary),

          // ─── TAB 2: HALL OF FAME ───
          _buildHallOfFameTab(hof, rem, isDark, primary),
        ],
      ),
    );
  }

  Widget _buildVipRankTab(VIPHonorProvider honor, bool isDark, Color primary) {
    final currentUser = honor.hallOfFame.currentUserRank;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal VIP Standing
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.getPremiumGradient(isDark),
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(currentUser.avatarUrl),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser.nickname,
                        style: TextStyle(
                          color: AppColors.onPrimary(isDark: isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Global Rank #${currentUser.rank} • SVIP ${currentUser.svipLevel}',
                        style: TextStyle(
                          color: AppColors.onPrimary(isDark: isDark).withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppFormatters.formatNumber(currentUser.points)} Honor Points',
                        style: TextStyle(
                          color: AppColors.onPrimary(isDark: isDark),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'VIP Honor Reward Tiers',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
          const SizedBox(height: 12),

          ...honor.hallOfFame.rewardTiers.map((tier) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PremiumCard(
                padding: const EdgeInsets.all(16),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tier.rankRangeText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: primary,
                          ),
                        ),
                        Text(
                          '+${AppFormatters.formatNumber(tier.bonusCoins)} Coins',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tier.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tier.rewardFrame} • ${tier.entranceEffect}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHallOfFameTab(HallOfFameRanking hof, Duration rem, bool isDark, Color primary) {
    return Column(
      children: [
        // Countdown banner
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_rounded, size: 16, color: Colors.orangeAccent),
              const SizedBox(width: 6),
              Text(
                'Season Ends In: ${rem.inDays}d ${rem.inHours % 24}h ${rem.inMinutes % 60}m',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ─── Top 3 Podium ───
                _buildTop3Podium(hof.topPodium, isDark, primary),

                const SizedBox(height: 24),

                // ─── 4th Onward Ranked List ───
                ...hof.listRankings.map((user) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(12),
                      radius: 14,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            alignment: Alignment.center,
                            child: Text(
                              '#${user.rank}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(user.avatarUrl),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(user.countryFlag),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        user.nickname,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.getTextPrimary(isDark),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'SVIP ${user.svipLevel}',
                                  style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${AppFormatters.formatNumber(user.points)} pts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),

        // Sticky Bottom User Rank Bar
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -3)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#${hof.currentUserRank.rank}',
                    style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(hof.currentUserRank.avatarUrl),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hof.currentUserRank.nickname,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
                      ),
                      Text(
                        'SVIP ${hof.currentUserRank.svipLevel} • Top Contributor',
                        style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${AppFormatters.formatNumber(hof.currentUserRank.points)} pts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTop3Podium(List<VIPRankUser> top3, bool isDark, Color primary) {
    if (top3.length < 3) return const SizedBox.shrink();
    final rank1 = top3[0];
    final rank2 = top3[1];
    final rank3 = top3[2];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2 (Left)
        _buildPodiumPillar(rank2, 2, 110, Colors.grey.shade400, '🥈', isDark),
        const SizedBox(width: 10),
        // Rank 1 (Center - Tallest)
        _buildPodiumPillar(rank1, 1, 140, Colors.amber, '👑', isDark),
        const SizedBox(width: 10),
        // Rank 3 (Right)
        _buildPodiumPillar(rank3, 3, 90, Colors.brown.shade400, '🥉', isDark),
      ],
    );
  }

  Widget _buildPodiumPillar(VIPRankUser user, int rank, double height, Color crownColor, String crownIcon, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(crownIcon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          CircleAvatar(
            radius: rank == 1 ? 30 : 24,
            backgroundImage: NetworkImage(user.avatarUrl),
          ),
          const SizedBox(height: 6),
          Text(
            user.nickname,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: AppColors.getTextPrimary(isDark),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${(user.points / 1000000).toStringAsFixed(1)}M pts',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [crownColor.withValues(alpha: 0.6), crownColor.withValues(alpha: 0.2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crownColor, width: 1),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
