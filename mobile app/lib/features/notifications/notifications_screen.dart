import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/notification_provider.dart';
import '../../core/services/fcm_service.dart';
import '../../widgets/skeleton_widgets.dart';
import '../settings/notification_settings_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMoreNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifications = notifProvider.notifications;
    final unreadCount = notifProvider.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.live,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => notifProvider.markAllAsRead(),
              child: const Text('Mark all read', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Notification Preferences',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifProvider.refreshNotifications(),
        child: notifProvider.isLoading && notifications.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: SkeletonList(
                  count: 6,
                  builder: (index) => const SkeletonNotificationRow(),
                ),
              )
            : notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                      const EmptyStateWidget(
                        icon: Icons.notifications_off_rounded,
                        title: 'No Notifications Yet',
                        subtitle: 'When you receive gifts, messages, room alerts, or updates, they will appear here!',
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length + (notifProvider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                        );
                      }

                      final item = notifications[index];

                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => notifProvider.deleteNotification(item.id),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? Theme.of(context).cardColor
                                : AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.isRead
                                  ? Theme.of(context).dividerColor
                                  : AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _getCategoryColor(item.type, item.category).withValues(alpha: 0.15),
                                  child: Icon(
                                    _getCategoryIcon(item.type, item.category),
                                    color: _getCategoryColor(item.type, item.category),
                                    size: 20,
                                  ),
                                ),
                                if (!item.isRead)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.live,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(item.message, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Text(
                                  AppFormatters.formatTimeAgo(item.timestamp),
                                  style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                            onTap: () {
                              if (!item.isRead) {
                                notifProvider.markAsRead(item.id);
                              }
                              if (item.dataJson != null) {
                                FcmService.instance.handleNotificationTap(context, item.dataJson);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  IconData _getCategoryIcon(String type, String? category) {
    final t = type.toUpperCase();
    final c = (category ?? '').toLowerCase();

    if (c == 'gift') return Icons.card_giftcard_rounded;
    if (c == 'follower') return Icons.person_add_rounded;
    if (c == 'recharge' || t == 'FINANCE') return Icons.account_balance_wallet_rounded;
    if (c == 'invitation' || t == 'LIVE') return Icons.live_tv_rounded;
    if (t == 'MODERATION') return Icons.shield_outlined;
    if (t == 'SUPPORT') return Icons.support_agent_rounded;
    if (t == 'PK') return Icons.sports_kabaddi_rounded;
    if (t == 'GAMES') return Icons.videogame_asset_rounded;
    if (t == 'EVENTS') return Icons.celebration_rounded;

    return Icons.notifications_rounded;
  }

  Color _getCategoryColor(String type, String? category) {
    final t = type.toUpperCase();
    if (t == 'MODERATION') return Colors.redAccent;
    if (t == 'FINANCE') return Colors.amber;
    if (t == 'LIVE') return Colors.pinkAccent;
    if (t == 'SUPPORT') return Colors.blueAccent;
    return AppColors.primary;
  }
}
