import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/skeleton_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifProvider.refreshNotifications(),
        child: notifProvider.isLoading
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: SkeletonList(
                  count: 6,
                  builder: (index) => const SkeletonNotificationRow(),
                ),
              )
            : notifications.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.notifications_off_rounded,
                    title: 'No Notifications Yet',
                    subtitle: 'When hosts you follow go live or you receive gifts, notifications will appear here!',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
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
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                  child: Icon(
                                    _getCategoryIcon(item.category),
                                    color: AppColors.primary,
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
                              notifProvider.markAsRead(item.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'follower':
        return Icons.person_add_rounded;
      case 'recharge':
        return Icons.account_balance_wallet_rounded;
      case 'invitation':
        return Icons.style_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}
