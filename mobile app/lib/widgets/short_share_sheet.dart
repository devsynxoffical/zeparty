import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/messaging_provider.dart';
import '../core/repositories/backend_repository.dart';
import 'user_avatar.dart';

class ShortShareSheet extends StatefulWidget {
  final String shortId;
  final String? title;

  const ShortShareSheet({
    super.key,
    required this.shortId,
    this.title,
  });

  static Future<void> show(BuildContext context, {required String shortId, String? title}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ShortShareSheet(shortId: shortId, title: title),
    );
  }

  @override
  State<ShortShareSheet> createState() => _ShortShareSheetState();
}

class _ShortShareSheetState extends State<ShortShareSheet> {
  final Set<String> _sentUserIds = {};

  String get _shortLink => 'https://zeparty.app/short/${widget.shortId}';

  void _copyLink(BuildContext context, String message) {
    Clipboard.setData(ClipboardData(text: _shortLink));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendToFriend(BuildContext context, UserModel friend) async {
    final auth = context.read<AuthProvider>();
    final messaging = context.read<MessagingProvider>();

    if (auth.currentUser.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to send messages to friends.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    try {
      final shareMessage = 'Check out this Short! 🎬\n$_shortLink';
      await messaging.sendMessage(
        friend.id,
        shareMessage,
        currentUserId: auth.currentUser.id,
      );

      if (context.mounted) {
        setState(() {
          _sentUserIds.add(friend.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Sent Short to @${friend.username.isNotEmpty ? friend.username : friend.displayName}!'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send short: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final auth = context.watch<AuthProvider>();
    final messaging = context.watch<MessagingProvider>();
    final currentUserId = auth.currentUser.id;

    // Build contacts list combining messaging conversation users, followed accounts, and popular users
    final Map<String, UserModel> contactsMap = {};

    // 1. Existing DM contacts
    for (final user in messaging.chatUsers) {
      if (user.id.isNotEmpty && user.id != currentUserId) {
        contactsMap[user.id] = user;
      }
    }

    // 2. Followed users
    for (final followedId in auth.followingUserIds) {
      if (followedId.isNotEmpty && followedId != currentUserId && !contactsMap.containsKey(followedId)) {
        contactsMap[followedId] = UserModel(
          id: followedId,
          username: 'user_$followedId',
          name: 'ZeParty Friend',
          avatarUrl: '',
        );
      }
    }

    // 3. Popular users fallback to ensure active list for demonstration
    for (final popular in BackendRepository.instance.popularUsers) {
      if (popular.id.isNotEmpty && popular.id != currentUserId && !contactsMap.containsKey(popular.id)) {
        contactsMap[popular.id] = popular;
      }
    }

    final contactsList = contactsMap.values.toList();

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title Header
          Row(
            children: [
              const Icon(Icons.share_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title != null && widget.title!.isNotEmpty
                      ? 'Share "${widget.title}"'
                      : 'Share Short Video',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Generated Valid Short Link Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _shortLink,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
                  onPressed: () => _copyLink(context, '✅ Short link copied to clipboard!'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // External Share Shortcuts Row (WhatsApp, Telegram, Copy Link)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildExternalOption(
                context,
                icon: Icons.chat_bubble_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _copyLink(context, '✅ WhatsApp share link copied! Paste in WhatsApp chat.'),
              ),
              _buildExternalOption(
                context,
                icon: Icons.send_rounded,
                label: 'Telegram',
                color: const Color(0xFF0088CC),
                onTap: () => _copyLink(context, '✅ Telegram share link copied! Paste in Telegram chat.'),
              ),
              _buildExternalOption(
                context,
                icon: Icons.link_rounded,
                label: 'Copy Link',
                color: AppColors.primary,
                onTap: () => _copyLink(context, '✅ Link copied! Send to anyone to watch.'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // FRIENDS SECTION HEADER
          Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Friends',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${contactsList.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // FRIENDS LIST & EMPTY STATE
          if (contactsList.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.person_search_rounded, size: 36, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'No friends or followed creators yet',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Follow creators or chat with members to send Shorts directly to their inbox.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.getTextSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: contactsList.length,
                itemBuilder: (context, index) {
                  final friend = contactsList[index];
                  final isSent = _sentUserIds.contains(friend.id);

                  return Container(
                    width: 86,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(
                          imageUrl: friend.avatarUrl,
                          name: friend.displayName,
                          radius: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          friend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 26,
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSent ? AppColors.success : primaryColor,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 0,
                            ),
                            onPressed: isSent ? null : () => _sendToFriend(context, friend),
                            child: Text(
                              isSent ? 'Sent ✔' : 'Send',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildExternalOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
