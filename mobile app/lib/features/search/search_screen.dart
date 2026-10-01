import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/services/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../models/live_room_model.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
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
  late TabController _tabController;
  final List<String> _tabs = ['Users', 'Hosts', 'Live Rooms', 'Videos', 'Sounds', 'Hashtags'];
  final _searchController = TextEditingController();
  String _currentQuery = '';
  Timer? _debounceTimer;

  // Real backend query results
  List<UserModel> _searchedUsers = [];
  List<LiveRoomModel> _searchedRooms = [];
  List<PostModel> _searchedPosts = [];

  bool _isLoadingUsers = false;
  bool _isLoadingRooms = false;
  bool _isLoadingPosts = false;

  final List<String> _trendingTags = [
    '#ZePartyFest',
    '#MusicLive',
    '#PKBattle2026',
    '#GamingZone',
    '#TalentShowcase',
    '#SingWithMe',
    '#NightVibes',
  ];

  final List<String> _trendingSounds = [
    'ZeParty Official Beat - Audio Studio',
    'Cyber Night Wave - DJ Pulse',
    'Golden Party Anthem - Star Records',
    'Acoustic Chill Acoustic - Velvet Sound',
    'Arabic Lounge Vibes - Habibi Remix',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    // Initial fetch of active rooms and popular users
    _performBackendSearch('');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();
    setState(() {
      _currentQuery = trimmed;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performBackendSearch(trimmed);
    });
  }

  Future<void> _performBackendSearch(String query) async {
    final client = ApiClient.instance;

    // 1. Search Users & Hosts
    setState(() => _isLoadingUsers = true);
    try {
      final res = await client.get<Map<String, dynamic>>(
        '/v1/users/search',
        queryParameters: {
          'q': query,
          'limit': 30,
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
          if (query.isNotEmpty) 'search': query,
          'limit': 30,
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
          'limit': 30,
        },
      );
      final rawPosts = res.data?['data'];
      final List<PostModel> loadedPosts = [];
      if (rawPosts is List) {
        for (final item in rawPosts) {
          if (item is Map<String, dynamic>) {
            final p = PostModel.fromJson(item);
            if (query.isEmpty ||
                p.content.toLowerCase().contains(query.toLowerCase()) ||
                p.author.name.toLowerCase().contains(query.toLowerCase()) ||
                p.author.username.toLowerCase().contains(query.toLowerCase())) {
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

  void _toggleFollow(String userId, String userName) {
    final auth = context.read<AuthProvider>();
    if (auth.isFollowing(userId)) {
      auth.unfollowUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unfollowed $userName'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      auth.followUser(userId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ You are now following $userName!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToRoom(BuildContext context, LiveRoomModel room) {
    final isParty = room.category.toLowerCase() == 'party' || room.id.startsWith('party_');
    if (isParty) {
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
            autofocus: false,
            onChanged: _onSearchChanged,
            style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search user ID, username, room ID, host...',
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.getPrimary(isDark),
          labelColor: AppColors.getPrimary(isDark),
          unselectedLabelColor: AppColors.getTextSecondary(isDark),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Users Tab
          _buildUsersResultList(_searchedUsers, isDark, onlyHosts: false),
          // 2. Hosts Tab
          _buildUsersResultList(_searchedUsers, isDark, onlyHosts: true),
          // 3. Live Rooms Tab
          _buildLiveRoomsResultList(_searchedRooms, isDark),
          // 4. Videos Tab
          _buildVideosResultGrid(_searchedPosts, isDark),
          // 5. Sounds Tab
          _buildSoundsList(isDark),
          // 6. Hashtags Tab
          _buildHashtagsList(isDark),
        ],
      ),
    );
  }

  Widget _buildUsersResultList(List<UserModel> users, bool isDark, {required bool onlyHosts}) {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    }

    List<UserModel> filtered = users;
    if (onlyHosts) {
      filtered = filtered.where((u) => u.isHost || u.role == UserRole.host).toList();
    }

    if (_currentQuery.isNotEmpty) {
      filtered = filtered.where((u) {
        final matchId = u.id.toLowerCase().contains(_currentQuery);
        final matchUsername = u.username.toLowerCase().contains(_currentQuery);
        final matchName = u.name.toLowerCase().contains(_currentQuery);
        final matchDisplayName = u.displayName.toLowerCase().contains(_currentQuery);
        return matchId || matchUsername || matchName || matchDisplayName;
      }).toList();
    }

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_search_rounded,
        title: 'No ${onlyHosts ? "Hosts" : "Users"} Found',
        subtitle: _currentQuery.isNotEmpty
            ? 'We couldn\'t find any ${onlyHosts ? "hosts" : "users"} matching "$_currentQuery"'
            : 'No ${onlyHosts ? "hosts" : "users"} available right now.',
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                );
              },
              child: UserAvatar(
                imageUrl: user.avatarUrl,
                radius: 24,
                isLive: user.isLive,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName : user.name,
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (user.isVip) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.workspace_premium_rounded, size: 14, color: AppColors.gold),
                ],
                if (user.isHost) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 14, color: Colors.blueAccent),
                ],
              ],
            ),
            subtitle: Text(
              '@${user.username} • ID: ${user.id} • ${AppFormatters.formatNumber(user.followers)} followers',
              style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isMe
                ? const SizedBox.shrink()
                : isFollowed
                    ? OutlinedButton(
                        onPressed: () => _toggleFollow(user.id, user.displayName.isNotEmpty ? user.displayName : user.name),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.getTextSecondary(isDark)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          minimumSize: const Size(0, 34),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Following', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    : Container(
                        height: 34,
                        constraints: const BoxConstraints(minWidth: 80, maxWidth: 90),
                        decoration: BoxDecoration(
                          gradient: AppColors.getAccentGradient(isDark),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _toggleFollow(user.id, user.displayName.isNotEmpty ? user.displayName : user.name),
                            child: Center(
                              child: Text(
                                '+ Follow',
                                style: TextStyle(
                                  color: AppColors.onPrimary(isDark: isDark),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLiveRoomsResultList(List<LiveRoomModel> rooms, bool isDark) {
    if (_isLoadingRooms) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    }

    if (rooms.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.live_tv_rounded,
        title: 'No Live Rooms Found',
        subtitle: _currentQuery.isNotEmpty
            ? 'No live rooms match "$_currentQuery"'
            : 'No active live rooms at this moment.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: rooms.length,
      itemBuilder: (context, i) {
        final room = rooms[i];
        final isParty = room.category.toLowerCase() == 'party' || room.id.startsWith('party_');

        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 12),
          color: AppColors.getCard(isDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: UserAvatar(imageUrl: room.host.avatarUrl, radius: 24, isLive: true),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: isParty ? Colors.deepPurpleAccent : AppColors.live,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isParty ? 'PARTY' : 'LIVE',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    room.title,
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Host: ${room.host.name} • Room ID: ${room.id} • ${room.viewerCount} Viewers',
                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.getTextSecondary(isDark)),
            onTap: () => _navigateToRoom(context, room),
          ),
        );
      },
    );
  }

  Widget _buildVideosResultGrid(List<PostModel> posts, bool isDark) {
    if (_isLoadingPosts) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    }

    final videoPosts = posts.where((p) => p.imageUrls.isNotEmpty || p.content.isNotEmpty).toList();

    if (videoPosts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.video_library_rounded,
        title: 'No Posts/Videos Found',
        subtitle: _currentQuery.isNotEmpty
            ? 'No posts or clips match "$_currentQuery"'
            : 'No posts available at this moment.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: videoPosts.length,
      itemBuilder: (_, i) {
        final post = videoPosts[i];
        final hasImage = post.imageUrls.isNotEmpty;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SinglePostScreen(post: post)),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: AppColors.getCard(isDark),
                  child: hasImage
                      ? Image.network(
                          post.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(Icons.photo_library_rounded, color: AppColors.getPrimary(isDark), size: 36),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple.shade900, Colors.deepPurple.shade700],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              post.content,
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.content.isNotEmpty ? post.content : '@${post.author.username}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '❤️ ${post.likes} • 💬 ${post.comments}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoundsList(bool isDark) {
    final sounds = _trendingSounds.where((s) {
      if (_currentQuery.isEmpty) return true;
      return s.toLowerCase().contains(_currentQuery);
    }).toList();

    if (sounds.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.music_off_rounded,
        title: 'No Sounds Found',
        subtitle: 'No sound tracks matching "$_currentQuery"',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: sounds.length,
      itemBuilder: (_, i) => Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 8),
        color: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.getBorder(isDark)),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.getPrimary(isDark).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.music_note_rounded, color: AppColors.getPrimary(isDark), size: 20),
          ),
          title: Text(sounds[i], style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('${(i + 1) * 3420} posts • 0:45', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
          trailing: IconButton(
            icon: Icon(Icons.play_circle_outline_rounded, color: AppColors.getPrimary(isDark)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Playing preview for ${sounds[i]}'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHashtagsList(bool isDark) {
    final tags = _trendingTags.where((t) {
      if (_currentQuery.isEmpty) return true;
      return t.toLowerCase().contains(_currentQuery);
    }).toList();

    if (tags.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.tag_rounded,
        title: 'No Hashtags Found',
        subtitle: 'No hashtags matching "$_currentQuery"',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: tags.length,
      itemBuilder: (_, i) => Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 8),
        color: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.getBorder(isDark)),
        ),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.tag_rounded, color: Colors.amber, size: 20),
          ),
          title: Text(tags[i], style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text('${(i + 2) * 12}.5K views & posts', style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12)),
          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.getTextSecondary(isDark)),
          onTap: () {
            _searchController.text = tags[i].replaceAll('#', '');
            _onSearchChanged(_searchController.text);
          },
        ),
      ),
    );
  }
}
