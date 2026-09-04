import 'package:flutter/foundation.dart';

enum GameSessionStatus {
  started,
  completed,
  cancelled,
  failed,
}

@immutable
class GameSessionModel {
  final String gameSessionId;
  final String gameId;
  final String gameType;
  final String userId;
  final int entryCoins;
  final int rewardCoins;
  final String result; // e.g. "won", "lost", "jackpot"
  final GameSessionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;

  const GameSessionModel({
    required this.gameSessionId,
    required this.gameId,
    required this.gameType,
    required this.userId,
    required this.entryCoins,
    this.rewardCoins = 0,
    required this.result,
    required this.status,
    required this.startedAt,
    this.completedAt,
  });

  factory GameSessionModel.fromJson(Map<String, dynamic> json) {
    return GameSessionModel(
      gameSessionId: json['gameSessionId'] as String? ?? '',
      gameId: json['gameId'] as String? ?? '',
      gameType: json['gameType'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      entryCoins: (json['entryCoins'] as num?)?.toInt() ?? 0,
      rewardCoins: (json['rewardCoins'] as num?)?.toInt() ?? 0,
      result: json['result'] as String? ?? 'pending',
      status: GameSessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GameSessionStatus.started,
      ),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gameSessionId': gameSessionId,
      'gameId': gameId,
      'gameType': gameType,
      'userId': userId,
      'entryCoins': entryCoins,
      'rewardCoins': rewardCoins,
      'result': result,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  GameSessionModel copyWith({
    String? gameSessionId,
    String? gameId,
    String? gameType,
    String? userId,
    int? entryCoins,
    int? rewardCoins,
    String? result,
    GameSessionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return GameSessionModel(
      gameSessionId: gameSessionId ?? this.gameSessionId,
      gameId: gameId ?? this.gameId,
      gameType: gameType ?? this.gameType,
      userId: userId ?? this.userId,
      entryCoins: entryCoins ?? this.entryCoins,
      rewardCoins: rewardCoins ?? this.rewardCoins,
      result: result ?? this.result,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
