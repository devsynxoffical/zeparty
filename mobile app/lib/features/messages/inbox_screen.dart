import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/messaging_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/report_sheet.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _selectedFilter = 'All'; // 'All', 'Unread', 'Direct', 'Official', 'Archived'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final messaging = context.watch<MessagingProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (messaging.totalCombinedUnreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${messaging.totalCombinedUnreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_rounded, color: Colors.amberAccent),
            tooltip: 'Admin Broadcast Activity Notice',
            onPressed: () => _showAdminBroadcastComposer(context, isDark),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Activity Area (System Messages, Activity Rewards, Activity Helper)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _buildTopActivityCard(
                    context,
                    title: 'System Messages',
                    icon: Icons.notifications_active_rounded,
                    color: Colors.blueAccent,
                    unreadCount: messaging.systemUnreadCount,
                    preview: messaging.systemMessages.isNotEmpty ? messaging.systemMessages.first.title : 'No notices',
                    onTap: () => _showSystemMessagesSheet(context, isDark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTopActivityCard(
                    context,
                    title: 'Activity Rewards',
                    icon: Icons.card_giftcard_rounded,
                    color: Colors.amberAccent,
                    unreadCount: messaging.rewardsUnreadCount,
                    preview: messaging.activityRewards.isNotEmpty ? messaging.activityRewards.first.title : 'No rewards',
                    onTap: () => _showActivityRewardsSheet(context, isDark),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTopActivityCard(
                    context,
                    title: 'Activity Helper',
                    icon: Icons.lightbulb_rounded,
                    color: Colors.purpleAccent,
                    unreadCount: messaging.helperUnreadCount,
                    preview: messaging.activityHelpers.isNotEmpty ? messaging.activityHelpers.first.title : 'No tips',
                    onTap: () => _showActivityHelperSheet(context, isDark),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search messages, official notices, or contacts...',
                hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // 3. Filter Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: ['All', 'Unread', 'Direct', 'Official', 'Archived'].map((f) {
                final isSel = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      f,
                      style: TextStyle(
                        color: isSel ? Colors.white : AppColors.getTextPrimary(isDark),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: primary,
                    backgroundColor: AppColors.getCard(isDark),
                    onSelected: (_) => setState(() => _selectedFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),

          // 4. Conversation Threads List
          Expanded(
            child: _buildConversationList(context, messaging, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActivityCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required int unreadCount,
    required String preview,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 14, color: color),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              preview,
              style: TextStyle(fontSize: 9, color: AppColors.getTextSecondary(isDark)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(BuildContext context, MessagingProvider messaging, bool isDark) {
    final users = messaging.chatUsers.where((u) {
      final meta = messaging.getMetaForUser(u.id);

      // Filter check
      if (_selectedFilter == 'Unread' && meta.unreadCount == 0) return false;
      if (_selectedFilter == 'Archived' && !meta.isArchived) return false;
      if (_selectedFilter != 'Archived' && meta.isArchived) return false;
      if (meta.isBlocked) return false;

      // Search check
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final msgs = messaging.getMessagesForUser(u.id);
        final lastText = msgs.isNotEmpty ? msgs.last.text.toLowerCase() : '';
        return u.name.toLowerCase().contains(q) || lastText.contains(q);
      }
      return true;
    }).toList();

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('No conversations found', style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (ctx, idx) {
        final user = users[idx];
        final meta = messaging.getMetaForUser(user.id);
        final messages = messaging.getMessagesForUser(user.id);
        final lastMsg = messages.isNotEmpty ? messages.last : null;

        return Card(
          color: AppColors.getCard(isDark),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Stack(
              children: [
                UserAvatar(imageUrl: user.avatarUrl, radius: 22, showVipFrame: user.isVip),
                if (user.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark))),
                const SizedBox(width: 4),
                if (user.isVip)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                    child: Text(user.vipLevel, style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                const Spacer(),
                if (meta.isPinned) const Icon(Icons.push_pin_rounded, size: 14, color: Colors.amberAccent),
                if (meta.isMuted) const Icon(Icons.volume_off_rounded, size: 14, color: Colors.grey),
              ],
            ),
            subtitle: Text(
              lastMsg?.text ?? 'Tap to start conversation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (lastMsg != null)
                  Text(
                    '${lastMsg.timestamp.hour}:${lastMsg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                const SizedBox(height: 4),
                if (meta.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: Text(
                      '${meta.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            onTap: () {
              messaging.markThreadAsRead(user.id);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
            },
            onLongPress: () => _showConversationContextMenu(context, user, meta, messaging, isDark),
          ),
        );
      },
    );
  }

  void _showConversationContextMenu(
    BuildContext context,
    UserModel user,
    ConversationThreadMeta meta,
    MessagingProvider messaging,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (b) => Wrap(
        children: [
          ListTile(
            leading: Icon(meta.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: Colors.amberAccent),
            title: Text(meta.isPinned ? 'Unpin Conversation' : 'Pin to Top', style: const TextStyle(color: Colors.white)),
            onTap: () {
              messaging.togglePin(user.id);
              Navigator.pop(b);
            },
          ),
          ListTile(
            leading: Icon(meta.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: Colors.blueAccent),
            title: Text(meta.isMuted ? 'Unmute Notifications' : 'Mute Notifications', style: const TextStyle(color: Colors.white)),
            onTap: () {
              messaging.toggleMute(user.id);
              Navigator.pop(b);
            },
          ),
          ListTile(
            leading: Icon(meta.unreadCount > 0 ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded, color: Colors.greenAccent),
            title: Text(meta.unreadCount > 0 ? 'Mark as Read' : 'Mark as Unread', style: const TextStyle(color: Colors.white)),
            onTap: () {
              if (meta.unreadCount > 0) {
                messaging.markThreadAsRead(user.id);
              } else {
                messaging.markThreadAsUnread(user.id);
              }
              Navigator.pop(b);
            },
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: Colors.redAccent),
            title: const Text('Block Account', style: TextStyle(color: Colors.white)),
            onTap: () {
              messaging.toggleBlock(user.id);
              Navigator.pop(b);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.name} has been blocked.')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.report_problem_rounded, color: Colors.orangeAccent),
            title: const Text('Report Message / Account', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(b);
              _promptReportDialog(context, user, messaging);
            },
          ),
        ],
      ),
    );
  }

  void _promptReportDialog(BuildContext context, UserModel user, MessagingProvider messaging) {
    ReportSheet.show(
      context,
      targetTitle: user.name,
      reportedUserId: user.id,
    );
  }

  void _showSystemMessagesSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) {
        final messaging = context.watch<MessagingProvider>();
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('System Messages', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => messaging.markAllSystemMessagesRead(),
                    child: const Text('Mark All Read', style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              ...messaging.systemMessages.map((m) => Card(
                    color: const Color(0xFF25213B),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.shield_outlined, color: Colors.white)),
                      title: Text(m.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('${m.content}\n${m.category} • ${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showActivityRewardsSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) {
        final messaging = context.watch<MessagingProvider>();
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Activity Rewards', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => messaging.markAllRewardsRead(),
                    child: const Text('Mark All Read', style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              ...messaging.activityRewards.map((r) => Card(
                    color: const Color(0xFF25213B),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.amberAccent, child: Icon(Icons.emoji_events_rounded, color: Colors.black)),
                      title: Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('${r.description}\nCoins: ${r.rewardCoins} • Status: ${r.status}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      trailing: r.status == 'Claimable'
                          ? ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                              onPressed: () => messaging.claimActivityReward(r.id),
                              child: const Text('Claim', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            )
                          : const Text('Claimed', style: TextStyle(color: Colors.grey)),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showActivityHelperSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) {
        final messaging = context.watch<MessagingProvider>();
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          expand: false,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Activity Helper & Tips', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => messaging.markAllHelpersRead(),
                    child: const Text('Mark All Read', style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              ...messaging.activityHelpers.map((h) => Card(
                    color: const Color(0xFF25213B),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.purpleAccent, child: Icon(Icons.help_outline_rounded, color: Colors.white)),
                      title: Text(h.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Tips: ${h.tips}\nGuidance: ${h.eventGuidance}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showAdminBroadcastComposer(BuildContext context, bool isDark) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String targetType = 'System Messages';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B182B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(b).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Activity Broadcast', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: targetType,
              dropdownColor: const Color(0xFF25213B),
              style: const TextStyle(color: Colors.white),
              items: ['System Messages', 'Activity Rewards', 'Activity Helper']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => targetType = v!,
              decoration: const InputDecoration(labelText: 'Target Category', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Content Body', labelStyle: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.getPrimary(isDark)),
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    context.read<MessagingProvider>().createAdminBroadcast(
                          targetType: targetType,
                          title: titleController.text,
                          content: contentController.text,
                          country: 'GLOBAL',
                          role: 'ALL',
                        );
                    Navigator.pop(b);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Broadcast sent successfully.')));
                  }
                },
                child: const Text('Send Broadcast Notice', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
