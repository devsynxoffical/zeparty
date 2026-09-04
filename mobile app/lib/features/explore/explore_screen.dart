import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../core/animations/app_animations.dart';
import '../../models/live_room_model.dart';
import '../../providers/live_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/skeleton_widgets.dart';
import '../../widgets/design/premium_card.dart';
import '../live/live_room_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  final List<String> _recentSearches = ['Sophia', 'Music', 'PK Battle', 'Danial'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim();
          _isSearching = _searchQuery.isNotEmpty;
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _isSearching = false;
    });
  }

  void _saveSearchQuery(String query) {
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      setState(() {
        _recentSearches.insert(0, query);
        if (_recentSearches.length > 5) _recentSearches.removeLast();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: _onSearchChanged,
          onSubmitted: _saveSearchQuery,
          decoration: InputDecoration(
            hintText: 'Search hosts, live rooms, user IDs...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _clearSearch,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        bottom: _isSearching
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'Shorts'),
                ],
              ),
      ),
      body: _isSearching
          ? _buildSearchResults()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDiscoverTab(),
                _buildLiveNowTab(), // Fallback for Shorts if not implemented
              ],
            ),
    );
  }

  Widget _buildSearchResults() {
    final liveProvider = context.watch<LiveProvider>();
    final rooms = liveProvider.activeRoom != null ? [liveProvider.activeRoom!] : <LiveRoomModel>[];

    final query = _searchQuery.toLowerCase();
    final matchedRooms = rooms.where((r) => r.title.toLowerCase().contains(query) || r.host.name.toLowerCase().contains(query)).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Search Results for "$_searchQuery"', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${matchedRooms.length} found', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          if (matchedRooms.isEmpty)
            const EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'No Matching Results',
              subtitle: 'Try searching with a different username, host name or topic keyword',
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matchedRooms.length,
              itemBuilder: (context, index) {
                final room = matchedRooms[index];
                return ListTile(
                  leading: UserAvatar(imageUrl: room.host.avatarUrl, radius: 24, isLive: true),
                  title: Text(room.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${room.host.name} • ${room.viewerCount} Viewers'),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.live, foregroundColor: AppColors.white),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => LiveRoomScreen(room: room)));
                    },
                    child: const Text('Watch'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Searches Chips
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Searches', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _recentSearches.clear()),
                  child: const Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.mutedText)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _recentSearches.map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  avatar: const Icon(Icons.history, size: 14),
                  onPressed: () {
                    _searchController.text = s;
                    _onSearchChanged(s);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Featured Banner Card
          MetallicShine(
            duration: const Duration(milliseconds: 3000),
            bandWidth: 0.35,
            beginX: -0.7,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getAccentGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getPrimary(isDark).withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(12)),
                          child: const Text('LIVE EVENT', style: TextStyle(color: AppColors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Global PK Battle Championship',
                          style: TextStyle(color: isDark ? AppColors.black : AppColors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Watch top creators battle live for the crown 🏆',
                          style: TextStyle(color: isDark ? AppColors.darkBlack : AppColors.lightSurface, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.stars_rounded, color: isDark ? AppColors.black : AppColors.white, size: 54),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Categories Horizontal Row
          Text('Popular Categories', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryPill('🔥 Trending', isSelected: true),
                _buildCategoryPill('🎙️ Music Party'),
                _buildCategoryPill('⚔️ PK Tournament'),
                _buildCategoryPill('🎮 Gaming Live'),
                _buildCategoryPill('💃 Dance Show'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Explore Users Cards
          Text('Recommended Hosts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  padding: const EdgeInsets.all(14),
                  radius: 16,
                  premium: true,
                  child: Row(
                  children: [
                    const UserAvatar(
                      imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
                      radius: 26,
                      isLive: true,
                      showVipFrame: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                index == 0 ? 'Sophia Rose' : (index == 1 ? 'Alex Rivera' : 'Elena Rostova'),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            index == 0 ? 'Singer & Vocalist 🎙️' : (index == 1 ? 'PK Champion 🏆' : 'Dance Host 💃'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.card_giftcard_rounded, color: AppColors.violet, size: 20),
                              onPressed: () {
                                AuthGuard.require(context, () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (c) => const GiftDialog(streamerName: 'Sophia Rose'),
                                  );
                                }, reason: 'Sign in to send gifts');
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 20),
                              onPressed: () {
                                AuthGuard.require(context, () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Followed host successfully!')),
                                  );
                                }, reason: 'Sign in to follow hosts');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String title, {bool isSelected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected ? AppColors.getAccentGradient(isDark) : null,
        color: isSelected ? null : AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.getBorderStrong(isDark) : AppColors.getBorder(isDark),
          width: 1.1,
        ),
        boxShadow: isSelected
            ? AppColors.primaryGlow(isDark, alpha: 0.25, blur: 10)
            : null,
      ),
      child: Center(
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.onPrimary(isDark: isDark) : AppColors.getTextSecondary(isDark),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveNowTab() {
    return const Center(
      child: EmptyStateWidget(
        icon: Icons.live_tv_rounded,
        title: 'Explore Live Streams',
        subtitle: 'Watch real-time live video feeds from top global hosts!',
      ),
    );
  }
}
