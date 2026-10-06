import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../models/live_room_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/skeleton_widgets.dart';
import '../profile/user_profile_details_screen.dart';
import '../live/live_room_screen.dart';
import '../party_room/live_party_room_screen.dart';
import '../social/single_post_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  static const String _recentSearchesKey = 'zeparty_recent_searches_history';
  late TabController _tabController;
  final List<String> _tabs = ['Users', 'Hosts', 'Live Rooms', 'Videos', 'Sounds', 'Hashtags'];
  final _searchController = TextEditingController();
  String _currentQuery = '';
  Timer? _debounceTimer;

  List<String> _recentSearches = [];

  // Real backend query results
  List<UserModel> _searchedUsers = [];
  List<LiveRoomModel> _searchedRooms = [];
  List<PostModel> _searchedPosts = [];
  List<UserModel> _suggestedCreators = [];

  bool _isLoadingUsers = false;
  bool _isLoadingRooms = false;
  bool _isLoadingPosts = false;
  bool _isLoadingSuggestedCreators = false;

  final List<String> _allTrendingTags = [
    '#ZePartyFest',
    '#MusicLive',
    '#PKBattle2026',
    '#GamingZone',
    '#TalentShowcase',
    '#SingWithMe',
    '#NightVibes',
    '#DanceParty',
  ];

  final List<Map<String, String>> _allSounds = [
    {'title': 'ZeParty Official Beat', 'artist': 'ZeParty Audio Studio', 'uses': '14.2K'},
    {'title': 'Cyber Night Wave', 'artist': 'DJ Pulse', 'uses': '8.9K'},
    {'title': 'Golden Party Anthem', 'artist': 'Star Records', 'uses': '22.1K'},
    {'title': 'Acoustic Chill Vibes', 'artist': 'Velvet Sound', 'uses': '5.4K'},
    {'title': 'Arabic Lounge Remix', 'artist': 'Habibi Beats', 'uses': '11.8K'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadRecentSearches();
    _loadDiscoverCreators();
  }

  Future<void> _loadDiscoverCreators() async {
    setState(() => _isLoadingSuggestedCreators = true);
    try {
      final res = await ApiClient.instance.get<Map<String, dynamic>>(
        '/v1/users/search',
        queryParameters: {'q': '', 'limit': 30},
      );
      final rawList = res.data?['data'];
      final List<UserModel> loaded = [];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            loaded.add(UserModel.fromJson(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          _suggestedCreators = loaded;
          _isLoadingSuggestedCreators = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestedCreators = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentSearchesKey) ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = list.take(5).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveSearchQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final updated = [trimmed, ..._recentSearches.where((s) => s.toLowerCase() != trimmed.toLowerCase())].take(5).toList();

    setState(() {
      _recentSearches = updated;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String item) async {
    final updated = _recentSearches.where((s) => s != item).toList();
    setState(() {
      _recentSearches = updated;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, updated);
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    setState(() {
      _recentSearches.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    setState(() {
      _currentQuery = trimmed;
    });

    _debounceTimer?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _searchedUsers.clear();
        _searchedRooms.clear();
        _searchedPosts.clear();
        _isLoadingUsers = false;
        _isLoadingRooms = false;
        _isLoadingPosts = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performBackendSearch(trimmed);
    });
  }

  Future<void> _performBackendSearch(String query) async {
    if (query.isEmpty) return;
    _saveSearchQuery(query);

    final client = ApiClient.instance;

    // 1. Search Users & Hosts
    setState(() => _isLoadingUsers = true);
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/v1/users/search',
        queryParameters: {
          'q': query,
          'limit': 50,
        },
      );
      final rawList = res.data?['data'];
      final List<UserModel> loadedUsers = [];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            loadedUsers.add(UserModel.fromJson(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          _searchedUsers = loadedUsers;
          _isLoadingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }

    // 2. Search Live Rooms (by room id or host name)
    setState(() => _isLoadingRooms = true);
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/v1/rooms/active',
        queryParameters: {
          'search': query,
          'limit': 50,
        },
      );
      final rawRooms = res.data?['data'];
      final List<LiveRoomModel> loadedRooms = [];
      if (rawRooms is List) {
        for (final item in rawRooms) {
          if (item is Map<String, dynamic>) {
            loadedRooms.add(LiveRoomModel.fromJson(item));
          }
        }
      }
      if (mounted) {
        setState(() {
          _searchedRooms = loadedRooms;
          _isLoadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }

    // 3. Search Posts & Videos
    setState(() => _isLoadingPosts = true);
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/v1/feed',
        queryParameters: {
          'limit': 50,
        },
      );
      final rawPosts = res.data?['data'];
      final List<PostModel> loadedPosts = [];
      if (rawPosts is List) {
        for (final item in rawPosts) {
          if (item is Map<String, dynamic>) {
            final p = PostModel.fromJson(item);
            final q = query.toLowerCase();
            if (p.content.toLowerCase().contains(q) ||
                p.author.name.toLowerCase().contains(q) ||
                p.author.username.toLowerCase().contains(q) ||
                p.author.displayName.toLowerCase().contains(q)) {
              loadedPosts.add(p);
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _searchedPosts = loadedPosts;
          _isLoadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  void _navigateToRoom(BuildContext context, LiveRoomModel room) {
    final isVoiceParty = room.roomType == 'AUDIO_PARTY' ||
        room.roomType == 'AUDIO' ||
        room.category.toLowerCase() == 'party' ||
        room.id.startsWith('party_');
    if (isVoiceParty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LivePartyRoomScreen(room: room)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LiveRoomScreen(room: room)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final hasQuery = _currentQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        titleSpacing: 0,
        title: AnimatedContainer(
          duration: AppAnimations.fast,
          height: 42,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.getBorder(isDark)),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: (val) {
              _saveSearchQuery(val);
              _performBackendSearch(val.trim());
            },
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by User ID, username, room ID, host...',
              hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.getPrimary(isDark)),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        bottom: hasQuery
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: AppColors.getPrimary(isDark),
                labelColor: AppColors.getPrimary(isDark),
                unselectedLabelColor: AppColors.getTextSecondary(isDark),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              )
            : null,
      ),
      body: hasQuery
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildUsersResultList(_searchedUsers, isDark, onlyHosts: false),
                _buildUsersResultList(_searchedUsers, isDark, onlyHosts: true),
                _buildLiveRoomsResultList(_searchedRooms, isDark),
                _buildVideosResultGrid(_searchedPosts, isDark),
                _buildSoundsList(isDark),
                _buildHashtagsList(isDark),
              ],
            )
          : _buildRecentSearchesView(isDark),
    );
  }

  /// Clean initial view showing ONLY up to 5 recent search history items
  Widget _buildRecentSearchesView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: AppColors.getPrimary(isDark)),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Searches',
                      style: TextStyle(
                        color: AppColors.getTextPrimary(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _clearAllRecentSearches,
                  child: const Text('Clear All', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((item) {
                return Chip(
                  backgroundColor: AppColors.getCard(isDark),
                  side: BorderSide(color: AppColors.getBorder(isDark)),
                  labelPadding: const EdgeInsets.only(left: 4),
                  label: GestureDetector(
                    onTap: () {
                      _searchController.text = item;
                      _onSearchChanged(item);
                    },
                    child: Text(
                      item,
                      style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 16),
                  deleteIconColor: AppColors.getTextSecondary(isDark),
                  onDeleted: () => _removeRecentSearch(item),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
          ],

          // Trending Topics Quick Chips
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'Trending Topics',
                style: TextStyle(
                  color: AppColors.getTextPrimary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTrendingTags.map((tag) {
              return ActionChip(
                backgroundColor: AppColors.getCard(isDark),
                side: BorderSide(color: AppColors.getBorder(isDark)),
                avatar: const Icon(Icons.tag_rounded, size: 14, color: AppColors.primaryGold),
                label: Text(tag, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 12)),
                onPressed: () {
                  _searchController.text = tag;
                  _onSearchChanged(tag);
                },
              );
            }).toList(),
          ),

          // Discover Creators Section
          if (_isLoadingSuggestedCreators) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)),
          ] else if (_suggestedCreators.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.stars_rounded, size: 20, color: AppColors.primaryGold),
                const SizedBox(width: 8),
                Text(
                  'Discover Creators',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestedCreators.length > 8 ? 8 : _suggestedCreators.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final creator = _suggestedCreators[idx];
                final isFollowed = context.watch<AuthProvider>().isFollowing(creator.id);
                final isMe = context.watch<AuthProvider>().currentUser.id == creator.id;

                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: AppColors.getCard(isDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: AppColors.getBorder(isDark)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: creator.id)),
                      );
                    },
                    leading: UserAvatar(imageUrl: creator.avatarUrl, radius: 22),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            creator.displayName.isNotEmpty ? creator.displayName : creator.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (creator.isHost) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber, width: 0.6),
                            ),
                            child: const Text('HOST', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '@${creator.username}',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                    ),
                    trailing: isMe
                        ? null
                        : SizedBox(
                            height: 32,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isFollowed ? Colors.transparent : AppColors.primaryGold,
                                side: BorderSide(color: isFollowed ? AppColors.getBorder(isDark) : AppColors.primaryGold),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: () {
                                context.read<AuthProvider>().toggleFollow(creator.id);
                              },
                              child: Text(
                                isFollowed ? 'Following' : '+ Follow',
                                style: TextStyle(
                                  color: isFollowed ? AppColors.getTextSecondary(isDark) : Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildUsersResultList(List<UserModel> users, bool isDark, {required bool onlyHosts}) {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2));
    }

    List<UserModel> filtered = users;
    if (onlyHosts) {
      filtered = filtered.where((u) => u.isHost || u.role == UserRole.host).toList();
    }

    if (_currentQuery.isNotEmpty) {
      final q = _currentQuery.toLowerCase();
      filtered = filtered.where((u) {
        final matchId = u.id.toLowerCase().contains(q);
        final matchUsername = u.username.toLowerCase().contains(q);
        final matchName = u.name.toLowerCase().contains(q);
        final matchDisplayName = u.displayName.toLowerCase().contains(q);
        return matchId || matchUsername || matchName || matchDisplayName;
      }).toList();
    }

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'No ${onlyHosts ? "Hosts" : "Users"} Found',
        subtitle: 'We couldn\'t find any ${onlyHosts ? "hosts" : "users"} matching "$_currentQuery"',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final user = filtered[i];
        final isFollowed = context.watch<AuthProvider>().isFollowing(user.id);
        final isMe = context.watch<AuthProvider>().currentUser.id == user.id;

        return Card(
          clipBehavior: Clip.antiAlias,
          color: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.getBorder(isDark)),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
              );
            },
            leading: UserAvatar(imageUrl: user.avatarUrl, radius: 24),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.displayName,
                    style: TextStyle(
                      color: AppColors.getTextPrimary(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isHost) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 16, color: Colors.blueAccent),
                ],
              ],
            ),
            subtitle: Text(
              '@${user.username} • ${AppFormatters.formatNumber(user.followers)} followers',
              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
            ),
            trailing: isMe
                ? null
                : ElevatedButton(
                    onPressed: () {
                      final auth = context.read<AuthProvider>();
                      if (isFollowed) {
                        auth.unfollowUser(user.id);
                      } else {
                        auth.followUser(user.id);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowed ? AppColors.getSurface(isDark) : AppColors.primaryGold,
                      foregroundColor: isFollowed ? AppColors.getTextPrimary(isDark) : Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isFollowed ? AppColors.getBorder(isDark) : Colors.transparent),
                      ),
                    ),
                    child: Text(
                      isFollowed ? 'Following' : '+ Follow',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isFollowed ? AppColors.getTextPrimary(isDark) : Colors.black,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLiveRoomsResultList(List<LiveRoomModel> rooms, bool isDark) {
    if (_isLoadingRooms) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2));
    }

    List<LiveRoomModel> filtered = rooms;
    if (_currentQuery.isNotEmpty) {
      final q = _currentQuery.toLowerCase();
      filtered = filtered.where((r) {
        final matchId = r.id.toLowerCase().contains(q);
        final matchTitle = r.title.toLowerCase().contains(q);
        final matchHost = r.host.name.toLowerCase().contains(q) || r.host.username.toLowerCase().contains(q);
        return matchId || matchTitle || matchHost;
      }).toList();
    }

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.sensors_off_rounded,
        title: 'No Live Rooms Found',
        subtitle: 'No active rooms matched "$_currentQuery".',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final room = filtered[i];
        final isVoice = room.roomType == 'AUDIO_PARTY' || room.category.toLowerCase() == 'party';

        return Card(
          clipBehavior: Clip.antiAlias,
          color: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.getBorder(isDark)),
          ),
          child: ListTile(
            onTap: () => _navigateToRoom(context, room),
            leading: Stack(
              children: [
                UserAvatar(imageUrl: room.coverUrl.isNotEmpty ? room.coverUrl : room.host.avatarUrl, radius: 24),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isVoice ? Colors.purpleAccent : AppColors.liveRed,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isVoice ? Icons.mic : Icons.videocam, size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
            title: Text(
              room.title,
              style: TextStyle(
                color: AppColors.getTextPrimary(isDark),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${isVoice ? "🎙️ Voice Party" : "📹 Video Live"} • Host: ${room.host.name} • ${room.viewerCount} Viewers',
              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
            ),
            trailing: ElevatedButton(
              onPressed: () => _navigateToRoom(context, room),
              style: ElevatedButton.styleFrom(
                backgroundColor: isVoice ? Colors.purpleAccent : AppColors.liveRed,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideosResultGrid(List<PostModel> posts, bool isDark) {
    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2));
    }

    if (posts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.video_library_rounded,
        title: 'No Videos Found',
        subtitle: 'No video posts matching "$_currentQuery"',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        final hasMedia = post.imageUrls.isNotEmpty;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SinglePostScreen(post: post)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
              image: hasMedia
                  ? DecorationImage(
                      image: NetworkImage(post.imageUrls.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.content,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      UserAvatar(imageUrl: post.author.avatarUrl, radius: 8),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.author.displayName,
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 12),
                      const SizedBox(width: 2),
                      Text('${post.likes}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundsList(bool isDark) {
    final q = _currentQuery.toLowerCase();
    final filtered = _allSounds.where((s) {
      return s['title']!.toLowerCase().contains(q) || s['artist']!.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.music_off_rounded,
        title: 'No Sounds Found',
        subtitle: 'No audio tracks matched "$_currentQuery"',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = filtered[i];
        return Card(
          color: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.music_note_rounded, color: Colors.amber, size: 20),
            ),
            title: Text(s['title']!, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${s['artist']} • ${s['uses']} videos', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
            trailing: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryGold, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildHashtagsList(bool isDark) {
    final q = _currentQuery.toLowerCase().replaceAll('#', '');
    final filtered = _allTrendingTags.where((tag) {
      return tag.toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.tag_rounded,
        title: 'No Hashtags Found',
        subtitle: 'No hashtags matched "$_currentQuery"',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final tag = filtered[i];
        return Card(
          color: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.pinkAccent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.tag_rounded, color: Colors.pinkAccent, size: 20),
            ),
            title: Text(tag, style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('Trending • ${10 + i * 4}.5K views', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ),
        );
      },
    );
  }
}
