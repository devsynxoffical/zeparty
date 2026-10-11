import 'package:flutter/material.dart';

import '../models/cp_ranking_model.dart';

class CpRankingProvider extends ChangeNotifier {
  final List<CpRankingModel> _allRankings = [];

  List<CpRankingModel> get allRankings => List.unmodifiable(_allRankings);

  CpRankingProvider();

  List<CpRankingModel> getFilteredRankings({
    required String timeframe,
    required bool hideCpPrivacyActive,
  }) {
    return _allRankings.where((cp) {
      if (cp.isPrivacyHidden) return false;
      if (hideCpPrivacyActive) return false;
      return true;
    }).toList();
  }

  void boostIntimacy(String cpId, int points) {
    final idx = _allRankings.indexWhere((c) => c.id == cpId);
    if (idx != -1) {
      final old = _allRankings[idx];
      _allRankings[idx] = CpRankingModel(
        id: old.id,
        user1: old.user1,
        user2: old.user2,
        intimacyPoints: old.intimacyPoints + points,
        ringTier: old.ringTier,
        cpLevel: old.cpLevel,
        anniversaryDate: old.anniversaryDate,
        rank: old.rank,
        isPrivacyHidden: old.isPrivacyHidden,
      );
      notifyListeners();
    }
  }
}
