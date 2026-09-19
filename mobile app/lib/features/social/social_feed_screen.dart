import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load real feed from backend on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final social = context.read<SocialProvider>();
      if (!social.feedLoaded && !social.feedLoading) {
        social.loadFeed();
      }
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
              child: SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    _buildAddStoryItem(auth),
                    ...social.posts.take(6).map((post) => _buildDynamicStoryItem(post)),
                  ],
                ),
              ),
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
                  Tab(text: '🎬 Shorts'),
                  Tab(text: '🔥 Trending'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostFeed(social, isTrending: false),
            const ShortVideosScreen(),
            _buildPostFeed(social, isTrending: true),
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

  Widget _buildAddStoryItem(AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final social = context.watch<SocialProvider>();
    final myStories = social.posts.where((p) =>
      p.author.id == auth.currentUser.id ||
      p.author.name.toLowerCase() == auth.currentUser.name.toLowerCase()
    ).toList();
    final hasStory = myStories.isNotEmpty;
    final latestStory = hasStory ? myStories.first : null;

    return GestureDetector(
      onTap: () {
        AuthGuard.require(context, () {
          if (hasStory && latestStory != null) {
            showDialog(
              context: context,
              builder: (_) => _FullStoryViewerDialog(post: latestStory, isMyStory: true),
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
                gradient: hasStory
                    ? const LinearGradient(
                        colors: [Color(0xFFF9CE34), Color(0xFFEE2A7B), Color(0xFF6228D7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
                    UserAvatar(imageUrl: auth.currentUser.avatarUrl, radius: 22),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.getPrimary(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasStory ? Icons.remove_red_eye_rounded : Icons.add,
                          size: 10,
                          color: AppColors.onPrimary(isDark: isDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasStory ? 'My Story ✨' : 'Your Story',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: hasStory ? FontWeight.bold : FontWeight.w600,
                color: hasStory ? AppColors.getPrimary(isDark) : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicStoryItem(PostModel post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorName = post.author.name.isNotEmpty ? post.author.name : 'User';
    final avatar = post.author.avatarUrl;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => _FullStoryViewerDialog(post: post, isMyStory: false),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFF9CE34), Color(0xFFEE2A7B), Color(0xFF6228D7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.getCard(isDark),
                child: UserAvatar(imageUrl: avatar, radius: 22),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 54,
              child: Text(
                authorName,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600),
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

  Widget _buildPostFeed(SocialProvider social, {required bool isTrending}) {
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

    final posts = isTrending ? social.posts.reversed.toList() : social.posts;

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.post_add_rounded, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('No posts yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                AuthGuard.require(context, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const CreatePostScreen()));
                }, reason: 'Sign in to create posts');
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Post'),
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
  final PostModel post;
  final bool isMyStory;

  const _FullStoryViewerDialog({
    required this.post,
    this.isMyStory = false,
  });

  @override
  State<_FullStoryViewerDialog> createState() => _FullStoryViewerDialogState();
}

class _FullStoryViewerDialogState extends State<_FullStoryViewerDialog> {
  VideoPlayerController? _videoController;
  final TextEditingController _replyController = TextEditingController();
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  Future<void> _initMedia() async {
    final mediaList = widget.post.imageUrls;
    if (mediaList.isNotEmpty) {
      final String url = mediaList.first;
      if (url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.m4v') || !url.startsWith('http')) {
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
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint('Story video error: $e');
        }
      }
    }
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
          widget.post.content.isNotEmpty ? widget.post.content : '✨ ZeParty Story',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.post.author.name.isNotEmpty ? widget.post.author.name : 'User';
    final avatar = widget.post.author.avatarUrl;
    final mediaList = widget.post.imageUrls;
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
                              errorBuilder: (_, __, ___) => _buildTextFallback(),
                            )
                          : Image.file(
                              File(mediaUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildTextFallback(),
                            ))
                      : _buildTextFallback(),
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

            // Top Header: User info + Close Button
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  // Progress indicator line
                  Container(
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: NetworkImage(avatar.isNotEmpty ? avatar : 'https://i.pravatar.cc/150'),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authorName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const Text(
                            'Just now',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                      const Spacer(),
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
                              SnackBar(content: Text('❤️ Reacted to $authorName\'s story!')),
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
