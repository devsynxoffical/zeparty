import 'package:flutter/material.dart';

import '../core/repositories/backend_repository.dart';
import '../models/cp_ranking_model.dart';
import '../models/user_model.dart';

class CpRankingProvider extends ChangeNotifier {
  final List<CpRankingModel> _allRankings = [];

  List<CpRankingModel> get allRankings => List.unmodifiable(_allRankings);

  CpRankingProvider() {
    _initMockRankings();
  }

  void _initMockRankings() {
    final rawUsers = BackendRepository.instance.popularUsers;
    final List<UserModel> users = List.from(rawUsers);
    if (users.length < 6) {
      users.addAll(const [
        UserModel(id: 'cp_u1', name: 'Aria Star', username: 'aria', avatarUrl: 'https://example.com/a1.jpg'),
        UserModel(id: 'cp_u2', name: 'Leo King', username: 'leo', avatarUrl: 'https://example.com/a2.jpg'),
        UserModel(id: 'cp_u3', name: 'Luna Moon', username: 'luna', avatarUrl: 'https://example.com/a3.jpg'),
        UserModel(id: 'cp_u4', name: 'Zack Blaze', username: 'zack', avatarUrl: 'https://example.com/a4.jpg'),
        UserModel(id: 'cp_u5', name: 'Maya Queen', username: 'maya', avatarUrl: 'https://example.com/a5.jpg'),
        UserModel(id: 'cp_u6', name: 'Kai Sun', username: 'kai', avatarUrl: 'https://example.com/a6.jpg'),
      ]);
    }

    _allRankings.addAll([
      CpRankingModel(
        id: 'cp_rank_1',
        user1: users[0], // Crown CP
        user2: users[1],
        intimacyPoints: 1250400,
        ringTier: 'Diamond Eternal Ring',
        cpLevel: 25,
        anniversaryDate: DateTime.now().subtract(const Duration(days: 340)),
        rank: 1,
      ),
      CpRankingModel(
        id: 'cp_rank_2',
        user1: users[2],
        user2: users[3],
        intimacyPoints: 890200,
        ringTier: 'Crown Gold Ring',
        cpLevel: 20,
        anniversaryDate: DateTime.now().subtract(const Duration(days: 215)),
        rank: 2,
      ),
      CpRankingModel(
        id: 'cp_rank_3',
        user1: users[4],
        user2: users[5],
        intimacyPoints: 640150,
        ringTier: 'Ruby Soul Ring',
        cpLevel: 16,
        anniversaryDate: DateTime.now().subtract(const Duration(days: 140)),
        rank: 3,
      ),
      CpRankingModel(
        id: 'cp_rank_4',
        user1: users.length > 6 ? users[6] : users[0],
        user2: users.length > 7 ? users[7] : users[2],
        intimacyPoints: 420800,
        ringTier: 'Sapphire Oath Ring',
        cpLevel: 12,
        anniversaryDate: DateTime.now().subtract(const Duration(days: 90)),
        rank: 4,
      ),
      CpRankingModel(
        id: 'cp_rank_5',
        user1: UserModel(
          id: 'hidden_user_1',
          name: 'Anonymous Partner',
          username: 'hidden1',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        ),
        user2: UserModel(
          id: 'hidden_user_2',
          name: 'Private Lover',
          username: 'hidden2',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        ),
        intimacyPoints: 350000,
        ringTier: 'Emerald Ring',
        cpLevel: 10,
        anniversaryDate: DateTime.now().subtract(const Duration(days: 60)),
        rank: 5,
        isPrivacyHidden: true, // Privacy Hidden entry test
      ),
    ]);
  }

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
