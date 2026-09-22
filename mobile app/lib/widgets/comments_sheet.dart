import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/auth_guard.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import '../features/profile/user_profile_details_screen.dart';
import 'user_avatar.dart';

/// Reusable TikTok/ZeParty Slide-up Comments Sheet.
/// Works across Short Videos, Social Posts, Live Rooms, and PK Battles.
class CommentsSheet extends StatefulWidget {
  final String targetId; // Post ID or Video ID
  final String title;
  final bool isPost; // If true, loads real comments from backend
  final List<SocialComment>? initialComments;
  final Function(String text)? onCommentSubmitted;

  const CommentsSheet({
    super.key,
    required this.targetId,
    this.title = 'Comments',
    this.isPost = true,
    this.initialComments,
    this.onCommentSubmitted,
  });

  static void show(
    BuildContext context, {
    required String targetId,
    String title = 'Comments',
    bool isPost = true,
    List<SocialComment>? initialComments,
    Function(String text)? onCommentSubmitted,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => CommentsSheet(
        targetId: targetId,
        title: title,
        isPost: isPost,
        initialComments: initialComments,
        onCommentSubmitted: onCommentSubmitted,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SocialComment> _localComments = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialComments != null) {
      _localComments = List.from(widget.initialComments!);
    } else if (widget.isPost) {
      // Trigger backend load via provider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SocialProvider>().loadCommentsForPost(widget.targetId);
      });
    } else {
      _localComments = [];
    }
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    AuthGuard.require(context, () {
      final currentUser = context.read<AuthProvider>().currentUser;
      final social = context.read<SocialProvider>();

      setState(() => _isSubmitting = true);

      final newComment = SocialComment(
        id: 'c_${DateTime.now().millisecondsSinceEpoch}',
        authorId: currentUser.id,
        authorName: currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : (currentUser.name.isNotEmpty ? currentUser.name : currentUser.username),
        authorAvatar: currentUser.avatarUrl,
        text: text,
        createdAt: DateTime.now(),
        likesCount: 0,
        isLiked: false,
      );

      setState(() {
        _localComments.insert(0, newComment);
      });

      if (widget.isPost) {
        social.addCommentToPost(widget.targetId, text, currentUser);
      } else {
        social.addCommentToShortVideo(widget.targetId, text, currentUser);
      }

      if (mounted) setState(() => _isSubmitting = false);

      widget.onCommentSubmitted?.call(text);
      _commentController.clear();
      _focusNode.unfocus();
    }, reason: 'Sign in to leave a comment');
  }

  void _toggleLike(int index) {
    AuthGuard.require(context, () {
      if (!widget.isPost) {
        // Local toggle for short-video comments
        setState(() {
          final comment = _localComments[index];
          final newIsLiked = !comment.isLiked;
          final newCount = newIsLiked ? comment.likesCount + 1 : comment.likesCount - 1;
          _localComments[index] = SocialComment(
            id: comment.id,
            authorId: comment.authorId,
            authorName: comment.authorName,
            authorAvatar: comment.authorAvatar,
            text: comment.text,
            createdAt: comment.createdAt,
            likesCount: newCount < 0 ? 0 : newCount,
            isLiked: newIsLiked,
          );
        });
      }
    }, reason: 'Sign in to like comments');
  }

  void _insertQuickEmoji(String emoji) {
    _commentController.text = '${_commentController.text}$emoji';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Build the final displayed comment list
  List<SocialComment> _resolveComments(SocialProvider social) {
    final providerComments = widget.isPost
        ? social.getCommentsForPost(widget.targetId)
        : social.getCommentsForVideo(widget.targetId);

    if (providerComments.isNotEmpty) {
      return providerComments;
    }
    return _localComments;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;
    final social = context.watch<SocialProvider>();
    final comments = _resolveComments(social);
    final isLoadingComments = widget.isPost && social.isPostCommentsLoading(widget.targetId);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      duration: const Duration(milliseconds: 150),
      child: Container(
        height: mediaQuery.size.height * 0.65,
        decoration: BoxDecoration(
          color: const Color(0xFF120B24),
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
            // Drag Handle Indicator
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${widget.title} (${comments.length}) 💬',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Comments List View
            Expanded(
              child: isLoadingComments
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E24AA), strokeWidth: 2))
                  : comments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 8),
                          Text(
                            'No comments yet. Be the first!',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final timeAgo = _formatTimeAgo(c.createdAt);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (c.authorId.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: c.authorId)),
                                  );
                                }
                              },
                              child: UserAvatar(imageUrl: c.authorAvatarUrl, radius: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          if (c.authorId.isNotEmpty) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: c.authorId)),
                                            );
                                          }
                                        },
                                        child: Text(
                                          c.authorName,
                                          style: const TextStyle(
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c.text,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Like Comment Button
                            GestureDetector(
                              onTap: () => _toggleLike(index),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    c.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: c.isLiked ? const Color(0xFFFF4081) : Colors.white38,
                                    size: 18,
                                  ),
                                  if (c.likesCount > 0)
                                    Text(
                                      '${c.likesCount}',
                                      style: TextStyle(
                                        color: c.isLiked ? const Color(0xFFFF4081) : Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),

            // Bottom Quick Emojis Dock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.black.withValues(alpha: 0.3),
              child: Row(
                children: ['🔥', '💖', '👏', '👑', '🚀', '✨'].map((emoji) {
                  return GestureDetector(
                    onTap: () => _insertQuickEmoji(emoji),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Bottom Input Bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1035),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                ),
                child: Row(
                  children: [
                    UserAvatar(imageUrl: currentUser.avatarUrl, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _commentController,
                          focusNode: _focusNode,
                          onSubmitted: (_) => _submitComment(),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE040FB), Color(0xFFFF4081)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
