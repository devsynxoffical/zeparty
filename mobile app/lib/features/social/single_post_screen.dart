import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/post_model.dart';
import '../../widgets/user_avatar.dart';

class SinglePostScreen extends StatelessWidget {
  final PostModel post;

  const SinglePostScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  imageUrl: post.author.avatarUrl,
                  name: post.author.name,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.getTextPrimary(isDark),
                      ),
                    ),
                    Text(
                      '@${post.author.username}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (post.content.isNotEmpty)
              Text(
                post.content,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
            const SizedBox(height: 16),
            if (post.imageUrls.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  post.imageUrls.first,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
