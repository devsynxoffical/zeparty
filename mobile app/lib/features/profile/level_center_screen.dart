import '../../core/utils/wealth_level_helper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/svip_provider.dart';
import '../svip/svip_center_screen.dart';


class LevelCenterScreen extends StatefulWidget {
  final int initialTab;

  const LevelCenterScreen({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<LevelCenterScreen> createState() => _LevelCenterScreenState();
}

class _LevelCenterScreenState extends State<LevelCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().currentUser;
    final svip = context.watch<SVIPProvider>();


    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Level Center & Tiers', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent),
            tooltip: 'SVIP Privilege Center',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen()));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Wealth'),
            Tab(text: 'Charm'),
            Tab(text: 'Game'),
            Tab(text: 'Account'),
            Tab(text: 'SVIP Tier'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Wealth Track (Sending History)
          () {
            final wealthProgress = WealthLevelHelper.getProgress(user.wealthXp);
            return _buildLevelTrackView(
              context,
              title: 'Wealth Level Track',
              subtitle: 'Calculated from total sending history & gifts',
              level: wealthProgress.currentLevel,
              currentXp: wealthProgress.progressInLevel,
              requiredXp: wealthProgress.additionalRequired,
              isMax: wealthProgress.isMax,
              nextLevel: wealthProgress.nextLevel,
              customProgressRatio: wealthProgress.progressRatio,
              icon: Icons.diamond_rounded,
              imagePath: 'assets/images/level_logo_wealth.png',
              color: const Color(0xFF00E5FF),
              perks: [
                '💎 Gold Crown Mic Frame',
                '👑 Wealth Rank Leaderboard Badge',
                '✨ High-Value Room Entry Banner',
                '💬 Highlighted Gold Chat Bubble',
                '⚡ Seating Priority in Voice Rooms',
              ],
              isDark: isDark,
            );
          }(),

          // 2. Charm Track (Receiving History)
          _buildLevelTrackView(
            context,
            title: 'Charm Level Track',
            subtitle: 'Calculated from gifts received & popularity',
            level: user.computedCharmLevel,
            currentXp: user.computedCharmLevel >= 100 ? 0 : user.charmLevelXp,
            requiredXp: user.computedCharmLevel >= 100 ? 0 : 10000,
            isMax: user.computedCharmLevel >= 100,
            nextLevel: user.computedCharmLevel >= 100 ? null : user.computedCharmLevel + 1,
            icon: Icons.favorite_rounded,
            imagePath: 'assets/images/level_logo_charm.png',
            color: const Color(0xFFFF4081),
            perks: [
              '💖 Sweet Heart Avatar Frame',
              '🌹 Charm Superstar Rank Badge',
              '🎉 Popularity Entry Announcement',
              '🎙️ Stage Host Mic Glow Effect',
            ],
            isDark: isDark,
          ),

          // 3. Game Track (Game Volume & Win History)
          _buildLevelTrackView(
            context,
            title: 'Game Level Track',
            subtitle: 'Calculated from game participation & win volume',
            level: user.computedGameLevel,
            currentXp: user.computedGameLevel >= 100 ? 0 : user.gameLevelXp,
            requiredXp: user.computedGameLevel >= 100 ? 0 : 10000,
            isMax: user.computedGameLevel >= 100,
            nextLevel: user.computedGameLevel >= 100 ? null : user.computedGameLevel + 1,
            icon: Icons.sports_esports_rounded,
            imagePath: 'assets/images/level_logo_game.png',
            color: const Color(0xFFB388FF),
            perks: [
              '🎮 Game Master Profile Badge',
              '🎰 Super Wheel Spin Multiplier Boost',
              '🚀 Rocket Launch Bonus Coins',
              '🏆 Victory Soundboard Sound Unlock',
            ],
            isDark: isDark,
          ),

          // 4. Account Level Track (Overall Platform Activity)
          _buildLevelTrackView(
            context,
            title: 'Account Level Track',
            subtitle: 'Calculated from total platform activity & tenure',
            level: user.computedAccountLevel,
            currentXp: user.computedAccountLevel >= 100 ? 0 : user.accountLevelXp,
            requiredXp: user.computedAccountLevel >= 100 ? 0 : 10000,
            isMax: user.computedAccountLevel >= 100,
            nextLevel: user.computedAccountLevel >= 100 ? null : user.computedAccountLevel + 1,
            icon: Icons.stars_rounded,
            imagePath: 'assets/images/level_logo_account.png',
            color: const Color(0xFF00E676),
            perks: [
              '⭐ Veteran Account Status Badge',
              '🛡️ Enhanced Profile Security Perks',
              '🎁 Daily Loyalty Bonus Multiplier',
              '💬 Priority Customer Support Response',
            ],
            isDark: isDark,
          ),

          // 5. SVIP Track
          _buildSvipTrackView(context, user, svip, isDark),
        ],
      ),
    );
  }

  Widget _buildLevelTrackView(
    BuildContext context, {
    required String title,
    required String subtitle,
    required int level,
    required int currentXp,
    required int requiredXp,
    required IconData icon,
    String? imagePath,
    required Color color,
    required List<String> perks,
    required bool isDark,
    bool isMax = false,
    int? nextLevel,
    double? customProgressRatio,
  }) {
    final effectiveLevel = level.clamp(1, 100);
    final bool effectiveIsMax = isMax || effectiveLevel >= 100;
    final progress = customProgressRatio ?? (requiredXp > 0 ? (currentXp / requiredXp).clamp(0.0, 1.0) : 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), const Color(0xFF1E1938)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: imagePath != null
                      ? Image.asset(imagePath, width: 36, height: 36,
                          errorBuilder: (_, __, ___) => Icon(icon, size: 28, color: color))
                      : Icon(icon, size: 28, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      const SizedBox(height: 8),
                      Text(
                        effectiveIsMax ? 'Active Level: Lv. 100 (MAX)' : 'Active Level: Lv. $effectiveLevel',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Server-Authoritative Progress Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Server XP Progression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      effectiveIsMax
                          ? 'Lv. 100 ➔ MAX'
                          : 'Lv. $effectiveLevel ➔ Lv. ${nextLevel ?? (effectiveLevel + 1)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: effectiveIsMax ? 1.0 : progress,
                    minHeight: 10,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      effectiveIsMax
                          ? 'Current XP: MAX'
                          : 'Current XP: ${AppFormatters.formatNumber(currentXp)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      effectiveIsMax
                          ? 'Target XP: MAX'
                          : 'Target XP: ${AppFormatters.formatNumber(requiredXp)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Unlocked Perks Section
          Text('Unlocked Privileges & Perks', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),

          ...perks.map((p) => Card(
                color: AppColors.getCard(isDark),
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.check_circle_rounded, color: color),
                  title: Text(p, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.getTextPrimary(isDark))),
                  subtitle: const Text('Server Authoritative Privilege Unlocked', style: TextStyle(fontSize: 10, color: Colors.greenAccent)),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSvipTrackView(BuildContext context, UserModel user, SVIPProvider svip, bool isDark) {
    final expiry = svip.expiryDate;
    final formattedExpiry = '${expiry.year}.${expiry.month.toString().padLeft(2, '0')}.${expiry.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SVIP Tier Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('SVIP ${svip.currentLevel}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    const Text('👑', style: TextStyle(fontSize: 32)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Active Points: ${AppFormatters.formatNumber(svip.currentPoints)} Points', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Renewal Countdown: Expires on $formattedExpiry', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen()));
                  },
                  child: const Text('Open SVIP Privilege Center ➔', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text('SVIP Tier Roadmap & Privilege Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
          const SizedBox(height: 10),

          ...svip.levels.take(6).map((lvl) {
            final isUnlocked = lvl.level <= svip.currentLevel;
            return Card(
              color: AppColors.getCard(isDark),
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isUnlocked ? Colors.amberAccent : Colors.white12,
                  child: Icon(Icons.workspace_premium_rounded, color: isUnlocked ? Colors.black : Colors.grey),
                ),
                title: Text(lvl.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                subtitle: Text('Required: ${AppFormatters.formatNumber(lvl.requiredPoints)} Points', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: Text(
                  isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(color: isUnlocked ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
