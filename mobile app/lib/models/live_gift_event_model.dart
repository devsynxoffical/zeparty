import 'package:flutter/foundation.dart';
import 'gift_model.dart';

@immutable
class LiveGiftEventModel {
  final String eventId;
  final String giftId;
  final String giftName;
  final String giftIcon;
  final String? iconUrl;
  final String? animationUrl;
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
    this.iconUrl,
    this.animationUrl,
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
    String? iconUrl,
    String? animationUrl,
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
      iconUrl: iconUrl ?? this.iconUrl,
      animationUrl: animationUrl ?? this.animationUrl,
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
      'iconUrl': iconUrl,
      'animationUrl': animationUrl,
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
      eventId: map['eventId'] as String? ?? map['transactionId'] as String? ?? '',
      giftId: map['giftId'] as String? ?? '',
      giftName: map['giftName'] as String? ?? 'Gift',
      giftIcon: map['giftIcon'] as String? ?? '🎁',
      iconUrl: map['iconUrl'] as String?,
      animationUrl: map['animationUrl'] as String?,
      animationLevel: GiftAnimationLevel.values.firstWhere(
        (e) => e.name == (map['animationLevel'] as String? ?? 'basic'),
        orElse: () => GiftAnimationLevel.basic,
      ),
      giftValue: (map['giftValue'] as num?)?.toInt() ?? 10,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      comboCount: (map['comboCount'] as num?)?.toInt() ?? 1,
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

  /// Factory specifically parsing backend Socket.IO `room:gift_sent` event payload
  factory LiveGiftEventModel.fromSocketJson(Map<String, dynamic> json) {
    final giftRaw = json['gift'];
    final giftObj = giftRaw is Map ? Map<String, dynamic>.from(giftRaw) : <String, dynamic>{};
    final isFull = giftObj['isFullScreen'] == true;
    final animUrl = giftObj['animationUrl']?.toString();
    final iconUrl = giftObj['iconUrl']?.toString();

    final totalCoins = int.tryParse(json['totalCoins']?.toString() ?? json['coins']?.toString() ?? '0') ?? 0;
    final qty = (json['quantity'] is num ? (json['quantity'] as num).toInt() : int.tryParse(json['quantity']?.toString() ?? '1')) ?? 1;
    final unitCoins = qty > 0 ? (totalCoins ~/ qty) : (totalCoins > 0 ? totalCoins : 10);

    GiftAnimationLevel animLevel = GiftAnimationLevel.basic;
    if (isFull || unitCoins >= 10000) {
      animLevel = GiftAnimationLevel.legendary;
    } else if (unitCoins >= 1000) {
      animLevel = GiftAnimationLevel.premium;
    } else if (unitCoins >= 100 || animUrl != null) {
      animLevel = GiftAnimationLevel.standard;
    }

    return LiveGiftEventModel(
      eventId: json['transactionId']?.toString() ?? json['id']?.toString() ?? 'tx_${DateTime.now().millisecondsSinceEpoch}',
      giftId: giftObj['id']?.toString() ?? json['giftId']?.toString() ?? '',
      giftName: giftObj['name']?.toString() ?? json['giftName']?.toString() ?? 'Gift',
      giftIcon: isFull ? '🏰' : (giftObj['icon']?.toString() ?? '🎁'),
      iconUrl: iconUrl,
      animationUrl: animUrl,
      animationLevel: animLevel,
      giftValue: unitCoins > 0 ? unitCoins : 10,
      quantity: qty,
      comboCount: qty,
      senderId: json['senderUserId']?.toString() ?? (json['sender'] is Map ? (json['sender'] as Map)['id']?.toString() : null) ?? '',
      senderName: json['senderName']?.toString() ?? (json['sender'] is Map ? (json['sender'] as Map)['name']?.toString() : null) ?? 'User',
      senderAvatarUrl: json['senderAvatarUrl']?.toString() ?? (json['sender'] is Map ? (json['sender'] as Map)['avatarUrl']?.toString() : null) ?? '',
      receiverId: json['recipientUserId']?.toString() ?? json['receiverUserId']?.toString() ?? (json['recipient'] is Map ? (json['recipient'] as Map)['id']?.toString() : null) ?? '',
      receiverName: json['recipientName']?.toString() ?? json['receiverName']?.toString() ?? (json['recipient'] is Map ? (json['recipient'] as Map)['name']?.toString() : null) ?? 'Host',
      receiverAvatarUrl: json['recipientAvatarUrl']?.toString() ?? json['receiverAvatarUrl']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }
}
