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
    required this.timestamp,
    this.isRead = false,
    this.isDelivered = false,
    MessageStatus? status,
  }) : status = status ??
            (isRead
                ? MessageStatus.read
                : (isDelivered ? MessageStatus.delivered : MessageStatus.sent));

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? text,
    String? type,
    String? mediaUrl,
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
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDelivered: isDelivered ?? this.isDelivered,
      status: status ?? this.status,
    );
  }
}
