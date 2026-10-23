import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/notification_model.dart';
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
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: item.isRead
                              ? Theme.of(context).cardColor
                              : AppColors.primary.withValues(alpha: 0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
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
                                if (_isRechargeNotification(item)) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.monetization_on_rounded, size: 14, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            _formatRechargeSubtitle(item),
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                              if (_isRechargeNotification(item)) {
                                _showRechargeDetailsSheet(context, item);
                              } else if (item.dataJson != null) {
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

  bool _isRechargeNotification(AppNotificationModel item) {
    final c = (item.category ?? '').toLowerCase();
    final t = item.type.toUpperCase();
    final nType = item.dataJson?['notificationType']?.toString().toUpperCase();
    return c == 'recharge' ||
        t == 'RECHARGE' ||
        nType == 'RECHARGE_SUCCESS' ||
        (item.dataJson?['transactionId'] != null && item.dataJson?['amountCoins'] != null);
  }

  String _formatRechargeSubtitle(AppNotificationModel item) {
    final sellerName = item.dataJson?['sellerName']?.toString() ?? 'Seller';
    final sellerPublicId = item.dataJson?['sellerPublicId']?.toString();
    final amountCoins = item.dataJson?['amountCoins']?.toString();
    final parts = <String>[];
    if (amountCoins != null) parts.add('+$amountCoins Coins');
    if (sellerPublicId != null) {
      parts.add('from $sellerName (@$sellerPublicId)');
    } else {
      parts.add('from $sellerName');
    }
    return parts.join(' ');
  }

  void _showRechargeDetailsSheet(BuildContext context, AppNotificationModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sellerName = item.dataJson?['sellerName']?.toString() ?? 'Authorized Coin Seller';
    final sellerPublicId = item.dataJson?['sellerPublicId']?.toString() ?? 'Unknown';
    final amountCoins = item.dataJson?['amountCoins']?.toString() ?? '';
    final txId = item.dataJson?['transactionId']?.toString() ??
        item.dataJson?['referenceId']?.toString() ??
        item.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Recharge Transaction Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (amountCoins.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Coins Recharged:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('+$amountCoins Coins 🪙', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 16)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _buildDetailRow('Seller Name', sellerName, isDark),
            _buildDetailRow('Seller Public ID', '@$sellerPublicId', isDark),
            _buildDetailRow('Date', AppFormatters.formatTimeAgo(item.timestamp), isDark),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Transaction ID:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        const SizedBox(height: 2),
                        SelectableText(
                          txId,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Copy Transaction ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: txId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Copied Transaction ID: $txId')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.getPrimary(isDark),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String type, String? category) {
    final t = type.toUpperCase();
    final c = (category ?? '').toLowerCase();

    if (c == 'follower') return Icons.person_add_rounded;
    if (c == 'post' || c == 'like') return Icons.favorite_rounded;
    if (c == 'comment') return Icons.chat_bubble_rounded;
    if (c == 'gift' || t == 'GIFT') return Icons.card_giftcard_rounded;
    if (c == 'recharge' || t == 'RECHARGE') return Icons.monetization_on_rounded;
    if (t == 'FINANCE') return Icons.account_balance_wallet_rounded;
    if (c == 'invitation' || t == 'LIVE') return Icons.live_tv_rounded;
    if (t == 'MODERATION') return Icons.shield_outlined;
    if (t == 'SUPPORT') return Icons.support_agent_rounded;
    if (t == 'PK') return Icons.sports_kabaddi_rounded;
    if (t == 'GAMES') return Icons.videogame_asset_rounded;
    if (t == 'EVENTS') return Icons.celebration_rounded;
    if (t == 'SYSTEM') return Icons.verified_user_rounded;

    return Icons.notifications_rounded;
  }

  Color _getCategoryColor(String type, String? category) {
    final t = type.toUpperCase();
    final c = (category ?? '').toLowerCase();

    if (c == 'follower') return const Color(0xFF8B5CF6);
    if (c == 'post' || c == 'like') return const Color(0xFFF43F5E);
    if (c == 'comment') return const Color(0xFF0EA5E9);
    if (c == 'recharge' || t == 'RECHARGE') return const Color(0xFFFFB300);
    if (t == 'MODERATION') return Colors.redAccent;
    if (t == 'FINANCE') return Colors.amber;
    if (t == 'LIVE') return Colors.pinkAccent;
    if (t == 'SUPPORT') return Colors.blueAccent;
    if (t == 'SYSTEM') return const Color(0xFF10B981);
    return AppColors.primary;
  }
}
