import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../core/theme/app_colors.dart';
import '../models/post_model.dart';
import '../core/utils/formatters.dart';
import '../core/utils/auth_guard.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../features/profile/user_profile_details_screen.dart';
import 'report_sheet.dart';
import 'user_avatar.dart';
import 'gift_dialog.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  Widget _buildPostMedia(String path) {
    final cleanPath = path.replaceFirst('file://', '');
    final lower = cleanPath.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        cleanPath.contains('/videos/');

    if (isVideo) {
      return _PostVideoPlayer(videoUrl: cleanPath);
    }

    final isLocal = !cleanPath.startsWith('http://') && !cleanPath.startsWith('https://');
    final file = isLocal ? File(cleanPath) : null;

    if (isLocal && file != null && file.existsSync()) {
      return Image.file(
        file,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    } else {
      return Image.network(
        cleanPath,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageError(),
      );
    }
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      height: 160,
      color: Colors.black12,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_rounded, color: Colors.grey, size: 36),
          SizedBox(height: 6),
          Text('Media unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isMe = auth.currentUser.id.isNotEmpty && (
      auth.currentUser.id == post.author.id ||
      auth.currentUser.username == post.author.username ||
      (auth.currentUser.name.isNotEmpty && post.author.name.toLowerCase() == auth.currentUser.name.toLowerCase()) ||
      (auth.currentUser.displayName.isNotEmpty && post.author.displayName.toLowerCase() == auth.currentUser.displayName.toLowerCase())
    );

    final displayAuthorName = isMe && auth.currentUser.displayName.isNotEmpty
        ? auth.currentUser.displayName
        : (post.author.displayName.isNotEmpty && post.author.displayName != 'Unknown User' ? post.author.displayName : 'Creator');

    final displayAvatarUrl = isMe && auth.currentUser.avatarUrl.isNotEmpty
        ? auth.currentUser.avatarUrl
        : post.author.avatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final targetId = post.author.id.isNotEmpty ? post.author.id : auth.currentUser.id;
                  if (targetId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileDetailsScreen(userId: targetId),
                      ),
                    );
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(imageUrl: displayAvatarUrl, radius: 20),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: post.author.isOnline ? const Color(0xFF00E676) : Colors.grey.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).cardColor, width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final targetId = post.author.id.isNotEmpty ? post.author.id : auth.currentUser.id;
                    if (targetId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileDetailsScreen(userId: targetId),
                        ),
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayAuthorName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AppFormatters.formatTimeAgo(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isMe) ...[
                Consumer<AuthProvider>(
                  builder: (context, authProv, _) {
                    final isFollowing = authProv.isFollowing(post.author.id);

                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isFollowing ? Colors.grey : AppColors.primary),
                        backgroundColor: isFollowing ? Colors.grey.withValues(alpha: 0.15) : Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      ),
                      onPressed: () {
                        AuthGuard.require(context, () {
                          authProv.toggleFollow(post.author.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFollowing ? 'Unfollowed $displayAuthorName' : 'Followed $displayAuthorName ❤️'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }, reason: 'Sign in to follow creators');
                      },
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: isFollowing ? Colors.grey : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'delete') {
                    showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                        title: const Text('Delete Post?'),
                        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dlgCtx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () {
                              Navigator.pop(dlgCtx);
                              context.read<SocialProvider>().deletePost(post.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Post deleted successfully.')),
                              );
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  } else if (val == 'report') {
                    ReportSheet.show(context, targetTitle: 'Post by $displayAuthorName', reportedPostId: post.id);
                  }
                },
                itemBuilder: (ctx) => [
                  if (isMe)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Post', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.amberAccent, size: 20),
                          SizedBox(width: 8),
                          Text('Report Post', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (post.imageUrls.isNotEmpty && post.imageUrls.first.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildPostMedia(post.imageUrls.first),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => AuthGuard.require(context, onLike, reason: 'Sign in to like posts'),
                  child: Row(
                    children: [
                      Icon(
                        post.isLiked ? Icons.favorite : Icons.favorite_border,
                        color: post.isLiked ? AppColors.live : Theme.of(context).iconTheme.color,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text('${post.likes}'),
                    ],
                  ),
                ),
              InkWell(
                onTap: onComment,
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 4),
                    Text('${post.comments}'),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  AuthGuard.require(context, () {
                    final currentUserId = auth.currentUser.id;
                    if (currentUserId.isNotEmpty &&
                        (currentUserId == post.author.id ||
                         (post.author.username.isNotEmpty && currentUserId == post.author.username))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ You cannot send a gift to your own post.'),
                          backgroundColor: Colors.orangeAccent,
                        ),
                      );
                      return;
                    }

                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => GiftDialog(
                        streamerName: displayAuthorName,
                        targetReceiver: post.author,
                        onGiftSent: (gift) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎁 Sent ${gift.name} to $displayAuthorName!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      ),
                    );
                  }, reason: 'Sign in to gift creators');
                },
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 4),
                    Text('Gift'),
                  ],
                ),
              ),
              InkWell(
                onTap: onShare,
                child: Row(
                  children: [
                    const Icon(Icons.share_outlined, size: 20),
                    const SizedBox(width: 4),
                    Text('${post.shares}'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const _PostVideoPlayer({required this.videoUrl});

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final cleanUrl = widget.videoUrl.replaceFirst('file://', '');
      if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(cleanUrl));
      } else {
        _controller = VideoPlayerController.file(File(cleanUrl));
      }
      await _controller!.initialize();
      _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 220,
        color: Colors.black87,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded, color: Colors.grey, size: 36),
              SizedBox(height: 6),
              Text('Video unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        width: double.infinity,
        height: 220,
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: double.infinity,
            height: 220,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (!_controller!.value.isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
        ],
      ),
    );
  }
}
