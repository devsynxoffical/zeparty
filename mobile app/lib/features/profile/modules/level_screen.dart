import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/user_avatar.dart';
import '../../../../widgets/skeleton_widgets.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/user_model.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({super.key});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Simulate network delay for loading state
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isLoading = false);
    });
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
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.black, // Dark background as per reference
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar with Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Wealth'),
                        Tab(text: 'Charm'),
                        Tab(text: 'Game'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDark)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildWealthTab(isDark, primary, user),
                        _buildCharmTab(isDark, primary, user),
                        _buildGameTab(isDark, primary, user),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SkeletonBox(width: double.infinity, height: 160, borderRadius: 20),
        const SizedBox(height: 30),
        SkeletonBox(width: 150, height: 24, borderRadius: 12),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SkeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 60, borderRadius: 16),
            SkeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 60, borderRadius: 16),
          ],
        )
      ],
    );
  }

  Widget _buildWealthTab(bool isDark, Color primary, UserModel user) {
    int totalXp = 825000000;
    return _buildLevelSystem(
      isDark: isDark,
      title: 'Wealth Level',
      level: user.wealthLevel,
      avatarUrl: user.avatarUrl,
      gradientColors: [const Color(0xFFFFD700), const Color(0xFFFDB931)], // Gold gradient
      currentXp: user.wealthXp,
      totalXp: totalXp,
      nextLevelXPNeeded: 'Need ${_formatNumber(totalXp - user.wealthXp)} EXP to upgrade',
    );
  }

  Widget _buildCharmTab(bool isDark, Color primary, UserModel user) {
    int totalXp = 9000;
    return _buildLevelSystem(
      isDark: isDark,
      title: 'Charm Level',
      level: user.charmLevel,
      avatarUrl: user.avatarUrl,
      gradientColors: [const Color(0xFFFF69B4), const Color(0xFFFF1493)], // Pink gradient
      currentXp: user.charmXp,
      totalXp: totalXp,
      nextLevelXPNeeded: 'Need ${_formatNumber(totalXp - user.charmXp)} EXP to upgrade',
    );
  }

  Widget _buildGameTab(bool isDark, Color primary, UserModel user) {
    int totalXp = 5000;
    return _buildLevelSystem(
      isDark: isDark,
      title: 'Game Level',
      level: user.gameLevel,
      avatarUrl: user.avatarUrl,
      gradientColors: [const Color(0xFF00E5FF), const Color(0xFF00B0FF)], // Cyan gradient
      currentXp: user.gameXp,
      totalXp: totalXp,
      nextLevelXPNeeded: 'Need ${_formatNumber(totalXp - user.gameXp)} EXP to upgrade',
    );
  }

  Widget _buildLevelSystem({
    required bool isDark,
    required String title,
    required int level,
    required String avatarUrl,
    required List<Color> gradientColors,
    required int currentXp,
    required int totalXp,
    required String nextLevelXPNeeded,
  }) {
    return Column(
      children: [
        // Top Banner Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                gradientColors[0].withValues(alpha: 0.9),
                gradientColors[1].withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar with border
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: UserAvatar(
                      imageUrl: avatarUrl,
                      radius: 30,
                      showVipFrame: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Lv. $level',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Lv. ${level + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            nextLevelXPNeeded,
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: currentXp / totalXp),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.black.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (value * totalXp).toInt().toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            totalXp.toString(),
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 10),

        // Bottom Sheet-like Container
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E), // Dark grey similar to screenshot
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTiersGrid(isDark, gradientColors[0], level),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildTiersGrid(bool isDark, Color tierColor, int currentLevel) {
    final List<Map<String, dynamic>> tiers = [
      {'range': 'Lv 1-10', 'min': 1, 'max': 10},
      {'range': 'Lv 11-20', 'min': 11, 'max': 20},
      {'range': 'Lv 21-30', 'min': 21, 'max': 30},
      {'range': 'Lv 31-40', 'min': 31, 'max': 40},
      {'range': 'Lv 41-50', 'min': 41, 'max': 50},
      {'range': 'Lv 51-60', 'min': 51, 'max': 60},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final tier = tiers[index];
        final isCurrentTier = currentLevel >= tier['min'] && currentLevel <= tier['max'];
        final isUnlocked = currentLevel >= tier['min'];
        
        Color bgColor = const Color(0xFF2A2A2A); // Lighter grey for cards
        Color borderColor = Colors.transparent;
        
        if (isCurrentTier) {
          bgColor = tierColor.withValues(alpha: 0.2);
          borderColor = tierColor;
        }

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: isCurrentTier ? 1.5 : 0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked ? tierColor.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.workspace_premium_rounded : Icons.lock_rounded, 
                      color: isUnlocked ? tierColor : Colors.white54,
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tier['range'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.white : Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
