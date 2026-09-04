import 'user_model.dart';

class CpRankingModel {
  final String id;
  final UserModel user1;
  final UserModel user2;
  final int intimacyPoints;
  final String ringTier;
  final int cpLevel;
  final DateTime anniversaryDate;
  final int rank;
  final bool isPrivacyHidden;

  const CpRankingModel({
    required this.id,
    required this.user1,
    required this.user2,
    required this.intimacyPoints,
    required this.ringTier,
    required this.cpLevel,
    required this.anniversaryDate,
    required this.rank,
    this.isPrivacyHidden = false,
  });
}
