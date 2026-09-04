import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/cp_ranking_model.dart';
import '../../../../providers/cp_ranking_provider.dart';
import '../../../../providers/privacy_settings_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../widgets/user_avatar.dart';

class CPRankingScreen extends StatefulWidget {
  const CPRankingScreen({super.key});

  @override
  State<CPRankingScreen> createState() => _CPRankingScreenState();
}

class _CPRankingScreenState extends State<CPRankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  void _showCpProfileModal(BuildContext context, CpRankingModel cp, bool isDark) {
    final daysTogether = DateTime.now().difference(cp.anniversaryDate).inDays;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Crown & Ring Tier Title
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💍', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    cp.ringTier,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Overlapping Avatars & CP Level Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UserAvatar(imageUrl: cp.user1.avatarUrl, radius: 36),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('CP Lv.${cp.cpLevel}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  const SizedBox(width: 4),
                  UserAvatar(imageUrl: cp.user2.avatarUrl, radius: 36),
                ],
              ),
              const SizedBox(height: 12),

              // Couple Names
              Text(
                '${cp.user1.name} 💕 ${cp.user2.name}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextPrimary(isDark)),
              ),
              const SizedBox(height: 4),
              Text(
                'Together for $daysTogether Days • Intimacy: ${AppFormatters.formatNumber(cp.intimacyPoints)} ❤️',
                style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
              ),

              const SizedBox(height: 20),

              // Intimacy Boost Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.82,
                  minHeight: 10,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progress to CP Lv.26', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text('82%', style: TextStyle(fontSize: 10, color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 24),

              // Send CP Blessing Gift Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.favorite_rounded, size: 20),
                label: const Text('Send CP Intimacy Blessing (100 🪙)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                onPressed: () {
                  final wallet = context.read<WalletProvider>();
                  final success = wallet.spendCoins(100, 'CP Intimacy Blessing for ${cp.user1.name} & ${cp.user2.name}');
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Insufficient Coins! Please recharge your wallet.')),
                    );
                    return;
                  }

                  context.read<CpRankingProvider>().boostIntimacy(cp.id, 500);
                  Navigator.pop(ctx);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('💖 Sent Intimacy Blessing (+500 Intimacy) to ${cp.user1.name} & ${cp.user2.name}!'),
                      backgroundColor: Colors.pinkAccent,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privacy = context.watch<PrivacySettingsProvider>();
    final rankingProvider = context.watch<CpRankingProvider>();

    final hideCpPrivacy = privacy.hideCpRelationship;
    final rankings = rankingProvider.getFilteredRankings(
      timeframe: 'Daily',
      hideCpPrivacyActive: hideCpPrivacy,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF160E2A), // Deep luxury purple
      appBar: AppBar(
        backgroundColor: const Color(0xFF160E2A),
        elevation: 0,
        title: const Text('CP Relationship Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Hall of Fame'),
          ],
        ),
      ),
      body: hideCpPrivacy
          ? _buildPrivacyHiddenNotice(isDark)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRankingsTab(context, rankings, isDark),
                _buildRankingsTab(context, rankings, isDark),
                _buildRankingsTab(context, rankings, isDark),
                _buildRankingsTab(context, rankings, isDark),
              ],
            ),
      bottomNavigationBar: _buildMyRankPinnedBar(context, rankings, isDark),
    );
  }

  Widget _buildPrivacyHiddenNotice(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.visibility_off_rounded, size: 64, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'CP Leaderboard Hidden by Privacy Flag',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'You have enabled "Hide CP Relationship" in Privacy Settings. Disable it to view and feature on public CP rankings.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRankPinnedBar(BuildContext context, List<CpRankingModel> rankings, bool isDark) {
    if (rankings.isEmpty) return const SizedBox.shrink();
    final myCp = rankings.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22113D),
        border: const Border(top: BorderSide(color: Colors.amberAccent, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'My Rank #${myCp.rank}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${myCp.user1.name} 💕 ${myCp.user2.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Intimacy: ${AppFormatters.formatNumber(myCp.intimacyPoints)} ❤️ • Leaderboard Pair',
                    style: const TextStyle(color: Colors.amberAccent, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                minimumSize: const Size(60, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _showCpProfileModal(context, myCp, isDark),
              child: const Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingsTab(BuildContext context, List<CpRankingModel> rankings, bool isDark) {
    if (rankings.isEmpty) {
      return const Center(
        child: Text('No active CP rankings available.', style: TextStyle(color: Colors.white54)),
      );
    }

    final top3 = rankings.take(3).toList();
    final remaining = rankings.skip(3).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // ── Top 3 Podium Cards ──
          if (top3.isNotEmpty) _buildTopPodium(context, top3, isDark),

          const SizedBox(height: 20),

          // ── Remaining Leaderboard List (Rank #4+) ──
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: remaining.length,
            itemBuilder: (ctx, idx) {
              final cp = remaining[idx];
              return _buildLeaderboardTile(context, cp, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopPodium(BuildContext context, List<CpRankingModel> top3, bool isDark) {
    final rank1 = top3.isNotEmpty ? top3[0] : null;
    final rank2 = top3.length > 1 ? top3[1] : null;
    final rank3 = top3.length > 2 ? top3[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2C164D), const Color(0xFF190C2F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (rank2 != null) _buildPodiumItem(context, rank2, 2, 70, isDark),
          if (rank1 != null) _buildPodiumItem(context, rank1, 1, 85, isDark),
          if (rank3 != null) _buildPodiumItem(context, rank3, 3, 65, isDark),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(BuildContext context, CpRankingModel cp, int rankPosition, double size, bool isDark) {
    Color rankColor = Colors.amberAccent;
    String crownEmoji = '👑';
    if (rankPosition == 2) {
      rankColor = const Color(0xFFC0C0C0);
      crownEmoji = '🥈';
    } else if (rankPosition == 3) {
      rankColor = const Color(0xFFCD7F32);
      crownEmoji = '🥉';
    }

    return GestureDetector(
      onTap: () => _showCpProfileModal(context, cp, isDark),
      child: Column(
        children: [
          Text(crownEmoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),

          // Overlapping Avatars
          SizedBox(
            width: size * 1.5,
            height: size,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: UserAvatar(imageUrl: cp.user1.avatarUrl, radius: size / 2.2),
                ),
                Positioned(
                  right: 0,
                  child: UserAvatar(imageUrl: cp.user2.avatarUrl, radius: size / 2.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Names
          SizedBox(
            width: size * 1.6,
            child: Text(
              '${cp.user1.name.split(' ').first} & ${cp.user2.name.split(' ').first}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),

          // Intimacy Points Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text(
                  AppFormatters.formatNumber(cp.intimacyPoints),
                  style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTile(BuildContext context, CpRankingModel cp, bool isDark) {
    return Card(
      color: const Color(0xFF22133B),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        onTap: () => _showCpProfileModal(context, cp, isDark),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('#${cp.rank}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 12),
            SizedBox(
              width: 54,
              height: 36,
              child: Stack(
                children: [
                  Positioned(left: 0, child: UserAvatar(imageUrl: cp.user1.avatarUrl, radius: 18)),
                  Positioned(right: 0, child: UserAvatar(imageUrl: cp.user2.avatarUrl, radius: 18)),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          '${cp.user1.name} 💕 ${cp.user2.name}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${cp.ringTier} • CP Lv.${cp.cpLevel}',
          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.pinkAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${AppFormatters.formatNumber(cp.intimacyPoints)} ❤️',
            style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }
}
