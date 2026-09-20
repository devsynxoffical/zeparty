import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/messaging_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/report_sheet.dart';
import '../profile/user_profile_details_screen.dart';
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
  Timer? _searchDebounce;
  List<UserModel> _searchedUsers = [];
  bool _isSearchingBackend = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessagingProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });

    _searchDebounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _searchedUsers = [];
        _isSearchingBackend = false;
      });
      return;
    }

    setState(() {
      _isSearchingBackend = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final results = await context.read<MessagingProvider>().searchUsers(val);
      if (mounted) {
        setState(() {
          _searchedUsers = results;
          _isSearchingBackend = false;
        });
      }
    });
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Messages',
            onPressed: () => messaging.loadConversations(),
          ),
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
              onChanged: _onSearchChanged,
              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search users by name, @username, or phone...',
                hintStyle: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.getCard(isDark),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          // 3. Filter Chips Bar (hidden if actively searching)
          if (_searchQuery.isEmpty)
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

          // 4. Conversation Threads & Global User Search Results List
          Expanded(
            child: _buildBodyContent(context, messaging, isDark),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.getTextPrimary(isDark)),
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

  Widget _buildBodyContent(BuildContext context, MessagingProvider messaging, bool isDark) {
    if (_searchQuery.trim().isNotEmpty) {
      return _buildSearchResults(context, messaging, isDark);
    }
    return _buildConversationList(context, messaging, isDark);
  }

  Widget _buildSearchResults(BuildContext context, MessagingProvider messaging, bool isDark) {
    if (_isSearchingBackend) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_searchedUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 48, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text(
              'No users found matching "$_searchQuery"',
              style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching by username, display name, or phone number',
              style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchedUsers.length,
      itemBuilder: (ctx, idx) {
        final user = _searchedUsers[idx];
        return Card(
          color: AppColors.getCard(isDark),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                );
              },
              child: UserAvatar(imageUrl: user.avatarUrl, radius: 22, showVipFrame: user.isVip),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.name.isNotEmpty ? user.name : user.username,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                if (user.username.isNotEmpty)
                  Text(
                    '@${user.username}',
                    style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                  ),
              ],
            ),
            subtitle: Text(
              user.bio.isNotEmpty ? user.bio : 'Tap to open chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.person_outline_rounded, color: Colors.blueAccent, size: 20),
                  tooltip: 'View Profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF00A884), size: 20),
                  tooltip: 'Send Message',
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
                  },
                ),
              ],
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user: user)));
            },
          ),
        );
      },
    );
  }

  Widget _buildConversationList(BuildContext context, MessagingProvider messaging, bool isDark) {
    if (messaging.isLoadingConversations && messaging.chatUsers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final users = messaging.chatUsers.where((u) {
      final meta = messaging.getMetaForUser(u.id);

      // Filter check
      if (_selectedFilter == 'Unread' && meta.unreadCount == 0) return false;
      if (_selectedFilter == 'Archived' && !meta.isArchived) return false;
      if (_selectedFilter != 'Archived' && meta.isArchived) return false;
      if (meta.isBlocked) return false;

      return true;
    }).toList();

    if (users.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => messaging.loadConversations(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 56, color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No conversations yet',
                    style: TextStyle(color: AppColors.getTextPrimary(isDark), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search users above to start chatting!',
                    style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => messaging.loadConversations(),
      child: ListView.builder(
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
              leading: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
                  );
                },
                child: Stack(
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
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name.isNotEmpty ? user.name : user.username,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.getTextPrimary(isDark)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (user.isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                      child: Text(user.vipLevel, style: const TextStyle(fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  if (user.isLive) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                      child: const Text('🔴 LIVE', style: TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  if (meta.isPinned) const Icon(Icons.push_pin_rounded, size: 14, color: Colors.amberAccent),
                  if (meta.isMuted) const Icon(Icons.volume_off_rounded, size: 14, color: Colors.grey),
                ],
              ),
              subtitle: messaging.isUserTyping(user.id)
                  ? const Text(
                      'typing...',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                    )
                  : Text(
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
      ),
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
            leading: const Icon(Icons.person_rounded, color: Colors.purpleAccent),
            title: const Text('View Full Profile', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(b);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => UserProfileDetailsScreen(userId: user.id)),
              );
            },
          ),
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
    context.read<MessagingProvider>().markAllSystemMessagesRead();
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
              if (messaging.systemMessages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No system messages', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                ...messaging.systemMessages.map((m) => Card(
                      color: const Color(0xFF26213B),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          m.category == 'Security' ? Icons.security_rounded : Icons.account_balance_wallet_rounded,
                          color: Colors.blueAccent,
                        ),
                        title: Text(m.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(m.content, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        trailing: Text(
                          '${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                        onTap: () => messaging.markSystemMessageRead(m.id),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showActivityRewardsSheet(BuildContext context, bool isDark) {
    context.read<MessagingProvider>().markAllRewardsRead();
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
              if (messaging.activityRewards.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No activity rewards available', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                ...messaging.activityRewards.map((r) => Card(
                      color: const Color(0xFF26213B),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.card_giftcard_rounded, color: Colors.amberAccent),
                        title: Text(r.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${r.description}\nReward: ${r.rewardCoins} Coins', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: r.status == 'Claimable' ? Colors.amber : Colors.grey,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: r.status == 'Claimable'
                              ? () {
                                  messaging.claimActivityReward(r.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('🎉 Claimed ${r.rewardCoins} Coins! Transaction: ${r.transactionRef}')),
                                  );
                                }
                              : null,
                          child: Text(r.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showActivityHelperSheet(BuildContext context, bool isDark) {
    context.read<MessagingProvider>().markAllHelpersRead();
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
                  const Text('Activity Helper & Event Tips', style: TextStyle(color: Colors.purpleAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => messaging.markAllHelpersRead(),
                    child: const Text('Mark All Read', style: TextStyle(color: Colors.greenAccent)),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              if (messaging.activityHelpers.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No activity tips', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                )
              else
                ...messaging.activityHelpers.map((h) => Card(
                      color: const Color(0xFF26213B),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: const Icon(Icons.lightbulb_rounded, color: Colors.purpleAccent),
                        title: Text(h.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${h.tips}\n${h.eventGuidance}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        onTap: () => messaging.markHelperRead(h.id),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }

  void _showAdminBroadcastComposer(BuildContext context, bool isDark) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String targetType = 'System Messages';
    String country = 'ALL';
    String role = 'ALL';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B182B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (b) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Activity Broadcast Notice', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: targetType,
                dropdownColor: const Color(0xFF26213B),
                decoration: const InputDecoration(labelText: 'Notification Stream', labelStyle: TextStyle(color: Colors.white70)),
                items: ['System Messages', 'Activity Rewards', 'Activity Helper']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (val) => setModalState(() => targetType = val ?? targetType),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Broadcast Title', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: contentCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Content Body', labelStyle: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 44),
                ),
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
                    context.read<MessagingProvider>().createAdminBroadcast(
                          targetType: targetType,
                          title: titleCtrl.text.trim(),
                          content: contentCtrl.text.trim(),
                          country: country,
                          role: role,
                        );
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📣 Broadcast dispatched to platform feed!')),
                    );
                  }
                },
                child: const Text('Dispatch Broadcast', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
