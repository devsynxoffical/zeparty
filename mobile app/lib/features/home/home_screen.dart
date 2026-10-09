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
import '../../providers/notification_provider.dart';
import '../../widgets/country_picker_widget.dart';
import '../../widgets/banner_carousel_widget.dart';
import 'tabs/live_discovery_grid.dart';
import 'tabs/mine_tab.dart';
import 'tabs/shorts_tab.dart';
import 'tabs/games_tab.dart';
import '../../providers/auth_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BackendRepository.instance.fetchLiveRooms();
    });
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
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser.id;
    
    // Base live rooms from reactive repository
    var liveRooms = backend.liveRooms;
    
    // Apply region filtering with country code and flag matching fallback
    if (regionProvider.selectedRegionCode != 'GLOBAL') {
      final filtered = liveRooms.where((r) {
        final hostReg = r.host.region.toUpperCase();
        final hostCountry = r.host.cleanCountryName.toUpperCase();
        final target = regionProvider.selectedRegionCode.toUpperCase();
        return hostReg.contains(target) || hostCountry.contains(target) || r.host.countryFlag == regionProvider.selectedRegionFlag;
      }).toList();
      if (filtered.isNotEmpty) {
        liveRooms = filtered;
      }
    }

    final primaryColor = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        bottom: false,
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
                  Builder(
                    builder: (ctx) {
                      final notifProv = ctx.watch<NotificationProvider>();
                      final unread = notifProv.unreadCount;
                      return Stack(
                        alignment: Alignment.topRight,
                        children: [
                          IconButton(
                            icon: Icon(Icons.notifications_rounded, color: Colors.orange, size: 22.w),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                              );
                            },
                          ),
                          if (unread > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: const BoxDecoration(
                                  color: AppColors.liveRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                    // Module 09: Party Top Banner Carousel
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
              // 1. Mine Tab: User's owned / hosted rooms
              MineTab(isDark: isDark),

              // 2. Party Tab: Audio Voice Party Rooms (sorted with host's own room first)
              LiveDiscoveryGrid(
                liveRooms: (() {
                  final list = liveRooms.where((r) {
                    final t = r.roomType.toUpperCase();
                    final isAudio = t.contains('AUDIO') || t.contains('VOICE') || (t.contains('PARTY') && !t.contains('VIDEO'));
                    return isAudio || (t != 'LIVE_VIDEO' && !t.contains('VIDEO') && r.category.toUpperCase() == 'PARTY');
                  }).toList();
                  list.sort((a, b) {
                    final aIsMine = currentUserId.isNotEmpty && (a.host.id == currentUserId || a.creatorUserId == currentUserId);
                    final bIsMine = currentUserId.isNotEmpty && (b.host.id == currentUserId || b.creatorUserId == currentUserId);
                    if (aIsMine && !bIsMine) return -1;
                    if (!aIsMine && bIsMine) return 1;
                    return b.viewerCount.compareTo(a.viewerCount);
                  });
                  return list;
                })(),
                isDark: isDark,
                isPartyTab: true,
              ),

              // 3. Live Tab: Video Streams (sorted with host's own room first, excludes PK)
              LiveDiscoveryGrid(
                liveRooms: (() {
                  final list = liveRooms.where((r) {
                    final isPk = r.category.toUpperCase() == 'PK' ||
                        r.title.toUpperCase().contains('PK') ||
                        r.roomType.toUpperCase().contains('PK');
                    if (isPk) return false;

                    final t = r.roomType.toUpperCase();
                    final isVideo = t.contains('VIDEO') || t == 'LIVE_VIDEO' || t == 'VIDEO ROOM';
                    return isVideo || (!t.contains('AUDIO') && !t.contains('VOICE') && !t.contains('PARTY'));
                  }).toList();
                  list.sort((a, b) {
                    final aIsMine = currentUserId.isNotEmpty && (a.host.id == currentUserId || a.creatorUserId == currentUserId);
                    final bIsMine = currentUserId.isNotEmpty && (b.host.id == currentUserId || b.creatorUserId == currentUserId);
                    if (aIsMine && !bIsMine) return -1;
                    if (!aIsMine && bIsMine) return 1;
                    return b.viewerCount.compareTo(a.viewerCount);
                  });
                  return list;
                })(),
                isDark: isDark,
                isPartyTab: false,
              ),

              // 4. Games Tab
              GamesTab(isDark: isDark),

              // 5. PK Tab: Live PK Battles ONLY
              LiveDiscoveryGrid(
                liveRooms: (() {
                  final list = liveRooms.where((r) {
                    final isPk = r.category.toUpperCase() == 'PK' ||
                        r.title.toUpperCase().contains('PK') ||
                        r.roomType.toUpperCase().contains('PK');
                    return isPk;
                  }).toList();
                  list.sort((a, b) {
                    final aIsMine = currentUserId.isNotEmpty && (a.host.id == currentUserId || a.creatorUserId == currentUserId);
                    final bIsMine = currentUserId.isNotEmpty && (b.host.id == currentUserId || b.creatorUserId == currentUserId);
                    if (aIsMine && !bIsMine) return -1;
                    if (!aIsMine && bIsMine) return 1;
                    return b.viewerCount.compareTo(a.viewerCount);
                  });
                  return list;
                })(),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
