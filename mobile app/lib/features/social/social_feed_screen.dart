import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/post_model.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/app_logo.dart';
import 'create_post_screen.dart';
import 'short_videos_screen.dart';
import 'camera_recorder_screen.dart';
import '../../core/services/room_share_service.dart';

class SocialFeedScreen extends StatefulWidget {
  final bool isScreenActive;
  const SocialFeedScreen({super.key, this.isScreenActive = true});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> with SingleTickerProviderStateMixin {
  static const String _viewedStoriesPrefsKey = 'zeparty_viewed_story_keys';
  late TabController _tabController;
  final Set<String> _viewedStoryKeys = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadViewedStories();
    // Load real feed from backend on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final social = context.read<SocialProvider>();
      if (!social.feedLoaded && !social.feedLoading) {
        social.loadFeed();
      }
    });
  }

  void _loadViewedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_viewedStoriesPrefsKey);
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _viewedStoryKeys.addAll(list);
        });
      }
    } catch (_) {}
  }

  void _markStoryAsViewed(String key) async {
    if (!_viewedStoryKeys.contains(key)) {
      setState(() {
        _viewedStoryKeys.add(key);
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_viewedStoriesPrefsKey, _viewedStoryKeys.toList());
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final social = context.watch<SocialProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            title: Row(
              children: [
                const AppLogo(
                  size: 32,
                  showBorder: true,
                  borderRadius: 9,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.getAccentGradient(isDark),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ZeParty',
                    style: TextStyle(
                      color: AppColors.onPrimary(isDark: isDark),
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.getPrimary(isDark).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.getPrimary(isDark), width: 0.8),
                  ),
                  child: Text(
                    'FEED',
                    style: TextStyle(
                      color: AppColors.getPrimary(isDark),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: AppColors.primary),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: _PostSearchDelegate(social.posts),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                onPressed: () {
                  AuthGuard.require(context, () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const CreatePostScreen()));
                  }, reason: 'Sign in to create social posts');
                },
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: _buildStoryBar(social, auth),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.getPrimary(isDark),
                labelColor: AppColors.getPrimary(isDark),
                unselectedLabelColor: AppColors.getTextSecondary(isDark),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: '🏠 For You'),
                  Tab(text: '👥 Following'),
                  Tab(text: '🎬 Shorts'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostFeed(social, auth, feedMode: 'forYou'),
            _buildPostFeed(social, auth, feedMode: 'following'),
            ShortVideosScreen(isActive: widget.isScreenActive && _tabController.index == 2),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.getPrimary(isDark),
        onPressed: () {
          AuthGuard.require(context, () {
            Navigator.push(context, MaterialPageRoute(builder: (c) => const CreatePostScreen()));
          }, reason: 'Sign in to create social posts');
        },
        icon: Icon(Icons.edit_rounded, color: AppColors.onPrimary(isDark: isDark), size: 18),
        label: Text('Post', style: TextStyle(color: AppColors.onPrimary(isDark: isDark), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStoryBar(SocialProvider social, AuthProvider auth) {
    final currentUserId = auth.currentUser.id;
    final currentUserName = auth.currentUser.displayName.toLowerCase();
    final currentUserHandle = auth.currentUser.username.toLowerCase();

    // 24-hour expiration filter: Stories must disappear after 24 hours
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final validStories = social.posts.where((p) => p.createdAt.isAfter(cutoff)).toList();

    // 1. Current user's valid stories
    final myStories = validStories.where((p) =>
      (currentUserId.isNotEmpty && p.author.id == currentUserId) ||
      (currentUserName.isNotEmpty && p.author.displayName.toLowerCase() == currentUserName) ||
      (currentUserHandle.isNotEmpty && p.author.username.toLowerCase() == currentUserHandle)
    ).toList();

    // 2. Group other users' stories strictly by unique author name/handle
    final Map<String, List<PostModel>> otherUsersStoryMap = {};
    for (final post in validStories) {
      final isMyPost = (currentUserId.isNotEmpty && post.author.id == currentUserId) ||
                       (currentUserName.isNotEmpty && post.author.displayName.toLowerCase() == currentUserName) ||
                       (currentUserHandle.isNotEmpty && post.author.username.toLowerCase() == currentUserHandle);
      if (isMyPost) continue;

      // Group by author username or display name
      final rawKey = post.author.username.isNotEmpty && !post.author.username.startsWith('user_')
          ? post.author.username
          : (post.author.displayName.isNotEmpty ? post.author.displayName : post.author.id);
      final key = rawKey.toLowerCase().trim();
      if (key.isNotEmpty) {
        otherUsersStoryMap.putIfAbsent(key, () => []).add(post);
      }
    }

    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _buildAddStoryItem(auth, myStories),
          ...otherUsersStoryMap.values.map((storyList) => _buildGroupedStoryItem(storyList)),
        ],
      ),
    );
  }

  Widget _buildAddStoryItem(AuthProvider auth, List<PostModel> myStories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasStory = myStories.isNotEmpty;
    final isMyStoryWatched = _viewedStoryKeys.contains('__my_story__');

    return GestureDetector(
      onTap: () {
        AuthGuard.require(context, () {
          if (hasStory) {
            _markStoryAsViewed('__my_story__');
            showDialog(
              context: context,
              builder: (_) => _FullStoryViewerDialog(stories: myStories, isMyStory: true),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraRecorderScreen()));
          }
        }, reason: 'Sign in to post a story');
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory && !isMyStoryWatched
                    ? const LinearGradient(
                        colors: [Color(0xFFF9CE34), Color(0xFFEE2A7B), Color(0xFF6228D7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: hasStory && isMyStoryWatched
                    ? Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade400,
                        width: 1.8,
                      )
                    : null,
                color: hasStory ? null : AppColors.getPrimary(isDark).withValues(alpha: 0.3),
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.getCard(isDark),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      imageUrl: auth.currentUser.avatarUrl.isNotEmpty
                          ? auth.currentUser.avatarUrl
                          : (hasStory ? myStories.first.author.avatarUrl : null),
                      name: auth.currentUser.displayName,
                      radius: 22,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          AuthGuard.require(context, () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraRecorderScreen()));
                          }, reason: 'Sign in to post a story');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.getPrimary(isDark),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 11,
                            color: AppColors.onPrimary(isDark: isDark),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasStory ? 'My Story (${myStories.length})' : 'Add Story',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: hasStory ? FontWeight.bold : FontWeight.w600,
                color: hasStory
                    ? (isMyStoryWatched ? (isDark ? Colors.white70 : Colors.black54) : AppColors.getPrimary(isDark))
                    : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedStoryItem(List<PostModel> stories) {
    if (stories.isEmpty) return const SizedBox.shrink();
    final firstPost = stories.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorName = firstPost.author.name.isNotEmpty && firstPost.author.name != 'Unknown User' ? firstPost.author.name : 'Creator';
    final avatar = firstPost.author.avatarUrl;

    final rawKey = firstPost.author.username.isNotEmpty && !firstPost.author.username.startsWith('user_')
        ? firstPost.author.username
        : (firstPost.author.displayName.isNotEmpty ? firstPost.author.displayName : firstPost.author.id);
    final storyKey = rawKey.toLowerCase().trim();
    final isWatched = _viewedStoryKeys.contains(storyKey);

    return GestureDetector(
      onTap: () {
        _markStoryAsViewed(storyKey);
        showDialog(
          context: context,
          builder: (ctx) => _FullStoryViewerDialog(stories: stories, isMyStory: false),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isWatched
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFFF9CE34), Color(0xFFEE2A7B), Color(0xFF6228D7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                border: isWatched
                    ? Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.grey.shade400,
                        width: 1.8,
                      )
                    : null,
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.getCard(isDark),
                child: UserAvatar(
                  imageUrl: avatar.isNotEmpty ? avatar : firstPost.author.avatarUrl,
                  name: authorName,
                  radius: 22,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 58,
              child: Text(
                authorName,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isWatched ? FontWeight.w400 : FontWeight.w600,
                  color: isWatched ? (isDark ? Colors.white70 : Colors.black54) : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostFeed(SocialProvider social, AuthProvider auth, {required String feedMode}) {
    if (social.feedLoading && social.posts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (social.feedError != null && social.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(social.feedError!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => social.loadFeed(refresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final List<PostModel> posts;
    if (feedMode == 'following') {
      posts = social.posts.where((p) => auth.isFollowing(p.author.id)).toList();
    } else {
      posts = social.posts;
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              feedMode == 'following' ? Icons.people_outline_rounded : Icons.post_add_rounded,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              feedMode == 'following'
                  ? 'No posts from creators you follow yet'
                  : 'No posts yet',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                AuthGuard.require(context, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const CreatePostScreen()));
                }, reason: 'Sign in to create posts');
              },
              icon: const Icon(Icons.add),
              label: Text(feedMode == 'following' ? 'Discover Creators' : 'Create First Post'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => social.loadFeed(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: posts.length + (social.feedHasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            // Load-more trigger
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!social.feedLoading) social.loadFeed();
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
            );
          }
          final post = posts[index];
          return PostCard(
            post: post,
            onLike: () {
              AuthGuard.require(context, () {
                social.toggleLikePost(post.id);
              }, reason: 'Sign in to like posts');
            },
            onComment: () => _showCommentSheet(context, post.id),
            onShare: () => RoomShareService.sharePost(context, postId: post.id, title: post.content),
          );
        },
      ),
    );
  }

  void _showCommentSheet(BuildContext context, String postId) {
    CommentsSheet.show(
      context,
      targetId: postId,
      title: 'Post Comments',
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) => false;
}

class _PostSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> posts;
  _PostSearchDelegate(this.posts);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildSearchBody();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchBody();

  Widget _buildSearchBody() {
    final filtered = posts
        .where((p) => (p.content as String).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final post = filtered[index];
        return ListTile(
          leading: const Icon(Icons.article_rounded, color: AppColors.primary),
          title: Text(post.content as String, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(post.author.name as String),
        );
      },
    );
  }
}

class _FullStoryViewerDialog extends StatefulWidget {
  final List<PostModel> stories;
  final bool isMyStory;

  const _FullStoryViewerDialog({
    required this.stories,
    this.isMyStory = false,
  });

  @override
  State<_FullStoryViewerDialog> createState() => _FullStoryViewerDialogState();
}

class _FullStoryViewerDialogState extends State<_FullStoryViewerDialog> {
  int _currentIndex = 0;
  VideoPlayerController? _videoController;
  final TextEditingController _replyController = TextEditingController();
  bool _isVideo = false;

  PostModel get currentStory =>
      widget.stories[_currentIndex.clamp(0, widget.stories.length - 1)];

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _initMedia();
    } else {
      Navigator.pop(context);
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _initMedia();
    }
  }

  Future<void> _initMedia() async {
    _videoController?.dispose();
    _videoController = null;
    _isVideo = false;

    final mediaList = currentStory.imageUrls;
    if (mediaList.isNotEmpty) {
      final String url = mediaList.first;
      if (url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.m4v')) {
        _isVideo = true;
        try {
          if (url.startsWith('http')) {
            _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
          } else {
            _videoController = VideoPlayerController.file(File(url));
          }
          await _videoController?.initialize();
          _videoController?.setLooping(true);
          await _videoController?.play();
        } catch (e) {
          debugPrint('Story video error: $e');
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _replyController.dispose();
    super.dispose();
  }

  Widget _buildTextFallback() {
    return Container(
      color: const Color(0xFF1E1B4B),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          currentStory.content.isNotEmpty ? currentStory.content : '✨ ZeParty Story',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const SizedBox.shrink();
    }

    final authorName = currentStory.author.name.isNotEmpty && currentStory.author.name != 'Unknown User'
        ? currentStory.author.name
        : 'Creator';
    final avatar = currentStory.author.avatarUrl;
    final mediaList = currentStory.imageUrls;
    final String? mediaUrl = mediaList.isNotEmpty ? mediaList.first : null;

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Media View (Video or Image)
            Positioned.fill(
              child: _isVideo && _videoController != null && _videoController!.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : mediaUrl != null
                      ? (mediaUrl.startsWith('http')
                          ? Image.network(
                              mediaUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildTextFallback(),
                            )
                          : Image.file(
                              File(mediaUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildTextFallback(),
                            ))
                      : _buildTextFallback(),
            ),

            // Left / Right Touch Tap Detectors for Instagram navigation
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _previousStory,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _nextStory,
                    ),
                  ),
                ],
              ),
            ),

            // Gradient Top Overlay for readability
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Top Header: Segmented Progress Lines + User info + Close Button
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Segmented Story Bars (Instagram Style)
                  Row(
                    children: List.generate(widget.stories.length, (index) {
                      final isPassed = index <= _currentIndex;
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isPassed ? Colors.white : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      UserAvatar(imageUrl: avatar, radius: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Story ${_currentIndex + 1} of ${widget.stories.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Bar: Reaction / Reply for viewers or Add New for host
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: widget.isMyStory
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CameraRecorderScreen()));
                            },
                            icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                            label: const Text('Add Another Story', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Send message to $authorName...',
                              hintStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.2),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 28),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Liked story! ❤️'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
