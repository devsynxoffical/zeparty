class MicReactionModel {
  final String id;
  final String senderUserId;
  final String roomId;
  final int micIndex;
  final String reactionAsset;
  final String category;
  final DateTime timestamp;

  const MicReactionModel({
    required this.id,
    required this.senderUserId,
    required this.roomId,
    required this.micIndex,
    required this.reactionAsset,
    required this.category,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderUserId': senderUserId,
        'roomId': roomId,
        'micIndex': micIndex,
        'reactionAsset': reactionAsset,
        'category': category,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MicReactionModel.fromJson(Map<String, dynamic> json) => MicReactionModel(
        id: json['id'] ?? '',
        senderUserId: json['senderUserId'] ?? '',
        roomId: json['roomId'] ?? '',
        micIndex: json['micIndex'] ?? 0,
        reactionAsset: json['reactionAsset'] ?? '',
        category: json['category'] ?? 'Popular',
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      );
}
