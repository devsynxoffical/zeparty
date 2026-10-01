import 'user_model.dart';

class PKBattleModel {
  final String id;
  final String roomAId;
  final String roomBId;
  final UserModel hostA;
  final UserModel hostB;
  final int scoreA;
  final int scoreB;
  final int durationSeconds;
  final Duration remainingTime;
  final String status; // 'COUNTDOWN', 'ACTIVE', 'ENDED'
  final bool isEnded;
  final String? winnerId;

  const PKBattleModel({
    required this.id,
    this.roomAId = '',
    this.roomBId = '',
    required this.hostA,
    required this.hostB,
    required this.scoreA,
    required this.scoreB,
    this.durationSeconds = 300,
    required this.remainingTime,
    this.status = 'ACTIVE',
    this.isEnded = false,
    this.winnerId,
  });

  factory PKBattleModel.fromJson(Map<String, dynamic> json) {
    final rawHostA = json['hostA'] ?? json['roomA']?['creator'] ?? {};
    final rawHostB = json['hostB'] ?? json['roomB']?['creator'] ?? {};

    final scoreANum = json['hostAScore'] != null ? int.tryParse(json['hostAScore'].toString()) ?? 0 : (json['scoreA'] ?? 0);
    final scoreBNum = json['hostBScore'] != null ? int.tryParse(json['hostBScore'].toString()) ?? 0 : (json['scoreB'] ?? 0);
    final duration = json['durationSeconds'] is int ? json['durationSeconds'] as int : 300;
    final statusStr = json['status']?.toString() ?? 'ACTIVE';

    return PKBattleModel(
      id: json['pkId']?.toString() ?? json['id']?.toString() ?? '',
      roomAId: json['roomAId']?.toString() ?? '',
      roomBId: json['roomBId']?.toString() ?? '',
      hostA: rawHostA is Map<String, dynamic> ? UserModel.fromJson(rawHostA) : const UserModel(id: '', username: 'host_blue', name: 'Host Blue', avatarUrl: ''),
      hostB: rawHostB is Map<String, dynamic> ? UserModel.fromJson(rawHostB) : const UserModel(id: '', username: 'host_red', name: 'Host Red', avatarUrl: ''),
      scoreA: scoreANum is int ? scoreANum : 0,
      scoreB: scoreBNum is int ? scoreBNum : 0,
      durationSeconds: duration,
      remainingTime: Duration(seconds: duration),
      status: statusStr,
      isEnded: statusStr == 'ENDED',
      winnerId: json['winnerHostUserId']?.toString(),
    );
  }

  PKBattleModel copyWith({
    String? id,
    String? roomAId,
    String? roomBId,
    UserModel? hostA,
    UserModel? hostB,
    int? scoreA,
    int? scoreB,
    int? durationSeconds,
    Duration? remainingTime,
    String? status,
    bool? isEnded,
    String? winnerId,
  }) {
    return PKBattleModel(
      id: id ?? this.id,
      roomAId: roomAId ?? this.roomAId,
      roomBId: roomBId ?? this.roomBId,
      hostA: hostA ?? this.hostA,
      hostB: hostB ?? this.hostB,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remainingTime: remainingTime ?? this.remainingTime,
      status: status ?? this.status,
      isEnded: isEnded ?? this.isEnded,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
