/// Application Notification Model aligned with backend PostgreSQL Notification entity
class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message; // Aligned with backend `body`
  final String type; // SYSTEM, SOCIAL, LIVE, PK, GAMES, EVENTS, FINANCE, MODERATION, SUPPORT, MARKETING
  final String? category; // Optional sub-category (Gift, Follower, Invitation, Call, etc.)
  final Map<String, dynamic>? dataJson;
  final String deliveryStatus;
  final DateTime timestamp; // Aligned with backend `createdAt`
  final bool isRead;
  final DateTime? readAt;

  const AppNotificationModel({
    required this.id,
    this.userId = '',
    required this.title,
    required this.message,
    this.type = 'SYSTEM',
    this.category,
    this.dataJson,
    this.deliveryStatus = 'DELIVERED',
    required this.timestamp,
    this.isRead = false,
    this.readAt,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['body'] as String? ?? json['message'] as String? ?? '',
      type: (json['type'] as String? ?? 'SYSTEM').toUpperCase(),
      category: json['category'] as String?,
      dataJson: json['dataJson'] is Map<String, dynamic>
          ? json['dataJson'] as Map<String, dynamic>
          : json['data'] is Map<String, dynamic>
              ? json['data'] as Map<String, dynamic>
              : null,
      deliveryStatus: json['deliveryStatus'] as String? ?? 'DELIVERED',
      timestamp: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : json['timestamp'] != null
              ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
              : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'].toString())
          : null,
    );
  }

  AppNotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    String? category,
    Map<String, dynamic>? dataJson,
    String? deliveryStatus,
    DateTime? timestamp,
    bool? isRead,
    DateTime? readAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      category: category ?? this.category,
      dataJson: dataJson ?? this.dataJson,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': message,
      'type': type,
      'category': category,
      'dataJson': dataJson,
      'deliveryStatus': deliveryStatus,
      'createdAt': timestamp.toIso8601String(),
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
    };
  }
}
