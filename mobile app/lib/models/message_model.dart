enum MessageStatus {
  sent,      // Single tick (grey) - Recipient Offline / Message Sent
  delivered, // Double tick (grey) - Recipient Online / Delivered
  read,      // Double tick (colorful) - Read by recipient
}

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type; // text, image, gift, system, voice
  final String? mediaUrl;
  final int? durationSeconds;
  final DateTime? mediaExpiresAt;
  final bool isMediaDeleted;
  final bool isMediaExpired;
  final DateTime timestamp;
  final bool isRead;
  final bool isDelivered;
  final MessageStatus status;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    this.durationSeconds,
    this.mediaExpiresAt,
    this.isMediaDeleted = false,
    this.isMediaExpired = false,
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    MessageStatus? status,
  }) : status = status ??
            (isRead
                ? MessageStatus.read
                : (isDelivered ? MessageStatus.delivered : MessageStatus.sent));

  /// Checks if media attachment was permanently purged after 1 month to conserve storage
  bool get isExpired {
    if (isMediaDeleted || isMediaExpired) return true;
    if (mediaExpiresAt != null && DateTime.now().isAfter(mediaExpiresAt!)) return true;
    if (type == 'voice' && (mediaUrl == null || mediaUrl!.isEmpty) && !text.contains('http')) {
      return true;
    }
    return false;
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final senderId = json['senderId']?.toString() ?? '';
    final receiverId = json['recipientId']?.toString() ?? json['receiverId']?.toString() ?? '';
    final text = json['content']?.toString() ?? json['text']?.toString() ?? '';
    final rawType = json['type']?.toString().toLowerCase() ?? 'text';
    final mediaUrl = json['mediaUrl']?.toString();
    final durationSeconds = int.tryParse(json['durationSeconds']?.toString() ?? '');

    DateTime? mediaExpiresAt;
    if (json['mediaExpiresAt'] != null) {
      mediaExpiresAt = DateTime.tryParse(json['mediaExpiresAt'].toString());
    }

    final isMediaDeleted = json['isMediaDeleted'] == true;
    final isMediaExpired = json['isMediaExpired'] == true || (mediaExpiresAt != null && DateTime.now().isAfter(mediaExpiresAt));

    DateTime timestamp = DateTime.now();
    if (json['createdAt'] != null) {
      timestamp = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      timestamp = DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now();
    }

    final isRead = json['isRead'] == true;
    final isDelivered = json['isDelivered'] == true || isRead;

    return MessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      type: rawType,
      mediaUrl: isMediaExpired ? null : mediaUrl,
      durationSeconds: durationSeconds,
      mediaExpiresAt: mediaExpiresAt,
      isMediaDeleted: isMediaDeleted,
      isMediaExpired: isMediaExpired,
      timestamp: timestamp,
      isRead: isRead,
      isDelivered: isDelivered,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': receiverId,
      'content': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'durationSeconds': durationSeconds,
      'mediaExpiresAt': mediaExpiresAt?.toIso8601String(),
      'isMediaDeleted': isMediaDeleted,
      'isMediaExpired': isMediaExpired,
      'createdAt': timestamp.toIso8601String(),
      'isRead': isRead,
      'isDelivered': isDelivered,
    };
  }

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    String? type,
    String? mediaUrl,
    int? durationSeconds,
    DateTime? mediaExpiresAt,
    bool? isMediaDeleted,
    bool? isMediaExpired,
    DateTime? timestamp,
    bool? isRead,
    bool? isDelivered,
    MessageStatus? status,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      text: text ?? this.text,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      mediaExpiresAt: mediaExpiresAt ?? this.mediaExpiresAt,
      isMediaDeleted: isMediaDeleted ?? this.isMediaDeleted,
      isMediaExpired: isMediaExpired ?? this.isMediaExpired,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      status: status ?? this.status,
    );
  }
}
