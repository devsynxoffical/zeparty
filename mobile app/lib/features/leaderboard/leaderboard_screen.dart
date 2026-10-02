import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/api_client.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../profile/user_profile_details_screen.dart';

class RankingEntry {
  final int rank;
  final UserModel user;
  final UserModel? partnerUser;
  final num points;
  final String formattedPoints;
  final String? roomId;
  final String? roomTitle;
  final String? coverImageUrl;
  final int? currentViewersCount;

  RankingEntry({
    required this.rank,
    required this.user,
    this.partnerUser,
    required this.points,
    required this.formattedPoints,
    this.roomId,
    this.roomTitle,
    this.coverImageUrl,
    this.currentViewersCount,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : json;
    final rawPartner = json['partnerUser'] is Map<String, dynamic> ? json['partnerUser'] as Map<String, dynamic> : null;

    final pts = (json['points'] as num?) ?? (json['score'] as num?) ?? 0;
    String formatted = json['formattedPoints']?.toString() ?? '';
    if (formatted.isEmpty) {
      if (pts >= 1000000) {
        formatted = '${(pts / 1000000).toStringAsFixed(1)}M';
      } else if (pts >= 1000) {
        formatted = '${(pts / 1000).toStringAsFixed(1)}K';
      } else {
        formatted = pts.toString();
      }
    }

    return RankingEntry(
      rank: json['rank'] is int ? json['rank'] as int : 1,
      user: UserModel.fromJson(rawUser),
      partnerUser: rawPartner != null ? UserModel.fromJson(rawPartner) : null,
      points: pts,
      formattedPoints: formatted,
      roomId: json['roomId']?.toString(),
      roomTitle: json['roomTitle']?.toString(),
      coverImageUrl: json['coverImageUrl']?.toString(),
      currentViewersCount: json['currentViewersCount'] is int ? json['currentViewersCount'] as int : null,
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _periodIndex = 0;
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];
  final List<String> _categories = ['Room', 'Wealth', 'Charm', 'CP', 'SVIP'];

  final Map<String, List<RankingEntry>> _cache = {};
  final Map<String, bool> _loadingMap = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
        _fetchCurrentRankings();
      }
    });
    _fetchCurrentRankings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentCategoryKey {
    final cat = _categories[_tabController.index].toLowerCase();
    final period = _periods[_periodIndex].toLowerCase();
    return '${cat}_$period';
  }

  Future<void> _fetchCurrentRankings({bool refresh = false}) async {
    final cat = _categories[_tabController.index].toLowerCase();
    final period = _periods[_periodIndex].toLowerCase();
    final key = '${cat}_$period';

    if (!refresh && _cache.containsKey(key) && _cache[key]!.isNotEmpty) {
      return;
    }

    setState(() => _loadingMap[key] = true);

    try {
      final client = ApiClient.instance;
      final res = await client.get<Map<String, dynamic>>(
        '/v1/rankings',
        queryParameters: {
          'category': cat,
          'period': period,
          'limit': 50,
        },
      );

      final rawData = res.data?['data'];
      final List<RankingEntry> loaded = [];
      if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          final item = rawData[i];
          if (item is Map<String, dynamic>) {
            item['rank'] = item['rank'] ?? (i + 1);
            loaded.add(RankingEntry.fromJson(item));
          }
        }
      }

      if (mounted) {
        setState(() {
          _cache[key] = loaded;
          _loadingMap[key] = false;
        });
      }
    } catch (e) {
      debugPrint('[LeaderboardScreen] Fetch error: $e');
      if (mounted) {
        setState(() => _loadingMap[key] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);
    final key = _currentCategoryKey;
    final isLoading = _loadingMap[key] == true;
    final entries = _cache[key] ?? [];

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
              tabs: _categories.map((c) => Tab(text: c)).toList(),
            ),
          ),
        ],
        body: Column(
          children: [
            // Period Filter (Daily, Weekly, Monthly)
            Container(
              color: AppColors.getBackground(isDark),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_periods.length, (i) {
                  final sel = _periodIndex == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _periodIndex = i);
                      _fetchCurrentRankings();
                    },
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

            // Ranking Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchCurrentRankings(refresh: true),
                color: AppColors.primaryGold,
                child: isLoading && entries.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                    : entries.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                              Center(
                                child: Text(
                                  'No rankings recorded for this period yet.',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                                ),
                              ),
                            ],
                          )
                        : _buildRankingList(entries, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList(List<RankingEntry> entries, bool isDark) {
    final top1 = entries.isNotEmpty ? entries[0] : null;
    final top2 = entries.length > 1 ? entries[1] : null;
    final top3 = entries.length > 2 ? entries[2] : null;
    final rest = entries.length > 3 ? entries.sublist(3) : <RankingEntry>[];
    final isCP = _categories[_tabController.index] == 'CP';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ─── PODIUM (Top 1, 2, 3) ───
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
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
              // 2nd Place
              _buildPodiumColumn(
                entry: top2,
                rank: 2,
                podiumHeight: 100,
                avatarRadius: 28,
                color: isDark ? AppColors.metallicGold : AppColors.metallicBlue,
                isDark: isDark,
              ),
              const SizedBox(width: 6),

              // 1st Place
              _buildPodiumColumn(
                entry: top1,
                rank: 1,
                podiumHeight: 135,
                avatarRadius: 36,
                color: isDark ? AppColors.lightGold : AppColors.royalBlue,
                isDark: isDark,
                crown: '👑',
              ),
              const SizedBox(width: 6),

              // 3rd Place
              _buildPodiumColumn(
                entry: top3,
                rank: 3,
                podiumHeight: 80,
                avatarRadius: 24,
                color: isDark ? AppColors.deepBronze : AppColors.lightBlue,
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── RANKINGS LIST (Rank 4+) ───
        ...rest.map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Row(
              children: [
                // Rank Number Pill
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(isDark),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.getBorder(isDark)),
                  ),
                  child: Text(
                    '#${entry.rank}',
                    style: TextStyle(
                      color: AppColors.getTextSecondary(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: entry.user.id)),
                    );
                  },
                  child: UserAvatar(imageUrl: entry.user.avatarUrl, radius: 20),
                ),
                if (isCP && entry.partnerUser != null) ...[
                  const SizedBox(width: 4),
                  const Text('❤️', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  UserAvatar(imageUrl: entry.partnerUser!.avatarUrl, radius: 16),
                ],
                const SizedBox(width: 12),

                // User Display Name & Handle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.user.displayName,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(isDark),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '@${entry.user.username}',
                            style: TextStyle(
                              color: AppColors.getTextSecondary(isDark),
                              fontSize: 11,
                            ),
                          ),
                          if (entry.user.vipLevel.isNotEmpty && entry.user.vipLevel != 'None') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                entry.user.vipLevel,
                                style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Score Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.diamond_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        entry.formattedPoints,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required RankingEntry? entry,
    required int rank,
    required double podiumHeight,
    required double avatarRadius,
    required Color color,
    required bool isDark,
    String? crown,
  }) {
    if (entry == null) {
      return SizedBox(
        width: 85,
        child: Column(
          children: [
            CircleAvatar(radius: avatarRadius, backgroundColor: Colors.white10),
            const SizedBox(height: 8),
            Text('#$rank', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crown != null) Text(crown, style: const TextStyle(fontSize: 20)),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: entry.user.id)),
              );
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                    boxShadow: [
                      BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10),
                    ],
                  ),
                  child: UserAvatar(imageUrl: entry.user.avatarUrl, radius: avatarRadius),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            entry.user.displayName,
            style: TextStyle(
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '💎 ${entry.formattedPoints}',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
