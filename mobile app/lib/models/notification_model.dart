class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String category; // Follower, Gift, Invitation, Call, Recharge, System
  final DateTime timestamp;
  final bool isRead;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    this.isRead = false,
  });
}
