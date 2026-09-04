class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final String type; // text, image, gift, system
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    required this.timestamp,
    this.isRead = true,
  });
}
