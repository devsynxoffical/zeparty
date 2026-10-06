import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/user_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../profile/user_profile_details_screen.dart';

class LiveViewersSheet extends StatefulWidget {
  final List<UserModel> viewers;
  final String roomId;
  final String roomTitle;
  final bool isDark;

  const LiveViewersSheet({
    super.key,
    required this.viewers,
    required this.roomId,
    required this.roomTitle,
    required this.isDark,
  });

  static Future<void> show(
    BuildContext context, {
    required List<UserModel> viewers,
    required String roomId,
    required String roomTitle,
    required bool isDark,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveViewersSheet(
        viewers: viewers,
        roomId: roomId,
        roomTitle: roomTitle,
        isDark: isDark,
      ),
    );
  }

  @override
  State<LiveViewersSheet> createState() => _LiveViewersSheetState();
}

class _LiveViewersSheetState extends State<LiveViewersSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primary = AppColors.getPrimary(isDark);
    final bgColor = isDark ? const Color(0xFF161226) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;

    final filteredViewers = widget.viewers.where((v) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.trim().toLowerCase();
      return v.name.toLowerCase().contains(q) ||
          v.username.toLowerCase().contains(q) ||
          v.id.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Live Viewers',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.4), width: 0.8),
                  ),
                  child: Text(
                    '${widget.viewers.length}',
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subtextColor, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF221C38) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: textColor, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search viewers by name or ID...',
                  hintStyle: TextStyle(color: subtextColor, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: subtextColor, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: subtextColor, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Viewers List
          Expanded(
            child: filteredViewers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 48,
                            color: subtextColor.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No viewers found matching "$_searchQuery"'
                                : 'No audience viewers yet',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching with another name or ID'
                                : 'Share your live stream with friends to get more viewers!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subtextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: filteredViewers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.3, color: Colors.white10),
                    itemBuilder: (context, index) {
                      final viewer = filteredViewers[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileDetailsScreen(
                                userId: viewer.id,
                                initialUser: viewer,
                              ),
                            ),
                          );
                        },
                        leading: Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: (viewer.avatarUrl.isNotEmpty)
                                    ? Image.network(
                                        viewer.avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildAvatarFallback(viewer.name),
                                      )
                                    : _buildAvatarFallback(viewer.name),
                              ),
                            ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                viewer.name.isNotEmpty ? viewer.name : viewer.username,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              viewer.countryFlag,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'ID:${viewer.id.length > 8 ? viewer.id.substring(0, 8) : viewer.id} • @${viewer.username}',
                          style: TextStyle(color: subtextColor, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Consumer<AuthProvider>(
                          builder: (ctx, auth, _) {
                            final isFollowing = auth.isFollowing(viewer.id);
                            final isMe = auth.currentUser.id == viewer.id;
                            if (isMe) return const SizedBox.shrink();

                            return GestureDetector(
                              onTap: () {
                                auth.toggleFollow(viewer.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isFollowing
                                          ? 'Unfollowed ${viewer.name}'
                                          : '✔ Following ${viewer.name}!',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isFollowing
                                      ? (isDark ? Colors.white12 : Colors.black12)
                                      : primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFollowing ? Icons.check_rounded : Icons.add_rounded,
                                      color: isFollowing ? textColor : Colors.black,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isFollowing ? 'Following' : 'Follow',
                                      style: TextStyle(
                                        color: isFollowing ? textColor : Colors.black,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      color: const Color(0xFF6C5CE7),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
