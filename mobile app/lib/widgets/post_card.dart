import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/post_model.dart';
import '../core/utils/formatters.dart';
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

  Widget _buildPostImage(String path) {
    final isLocal = !path.startsWith('http://') && !path.startsWith('https://');
    final file = isLocal ? File(path.replaceFirst('file://', '')) : null;

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
        path,
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
          Text('Image unavailable', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              UserAvatar(imageUrl: post.author.avatarUrl, radius: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppFormatters.formatTimeAgo(post.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final isFollowing = auth.isFollowing(post.author.id);
                  final isMe = auth.currentUser.id == post.author.id;
                  if (isMe) return const SizedBox.shrink();

                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isFollowing ? Colors.grey : AppColors.primary),
                      backgroundColor: isFollowing ? Colors.grey.withValues(alpha: 0.15) : Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    ),
                    onPressed: () {
                      auth.toggleFollow(post.author.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFollowing ? 'Unfollowed ${post.author.name}' : 'Followed ${post.author.name} ❤️'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
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
              child: _buildPostImage(post.imageUrls.first),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onLike,
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
