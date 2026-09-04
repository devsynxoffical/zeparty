import 'user_model.dart';

class PKBattleModel {
  final String id;
  final UserModel hostA;
  final UserModel hostB;
  final int scoreA;
  final int scoreB;
  final Duration remainingTime;
  final bool isEnded;
  final String? winnerId;

  const PKBattleModel({
    required this.id,
    required this.hostA,
    required this.hostB,
    required this.scoreA,
    required this.scoreB,
    required this.remainingTime,
    this.isEnded = false,
    this.winnerId,
  });

  PKBattleModel copyWith({
    String? id,
    UserModel? hostA,
    UserModel? hostB,
    int? scoreA,
    int? scoreB,
    Duration? remainingTime,
    bool? isEnded,
    String? winnerId,
  }) {
    return PKBattleModel(
      id: id ?? this.id,
      hostA: hostA ?? this.hostA,
      hostB: hostB ?? this.hostB,
      scoreA: scoreA ?? this.scoreA,
      scoreB: scoreB ?? this.scoreB,
      remainingTime: remainingTime ?? this.remainingTime,
      isEnded: isEnded ?? this.isEnded,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
