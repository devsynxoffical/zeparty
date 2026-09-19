import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../../features/party_room/live_party_room_screen.dart';
import '../../features/live/live_room_screen.dart';
import '../../models/live_room_model.dart';
import '../../models/user_model.dart';

/// Unified Deep Link & Share Service across Live Rooms, Party Rooms, Shorts & Feeds
class RoomShareService {
  RoomShareService._();

  static String generateRoomLink(String roomId) {
    return 'https://zeparty.app/room/$roomId';
  }

  static String generateShortLink(String shortId) {
    return 'https://zeparty.app/short/$shortId';
  }

  static String generatePostLink(String postId) {
    return 'https://zeparty.app/post/$postId';
  }

  /// Show unified Share Sheet with Deep Link & Join capability
  static Future<void> shareRoom(
    BuildContext context, {
    required String roomId,
    String? roomTitle,
    bool isParty = false,
  }) async {
    final link = generateRoomLink(roomId);
    await Clipboard.setData(ClipboardData(text: link));

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getCard(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.share_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      roomTitle != null && roomTitle.isNotEmpty
                          ? 'Share "$roomTitle"'
                          : 'Share Room & Invite Friends',
                      style: TextStyle(
                        color: AppColors.getTextPrimary(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Generated Link Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                        link,
                        style: TextStyle(
                          color: AppColors.getTextPrimary(isDark),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Room join link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShareOption(
                    ctx,
                    icon: Icons.chat_bubble_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _copyAndNotify(ctx, link, 'WhatsApp link copied! Paste in WhatsApp chat.'),
                  ),
                  _buildShareOption(
                    ctx,
                    icon: Icons.send_rounded,
                    label: 'Telegram',
                    color: const Color(0xFF0088CC),
                    onTap: () => _copyAndNotify(ctx, link, 'Telegram link copied! Paste in Telegram chat.'),
                  ),
                  _buildShareOption(
                    ctx,
                    icon: Icons.link_rounded,
                    label: 'Copy Link',
                    color: AppColors.primary,
                    onTap: () => _copyAndNotify(ctx, link, 'Link copied! Send to anyone to join.'),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Test Direct Join Link Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.getPrimary(isDark),
                    foregroundColor: AppColors.onPrimary(isDark: isDark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    final targetRoom = LiveRoomModel(
                      id: roomId,
                      title: roomTitle ?? (isParty ? 'Party Room' : 'Live Stream'),
                      host: const UserModel(id: 'host_user', username: 'host', name: 'Host User', avatarUrl: ''),
                      coverUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80',
                      viewerCount: 1,
                      category: isParty ? 'Party' : 'Music',
                      startTime: DateTime.now(),
                    );

                    if (isParty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LivePartyRoomScreen(room: targetRoom),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveRoomScreen(room: targetRoom),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text('Test Join via Share Link 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  /// Share Short Video with deep link
  static Future<void> shareShort(
    BuildContext context, {
    required String shortId,
    String? title,
  }) async {
    final link = generateShortLink(shortId);
    await Clipboard.setData(ClipboardData(text: link));

    if (!context.mounted) return;
    _showShareDialog(context, title: title ?? 'Short Video', link: link);
  }

  /// Share Social Post with deep link
  static Future<void> sharePost(
    BuildContext context, {
    required String postId,
    String? title,
  }) async {
    final link = generatePostLink(postId);
    await Clipboard.setData(ClipboardData(text: link));

    if (!context.mounted) return;
    _showShareDialog(context, title: title ?? 'Social Post', link: link);
  }

  static void _showShareDialog(BuildContext context, {required String title, required String link}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.share_rounded, color: AppColors.primary, size: 36),
            const SizedBox(height: 12),
            Text(
              'Share $title',
              style: TextStyle(
                color: AppColors.getTextPrimary(isDark),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                link,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Share link copied! Share with your friends.')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy & Share Link'),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildShareOption(
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
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static void _copyAndNotify(BuildContext context, String link, String message) {
    Clipboard.setData(ClipboardData(text: link));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ $message'), duration: const Duration(seconds: 3)),
    );
  }
}
