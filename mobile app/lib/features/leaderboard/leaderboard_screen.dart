import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/repositories/backend_repository.dart';
import '../../widgets/user_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _periodIndex = 0;
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: AppColors.getBackground(isDark),
            pinned: true,
            floating: false,
            expandedHeight: 56,
            centerTitle: true,
            title: Text(
              '🏆 Global Rankings',
              style: TextStyle(
                color: AppColors.getTextPrimary(isDark),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: primary,
              labelColor: primary,
              unselectedLabelColor: AppColors.getTextSecondary(isDark),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Room'),
                Tab(text: 'Wealth'),
                Tab(text: 'Charm'),
                Tab(text: 'CP'),
                Tab(text: 'SVIP'),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            // Period Filter
            Container(
              color: AppColors.getBackground(isDark),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_periods.length, (i) {
                  final sel = _periodIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _periodIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: sel ? AppColors.getAccentGradient(isDark) : null,
                        color: sel ? null : AppColors.getCard(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel ? Colors.transparent : AppColors.getBorder(isDark),
                        ),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        _periods[i],
                        style: TextStyle(
                          color: sel
                              ? AppColors.onGold(isDark: isDark)
                              : AppColors.getTextSecondary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Tab views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _LeaderList(isDark: isDark, isGifter: true, periodIndex: _periodIndex), // Room
                  _LeaderList(isDark: isDark, isGifter: true, periodIndex: _periodIndex), // Wealth
                  _LeaderList(isDark: isDark, isGifter: false, periodIndex: _periodIndex), // Charm
                  _LeaderList(isDark: isDark, isGifter: true, periodIndex: _periodIndex, isCP: true), // CP
                  _LeaderList(isDark: isDark, isGifter: false, periodIndex: _periodIndex), // SVIP
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderList extends StatelessWidget {
  final bool isDark;
  final bool isGifter;
  final int periodIndex;
  final bool isCP;

  const _LeaderList({
    required this.isDark,
    required this.isGifter,
    required this.periodIndex,
    this.isCP = false,
  });

  @override
  Widget build(BuildContext context) {
    final users = BackendRepository.instance.popularUsers;
    if (users.isEmpty) return const Center(child: Text('No data yet'));

    final top1 = users[0];
    final top2 = users.length > 1 ? users[1] : users[0];
    final top3 = users.length > 2 ? users[2] : users[0];

    final multiplier = [1.0, 0.7, 0.5][periodIndex];
    final primary = AppColors.getPrimary(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // ─── PODIUM ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSecondarySurface]
                    : [AppColors.lightBlue, AppColors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: AppColors.primaryGlow(isDark, alpha: 0.12, blur: 24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 2nd
                _PodiumColumn(
                  isDark: isDark,
                  user: top2,
                  rank: 2,
                  podiumHeight: 100,
                  avatarRadius: 28,
                  color: isDark ? AppColors.metallicGold : AppColors.metallicBlue,
                  diamonds: '${(85.4 * multiplier).toStringAsFixed(1)}K 💎',
                ),
                const SizedBox(width: 6),
                // 1st
                _PodiumColumn(
                  isDark: isDark,
                  user: top1,
                  rank: 1,
                  podiumHeight: 140,
                  avatarRadius: 38,
                  color: isDark ? AppColors.lightGold : AppColors.royalBlue,
                  diamonds: '${(142.8 * multiplier).toStringAsFixed(1)}K 💎',
                  crown: '👑',
                ),
                const SizedBox(width: 6),
                // 3rd
                _PodiumColumn(
                  isDark: isDark,
                  user: top3,
                  rank: 3,
                  podiumHeight: 80,
                  avatarRadius: 24,
                  color: isDark ? AppColors.deepBronze : AppColors.lightBlue,
                  diamonds: '${(54.1 * multiplier).toStringAsFixed(1)}K 💎',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── RANK LIST 4+ ───
          ...List.generate(users.length > 10 ? 10 : users.length, (index) {
            final user = users[index];
            final user2 = isCP ? users[(index + 1) % users.length] : null; // Simulated CP Partner

            final rankColors = isDark
                ? [
                    AppColors.warmGold,
                    AppColors.metallicGold,
                    AppColors.deepBronze,
                  ]
                : [
                    AppColors.royalBlue,
                    AppColors.metallicBlue,
                    AppColors.lightBlue,
                  ];
            final isTop3 = index < 3;
            final rankColor = isTop3 ? rankColors[index] : AppColors.getTextSecondary(isDark);
            final gifts = ((45 - index * 4) * multiplier).toStringAsFixed(0);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isTop3
                      ? rankColor.withValues(alpha: 0.3)
                      : AppColors.getBorder(isDark),
                ),
                boxShadow: isTop3
                    ? [
                        BoxShadow(
                          color: rankColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isTop3 ? AppColors.getPremiumGradient(isDark) : null,
                      color: isTop3 ? null : AppColors.getSurface(isDark),
                      shape: BoxShape.circle,
                      border: isTop3
                          ? null
                          : Border.all(color: AppColors.getBorder(isDark)),
                    ),
                    child: Center(
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: isTop3 ? AppColors.onPrimary(isDark: isDark) : rankColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isCP && user2 != null) ...[
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(imageUrl: user.avatarUrl, radius: 22, showVipFrame: index < 3),
                        Positioned(
                          left: 20,
                          child: UserAvatar(imageUrl: user2.avatarUrl, radius: 22, showVipFrame: false),
                        ),
                      ],
                    ),
                    const SizedBox(width: 32),
                  ] else ...[
                    UserAvatar(imageUrl: user.avatarUrl, radius: 22, showVipFrame: index < 3),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCP && user2 != null ? '${user.name} & ${user2.name}' : user.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isCP ? 'Top Couple' : '@${user.username}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$gifts K',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: primary,
                        ),
                      ),
                      Text(
                        isGifter ? 'gifted 💎' : 'received 💎',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final bool isDark;
  final dynamic user;
  final int rank;
  final double podiumHeight;
  final double avatarRadius;
  final Color color;
  final String diamonds;
  final String? crown;

  const _PodiumColumn({
    required this.isDark,
    required this.user,
    required this.rank,
    required this.podiumHeight,
    required this.avatarRadius,
    required this.color,
    required this.diamonds,
    this.crown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (crown != null)
          Text(crown!, style: const TextStyle(fontSize: 26))
        else
          const SizedBox(height: 34),
        UserAvatar(imageUrl: user.avatarUrl, radius: avatarRadius, showVipFrame: true),
        const SizedBox(height: 6),
        Text(
          user.name.split(' ').first,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          diamonds,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 86,
          height: podiumHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                color: color,
                fontSize: rank == 1 ? 26 : 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
