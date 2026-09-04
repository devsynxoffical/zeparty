import 'package:flutter/foundation.dart';
import 'gift_model.dart';

@immutable
class LiveGiftEventModel {
  final String eventId;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final GiftAnimationLevel animationLevel;
  final int giftValue;
  final int quantity;
  final int comboCount;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String receiverId;
  final String receiverName;
  final String receiverAvatarUrl;
  final String roomId;
  final DateTime timestamp;

  const LiveGiftEventModel({
    required this.eventId,
    required this.giftId,
    required this.giftName,
    required this.giftIcon,
    required this.animationLevel,
    required this.giftValue,
    this.quantity = 1,
    this.comboCount = 1,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatarUrl,
    required this.roomId,
    required this.timestamp,
  });

  int get totalValue => giftValue * quantity * comboCount;

  LiveGiftEventModel copyWith({
    String? eventId,
    String? giftId,
    String? giftName,
    String? giftIcon,
    GiftAnimationLevel? animationLevel,
    int? giftValue,
    int? quantity,
    int? comboCount,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? receiverId,
    String? receiverName,
    String? receiverAvatarUrl,
    String? roomId,
    DateTime? timestamp,
  }) {
    return LiveGiftEventModel(
      eventId: eventId ?? this.eventId,
      giftId: giftId ?? this.giftId,
      giftName: giftName ?? this.giftName,
      giftIcon: giftIcon ?? this.giftIcon,
      animationLevel: animationLevel ?? this.animationLevel,
      giftValue: giftValue ?? this.giftValue,
      quantity: quantity ?? this.quantity,
      comboCount: comboCount ?? this.comboCount,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatarUrl: receiverAvatarUrl ?? this.receiverAvatarUrl,
      roomId: roomId ?? this.roomId,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'giftId': giftId,
      'giftName': giftName,
      'giftIcon': giftIcon,
      'animationLevel': animationLevel.name,
      'giftValue': giftValue,
      'quantity': quantity,
      'comboCount': comboCount,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatarUrl': receiverAvatarUrl,
      'roomId': roomId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory LiveGiftEventModel.fromMap(Map<String, dynamic> map) {
    return LiveGiftEventModel(
      eventId: map['eventId'] as String? ?? '',
      giftId: map['giftId'] as String? ?? '',
      giftName: map['giftName'] as String? ?? 'Gift',
      giftIcon: map['giftIcon'] as String? ?? '🎁',
      animationLevel: GiftAnimationLevel.values.firstWhere(
        (e) => e.name == (map['animationLevel'] as String? ?? 'basic'),
        orElse: () => GiftAnimationLevel.basic,
      ),
      giftValue: map['giftValue'] as int? ?? 10,
      quantity: map['quantity'] as int? ?? 1,
      comboCount: map['comboCount'] as int? ?? 1,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'User',
      senderAvatarUrl: map['senderAvatarUrl'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? 'Host',
      receiverAvatarUrl: map['receiverAvatarUrl'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
