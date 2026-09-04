import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../features/profile/user_profile_details_screen.dart';
import 'user_avatar.dart';

/// Reusable Slide-up Sheet for displaying Followers and Following user lists.
class UserListSheet extends StatelessWidget {
  final String title;
  final List<UserModel> users;

  const UserListSheet({
    super.key,
    required this.title,
    required this.users,
  });

  static void show(BuildContext context, String title, List<UserModel> users) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => UserListSheet(title: title, users: users),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: mediaQuery.size.height * 0.68,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF120B24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white38 : Colors.black26,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '$title (${users.length})',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(isDark),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.getTextSecondary(isDark), size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: AppColors.getBorder(isDark), height: 1),

          // User List
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Text(
                      'No users to display',
                      style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: users.length,
                    separatorBuilder: (context, index) => Divider(color: AppColors.getBorder(isDark).withValues(alpha: 0.5), height: 12),
                    itemBuilder: (context, index) {
                      final u = users[index];

                      return Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final isFollowing = auth.isFollowing(u.id);
                          final isMe = auth.currentUser.id == u.id;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileDetailsScreen(userId: u.id),
                                ),
                              );
                            },
                            leading: UserAvatar(imageUrl: u.avatarUrl, radius: 22, isLive: u.isLive),
                            title: Text(
                              u.name,
                              style: TextStyle(
                                color: AppColors.getTextPrimary(isDark),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '@${u.username}',
                              style: TextStyle(
                                color: AppColors.getTextSecondary(isDark),
                                fontSize: 11,
                              ),
                            ),
                            trailing: isMe
                                ? const SizedBox.shrink()
                                : OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: isFollowing ? Colors.grey : const Color(0xFF00E5FF),
                                      ),
                                      backgroundColor: isFollowing
                                          ? Colors.grey.withValues(alpha: 0.15)
                                          : const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    ),
                                    onPressed: () {
                                      auth.toggleFollow(u.id);
                                    },
                                    child: Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowing ? Colors.grey : const Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
