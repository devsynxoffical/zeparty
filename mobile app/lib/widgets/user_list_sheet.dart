import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/repositories/social_repository.dart';
import '../core/theme/app_colors.dart';
import '../features/profile/user_profile_details_screen.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'user_avatar.dart';

/// Reusable Slide-up Sheet for displaying Followers and Following user lists from backend.
class UserListSheet extends StatefulWidget {
  final String title;
  final String? userId;
  final List<UserModel>? initialUsers;

  const UserListSheet({
    super.key,
    required this.title,
    this.userId,
    this.initialUsers,
  });

  static Future<void> show(
    BuildContext context,
    String title, {
    String? userId,
    List<UserModel>? users,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => UserListSheet(
        title: title,
        userId: userId,
        initialUsers: users,
      ),
    );
  }

  @override
  State<UserListSheet> createState() => _UserListSheetState();
}

class _UserListSheetState extends State<UserListSheet> {
  List<UserModel> _users = [];
  bool _isLoading = false;
  bool _isPrivate = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsers != null && widget.initialUsers!.isNotEmpty) {
      _users = List.from(widget.initialUsers!);
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      _loadUsersFromBackend();
    }
  }

  Future<void> _loadUsersFromBackend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPrivate = false;
    });

    try {
      final isFollowers = widget.title.toLowerCase().contains('follower');
      final res = isFollowers
          ? await SocialRepository.instance.fetchFollowers(widget.userId!)
          : await SocialRepository.instance.fetchFollowing(widget.userId!);

      if (res['isPrivate'] == true) {
        if (mounted) {
          setState(() {
            _isPrivate = true;
            _users = [];
            _isLoading = false;
          });
        }
        return;
      }

      final rawList = res['data'] ?? res['followers'] ?? res['following'] ?? [];
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
          _users = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load ${widget.title.toLowerCase()}';
        });
      }
    }
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
                  _isPrivate
                      ? widget.title
                      : (_isLoading ? widget.title : '${widget.title} (${_users.length})'),
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

          // User List Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  )
                : _isPrivate
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 36,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Private ${widget.title} List',
                                style: TextStyle(
                                  color: AppColors.getTextPrimary(isDark),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This user has set their ${widget.title.toLowerCase()} list to private. Total counts remain visible on their profile.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.getTextSecondary(isDark),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _loadUsersFromBackend,
                                  child: const Text('Try Again', style: TextStyle(color: AppColors.primary)),
                                ),
                              ],
                            ),
                          )
                        : _users.isEmpty
                            ? Center(
                                child: Text(
                                  'No ${widget.title.toLowerCase()} to display',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _users.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: AppColors.getBorder(isDark).withValues(alpha: 0.5),
                                  height: 12,
                                ),
                                itemBuilder: (context, index) {
                                  final u = _users[index];

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
                                          u.displayName.isNotEmpty
                                              ? u.displayName
                                              : (u.name.isNotEmpty ? u.name : u.username),
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
