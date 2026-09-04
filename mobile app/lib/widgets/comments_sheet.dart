import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';
import 'user_avatar.dart';

/// Reusable TikTok/ZeParty Slide-up Comments Sheet.
/// Works across Short Videos, Social Posts, Live Rooms, and PK Battles.
class CommentsSheet extends StatefulWidget {
  final String targetId; // Post ID or Video ID
  final String title;
  final List<SocialComment>? initialComments;
  final Function(String text)? onCommentSubmitted;

  const CommentsSheet({
    super.key,
    required this.targetId,
    this.title = 'Comments',
    this.initialComments,
    this.onCommentSubmitted,
  });

  static void show(
    BuildContext context, {
    required String targetId,
    String title = 'Comments',
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

  late List<SocialComment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = widget.initialComments != null
        ? List.from(widget.initialComments!)
        : _generateSampleComments();
  }

  List<SocialComment> _generateSampleComments() {
    final now = DateTime.now();
    return [
      SocialComment(
        id: 'c_1',
        authorId: 'u_sophia',
        authorName: 'Sophia Rose 💖',
        authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        text: 'Wow! This stream/video is super amazing! 🔥',
        createdAt: now.subtract(const Duration(minutes: 5)),
        likesCount: 24,
        isLiked: true,
      ),
      SocialComment(
        id: 'c_2',
        authorId: 'u_usman',
        authorName: 'Usman Jutt 👑',
        authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        text: 'Team Blue support kar rahe hain full support! 🚀💙',
        createdAt: now.subtract(const Duration(minutes: 18)),
        likesCount: 15,
      ),
      SocialComment(
        id: 'c_3',
        authorId: 'u_sana',
        authorName: 'Sana Mughal ✨',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        text: 'Super high quality live battle performance! 👏',
        createdAt: now.subtract(const Duration(hours: 1)),
        likesCount: 8,
      ),
      SocialComment(
        id: 'c_4',
        authorId: 'u_ali',
        authorName: 'Ali Khan 🔥',
        authorAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        text: 'Gift combo level 4 blast standard video content! 👑',
        createdAt: now.subtract(const Duration(hours: 3)),
        likesCount: 42,
        isLiked: true,
      ),
    ];
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = context.read<AuthProvider>().currentUser;
    final now = DateTime.now();

    final newComment = SocialComment(
      id: 'c_${now.millisecondsSinceEpoch}',
      authorId: currentUser.id,
      authorName: currentUser.name,
      authorAvatar: currentUser.avatarUrl,
      text: text,
      createdAt: now,
    );

    setState(() {
      _comments.insert(0, newComment);
    });

    try {
      context.read<SocialProvider>().addCommentToShortVideo(widget.targetId, text, currentUser);
    } catch (_) {}

    widget.onCommentSubmitted?.call(text);

    _commentController.clear();
    _focusNode.unfocus();
  }

  void _toggleLike(int index) {
    setState(() {
      final comment = _comments[index];
      final newIsLiked = !comment.isLiked;
      final newCount = newIsLiked ? comment.likesCount + 1 : comment.likesCount - 1;

      _comments[index] = SocialComment(
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;

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
                    '${widget.title} (${_comments.length}) 💬',
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
              child: _comments.isEmpty
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
                      itemCount: _comments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        final timeAgo = _formatTimeAgo(c.createdAt);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UserAvatar(imageUrl: c.authorAvatarUrl, radius: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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
