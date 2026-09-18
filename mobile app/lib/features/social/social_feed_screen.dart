import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_guard.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/app_logo.dart';
import 'create_post_screen.dart';
import 'short_videos_screen.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _stories = [
    {'name': 'Your Story', 'emoji': '➕', 'isMe': true},
    {'name': 'Luna', 'emoji': '🌙', 'isMe': false},
    {'name': 'StarX', 'emoji': '⭐', 'isMe': false},
    {'name': 'NeonX', 'emoji': '💜', 'isMe': false},
    {'name': 'SkyDJ', 'emoji': '🎧', 'isMe': false},
    {'name': 'Aria', 'emoji': '🎤', 'isMe': false},
    {'name': 'Leo', 'emoji': '🦁', 'isMe': false},
  ];

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
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _stories.length,
                  itemBuilder: (context, index) {
                    final story = _stories[index];
                    final bool isMe = story['isMe'] as bool;
                    return _buildStoryItem(story, isMe, auth);
                  },
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

  Widget _buildStoryItem(Map<String, dynamic> story, bool isMe, AuthProvider auth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        AuthGuard.require(context, () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isMe ? 'Add your story' : 'Viewing ${story['name']}\'s story'),
              duration: const Duration(seconds: 1),
            ),
          );
        }, reason: 'Sign in to view stories');
      },
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: isMe ? null : AppColors.getAccentGradient(isDark),
                shape: BoxShape.circle,
                color: isMe ? AppColors.getPrimary(isDark).withValues(alpha: 0.3) : null,
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.getCard(isDark),
                child: isMe
                    ? Stack(
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
                              child: Icon(Icons.add, size: 10, color: AppColors.onPrimary(isDark: isDark)),
                            ),
                          ),
                        ],
                      )
                    : Text(story['emoji'] as String, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              story['name'] as String,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
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
            onShare: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post link copied to clipboard! 🚀')),
              );
            },
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
