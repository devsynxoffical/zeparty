import 'package:flutter/foundation.dart';

@immutable
class EmojiReactionModel {
  final String reactionId;
  final String roomId;
  final String senderId;
  final String? targetUserId;
  final String emoji;
  final DateTime timestamp;
  final int? seatId;
  final String? senderName;
  final String? senderAvatar;
  final int? gameResult;

  const EmojiReactionModel({
    required this.reactionId,
    required this.roomId,
    required this.senderId,
    this.targetUserId,
    required this.emoji,
    required this.timestamp,
    this.seatId,
    this.senderName,
    this.senderAvatar,
    this.gameResult,
  });

  Map<String, dynamic> toMap() {
    return {
      'reactionId': reactionId,
      'roomId': roomId,
      'senderId': senderId,
      'targetUserId': targetUserId,
      'emoji': emoji,
      'timestamp': timestamp.toIso8601String(),
      'seatId': seatId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'gameResult': gameResult,
    };
  }

  factory EmojiReactionModel.fromMap(Map<String, dynamic> map) {
    return EmojiReactionModel(
      reactionId: map['reactionId'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      targetUserId: map['targetUserId'] as String?,
      emoji: map['emoji'] as String? ?? '❤️',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      seatId: map['seatId'] is num ? (map['seatId'] as num).toInt() : int.tryParse(map['seatId']?.toString() ?? ''),
      senderName: map['senderName'] as String?,
      senderAvatar: map['senderAvatar'] as String?,
      gameResult: map['gameResult'] is num ? (map['gameResult'] as num).toInt() : int.tryParse(map['gameResult']?.toString() ?? ''),
    );
  }

  EmojiReactionModel copyWith({
    String? reactionId,
    String? roomId,
    String? senderId,
    String? targetUserId,
    String? emoji,
    DateTime? timestamp,
    int? seatId,
    String? senderName,
    String? senderAvatar,
    int? gameResult,
  }) {
    return EmojiReactionModel(
      reactionId: reactionId ?? this.reactionId,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      targetUserId: targetUserId ?? this.targetUserId,
      emoji: emoji ?? this.emoji,
      timestamp: timestamp ?? this.timestamp,
      seatId: seatId ?? this.seatId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      gameResult: gameResult ?? this.gameResult,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmojiReactionModel &&
        other.reactionId == reactionId &&
        other.roomId == roomId &&
        other.senderId == senderId &&
        other.targetUserId == targetUserId &&
        other.emoji == emoji &&
        other.timestamp == timestamp &&
        other.seatId == seatId &&
        other.senderName == senderName &&
        other.senderAvatar == senderAvatar &&
        other.gameResult == gameResult;
  }

  @override
  int get hashCode {
    return Object.hash(
      reactionId,
      roomId,
      senderId,
      targetUserId,
      emoji,
      timestamp,
      seatId,
      senderName,
      senderAvatar,
      gameResult,
    );
  }
}
