import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/repositories/backend_repository.dart';
import '../../providers/region_provider.dart';
import '../search/search_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/country_picker_widget.dart';
import '../../widgets/banner_carousel_widget.dart';
import 'tabs/live_discovery_grid.dart';
import 'tabs/shorts_tab.dart';
import 'tabs/games_tab.dart';
import 'tabs/mine_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Mine', 'Party', 'Live', 'Games', 'PK'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final regionProvider = Provider.of<RegionProvider>(context);
    final backend = Provider.of<BackendRepository>(context);
    
    // Base live rooms from reactive repository
    var liveRooms = backend.liveRooms;
    
    // Apply region filtering
    if (regionProvider.selectedRegionCode != 'GLOBAL') {
      liveRooms = liveRooms.where((r) => r.host.region == regionProvider.selectedRegionCode).toList();
    }

    final primaryColor = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                floating: true,
                backgroundColor: AppColors.getBackground(isDark),
                elevation: 0,
                titleSpacing: 0,
                title: Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: EdgeInsets.zero,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 8),
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    labelColor: primaryColor,
                    unselectedLabelColor: AppColors.getTextSecondary(isDark),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    dividerColor: Colors.transparent,
                    tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 24.w),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_rounded, color: Colors.orange, size: 22.w),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () {
                      // Re-using notifications screen for the calendar/task icon to keep controls functional
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: AppColors.getTextSecondary(isDark), size: 24.w),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Module 09: Party Top Banner Carousel (Full width promotional/event carousel)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: BannerCarouselWidget(
                        isDark: isDark,
                        onPartyTap: () => _tabController.animateTo(1),
                        onLiveTap: () => _tabController.animateTo(2),
                      ),
                    ),
                    
                    // RECOMMEND & COUNTRY PICKER ROW
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Recommend',
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          CountryPickerWidget(isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              MineTab(isDark: isDark),
              // Party Tab: Audio Voice Party Rooms
              LiveDiscoveryGrid(
                liveRooms: liveRooms.where((r) =>
                  r.roomType == 'AUDIO_PARTY' ||
                  r.category.toUpperCase() == 'PARTY' ||
                  r.id.startsWith('party_') ||
                  r.id.startsWith('room-elena')
                ).toList(),
                isDark: isDark,
                isPartyTab: true,
              ),
              // Live Tab: Video Streams & Live Broadcasts
              LiveDiscoveryGrid(
                liveRooms: liveRooms.where((r) =>
                  r.roomType == 'LIVE_VIDEO' ||
                  (r.roomType != 'AUDIO_PARTY' && r.category.toUpperCase() != 'PARTY' && !r.id.startsWith('party_') && !r.id.startsWith('room-elena'))
                ).toList(),
                isDark: isDark,
                isPartyTab: false,
              ),
              GamesTab(isDark: isDark),
              LiveDiscoveryGrid(liveRooms: liveRooms.where((r) => r.category.toUpperCase() == 'PK').toList(), isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }
}
