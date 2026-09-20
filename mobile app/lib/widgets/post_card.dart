import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../core/theme/app_colors.dart';
import '../models/post_model.dart';
import '../core/utils/formatters.dart';
import '../core/utils/auth_guard.dart';
import '../providers/auth_provider.dart';
import 'user_avatar.dart';

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
              UserAvatar(imageUrl: displayAvatarUrl, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayAuthorName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppFormatters.formatTimeAgo(post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isMe)
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
