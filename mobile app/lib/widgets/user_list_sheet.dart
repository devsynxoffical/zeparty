import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/repositories/social_repository.dart';
import '../core/theme/app_colors.dart';
import '../features/profile/user_profile_details_screen.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'user_avatar.dart';

/// Social User item model with relationship status
class SocialUserItem {
  final UserModel user;
  bool isFollowing;
  final bool isFollowedBy;
  bool isMutual;

  SocialUserItem({
    required this.user,
    required this.isFollowing,
    required this.isFollowedBy,
    required this.isMutual,
  });

  factory SocialUserItem.fromJson(Map<String, dynamic> json) {
    final user = UserModel.fromJson(json);
    final isFollowing = json['isFollowing'] == true;
    final isFollowedBy = json['isFollowedBy'] == true;
    final isMutual = json['isMutual'] == true || (isFollowing && isFollowedBy);
    return SocialUserItem(
      user: user,
      isFollowing: isFollowing,
      isFollowedBy: isFollowedBy,
      isMutual: isMutual,
    );
  }
}

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
  final ScrollController _scrollController = ScrollController();
  List<SocialUserItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _serverTotal = 0;
  bool _isPrivate = false;
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.initialUsers != null && widget.initialUsers!.isNotEmpty) {
      _items = widget.initialUsers!
          .map((u) => SocialUserItem(user: u, isFollowing: false, isFollowedBy: false, isMutual: false))
          .toList();
      _serverTotal = _items.length;
    } else if (widget.userId != null && widget.userId!.isNotEmpty) {
      _loadUsersFromBackend(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore && !_isPrivate) {
        _loadUsersFromBackend(isRefresh: false);
      }
    }
  }

  Future<void> _loadUsersFromBackend({bool isRefresh = false}) async {
    final currentRequestId = ++_requestId;
    if (isRefresh) {
      _page = 1;
      _hasMore = false;
    }

    setState(() {
      if (isRefresh) {
        _isLoading = _items.isEmpty;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
      _isPrivate = false;
    });

    try {
      final isFollowers = widget.title.toLowerCase().contains('follower');
      final res = isFollowers
          ? await SocialRepository.instance.fetchFollowers(widget.userId!, page: _page, limit: 20)
          : await SocialRepository.instance.fetchFollowing(widget.userId!, page: _page, limit: 20);

      if (_requestId != currentRequestId || !mounted) return;

      if (res['isPrivate'] == true) {
        final total = res['pagination']?['total'] ?? res['pagination']?['totalCount'] ?? 0;
        setState(() {
          _isPrivate = true;
          _serverTotal = total is int ? total : (int.tryParse(total.toString()) ?? 0);
          _items = [];
          _isLoading = false;
          _isLoadingMore = false;
        });
        return;
      }

      final rawList = res['data'] ?? res['followers'] ?? res['following'] ?? [];
      final List<SocialUserItem> loaded = [];

      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            loaded.add(SocialUserItem.fromJson(item));
          } else if (item is UserModel) {
            loaded.add(SocialUserItem(user: item, isFollowing: false, isFollowedBy: false, isMutual: false));
          }
        }
      }

      final pagination = res['pagination'] as Map<String, dynamic>?;
      final total = pagination?['total'] ?? pagination?['totalCount'];
      final totalParsed = total is int ? total : (total != null ? int.tryParse(total.toString()) : null);

      setState(() {
        if (isRefresh || _page == 1) {
          _items = loaded;
        } else {
          _items.addAll(loaded);
        }
        _serverTotal = totalParsed ?? _items.length;
        _isLoading = false;
        _isLoadingMore = false;
        _hasMore = loaded.length >= 20;
        if (_hasMore) {
          _page++;
        }
      });
    } catch (e) {
      if (_requestId != currentRequestId || !mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _errorMessage = 'Failed to load ${widget.title.toLowerCase()}';
      });
    }
  }

  Future<void> _toggleFollow(SocialUserItem item, AuthProvider auth) async {
    final targetId = item.user.id;
    final wasFollowing = item.isFollowing;

    setState(() {
      item.isFollowing = !wasFollowing;
      item.isMutual = item.isFollowing && item.isFollowedBy;
    });

    try {
      if (wasFollowing) {
        await SocialRepository.instance.unfollowUser(targetId);
      } else {
        await SocialRepository.instance.followUser(targetId);
      }
      auth.toggleFollow(targetId);
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isFollowing = wasFollowing;
          item.isMutual = item.isFollowing && item.isFollowedBy;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  Widget _buildActionButton(SocialUserItem item, AuthProvider auth, bool isDark) {
    final isMe = auth.currentUser.id == item.user.id ||
        (auth.currentUser.publicUserId.isNotEmpty && auth.currentUser.publicUserId == item.user.publicUserId);
    if (isMe) return const SizedBox.shrink();

    final isFollowing = item.isFollowing || auth.isFollowing(item.user.id);
    final isMutual = item.isMutual;
    final isFollowedBy = item.isFollowedBy;

    String buttonText;
    Color borderColor;
    Color bgColor;
    Color textColor;

    if (isFollowing) {
      if (isMutual) {
        buttonText = 'Friends';
        borderColor = Colors.purpleAccent;
        bgColor = Colors.purpleAccent.withValues(alpha: 0.15);
        textColor = Colors.purpleAccent;
      } else {
        buttonText = 'Following';
        borderColor = Colors.grey;
        bgColor = Colors.grey.withValues(alpha: 0.15);
        textColor = Colors.grey;
      }
    } else {
      if (isFollowedBy) {
        buttonText = 'Follow Back';
        borderColor = const Color(0xFFFF4081);
        bgColor = const Color(0xFFFF4081).withValues(alpha: 0.15);
        textColor = const Color(0xFFFF4081);
      } else {
        buttonText = 'Follow';
        borderColor = const Color(0xFF00E5FF);
        bgColor = const Color(0xFF00E5FF).withValues(alpha: 0.15);
        textColor = const Color(0xFF00E5FF);
      }
    }

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: borderColor),
        backgroundColor: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      onPressed: () => _toggleFollow(item, auth),
      child: Text(
        buttonText,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayTotal = _serverTotal > 0 ? _serverTotal : _items.length;
    final titleString = _isPrivate
        ? '${widget.title} ($displayTotal)'
        : (_isLoading && _items.isEmpty ? widget.title : '${widget.title} ($displayTotal)');

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
                  titleString,
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
                                  onPressed: () => _loadUsersFromBackend(isRefresh: true),
                                  child: const Text('Try Again', style: TextStyle(color: AppColors.primary)),
                                ),
                              ],
                            ),
                          )
                        : _items.isEmpty
                            ? Center(
                                child: Text(
                                  'No ${widget.title.toLowerCase()} to display',
                                  style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 13),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _loadUsersFromBackend(isRefresh: true),
                                color: AppColors.primary,
                                child: ListView.separated(
                                  controller: _scrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                                  separatorBuilder: (context, index) => Divider(
                                    color: AppColors.getBorder(isDark).withValues(alpha: 0.5),
                                    height: 12,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == _items.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                        ),
                                      );
                                    }

                                    final item = _items[index];
                                    final u = item.user;

                                    return Consumer<AuthProvider>(
                                      builder: (context, auth, _) {
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => UserProfileDetailsScreen(
                                                  userId: u.effectivePublicId,
                                                ),
                                              ),
                                            );
                                          },
                                          leading: UserAvatar(imageUrl: u.avatarUrl, radius: 22, isLive: u.isLive),
                                          title: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  u.displayName.isNotEmpty
                                                      ? u.displayName
                                                      : (u.name.isNotEmpty
                                                          ? u.name
                                                          : (u.id.isNotEmpty ? 'User ${u.id}' : 'User')),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: AppColors.getTextPrimary(isDark),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              if (u.svipLevel > 0) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.amber, width: 0.8),
                                                  ),
                                                  child: Text(
                                                    'SVIP ${u.svipLevel}',
                                                    style: const TextStyle(
                                                      color: Colors.amber,
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          subtitle: Text(
                                            'ID: ${u.effectivePublicId}',
                                            style: TextStyle(
                                              color: AppColors.getTextSecondary(isDark),
                                              fontSize: 11,
                                            ),
                                          ),
                                          trailing: _buildActionButton(item, auth, isDark),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
