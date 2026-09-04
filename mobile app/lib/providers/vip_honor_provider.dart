import 'package:flutter/material.dart';
import '../models/vip_honor_model.dart';

class VIPHonorProvider extends ChangeNotifier {
  bool _isLoading = false;
  int _selectedTab = 0; // 0 = VIP Rank, 1 = Hall of Fame

  bool get isLoading => _isLoading;
  int get selectedTab => _selectedTab;

  void setSelectedTab(int tabIndex) {
    _selectedTab = tabIndex;
    notifyListeners();
  }

  // Top 3 Podium Users
  final List<VIPRankUser> _topPodium = [
    const VIPRankUser(
      rank: 1,
      userId: '777888',
      nickname: 'Sheikh Sultan',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      svipLevel: 16,
      points: 158400200,
      countryFlag: '🇦🇪',
      badgeTitle: 'Grand Emperor ✨',
    ),
    const VIPRankUser(
      rank: 2,
      userId: '992015',
      nickname: 'Lady Victoria',
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=300&q=80',
      svipLevel: 15,
      points: 112500000,
      countryFlag: '🇬🇧',
      badgeTitle: 'Royal Queen 👑',
    ),
    const VIPRankUser(
      rank: 3,
      userId: '448201',
      nickname: 'King Richard',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      svipLevel: 14,
      points: 89400000,
      countryFlag: '🇺🇸',
      badgeTitle: 'Apex Duke ⚡',
    ),
  ];

  // Ranked List 4..10
  final List<VIPRankUser> _listRankings = [
    const VIPRankUser(
      rank: 4,
      userId: '884102',
      nickname: 'Alpha Knight',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
      svipLevel: 13,
      points: 45200000,
      countryFlag: '🇸🇦',
    ),
    const VIPRankUser(
      rank: 5,
      userId: '661890',
      nickname: 'Princess Aurora',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
      svipLevel: 12,
      points: 28400000,
      countryFlag: '🇨🇦',
    ),
    const VIPRankUser(
      rank: 6,
      userId: '339102',
      nickname: 'Dragon Lord',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=300&q=80',
      svipLevel: 11,
      points: 18900000,
      countryFlag: '🇶🇦',
    ),
    const VIPRankUser(
      rank: 7,
      userId: '558291',
      nickname: 'Zeus Thunder',
      avatarUrl: 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=300&q=80',
      svipLevel: 10,
      points: 9200000,
      countryFlag: '🇩🇪',
    ),
  ];

  // Current User's Ranking
  final VIPRankUser _currentUserRank = const VIPRankUser(
    rank: 18,
    userId: '88091',
    nickname: 'ZeParty Official',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
    svipLevel: 11,
    points: 14500000,
    countryFlag: '🌐',
    badgeTitle: 'Top VIP Contributor',
  );

  // VIP Honor Reward Tiers
  final List<VIPHonorRewardTier> _rewardTiers = [
    const VIPHonorRewardTier(
      rankRangeText: 'Top 1 Champion',
      title: 'Supreme Hall of Fame Grand Trophy',
      bonusCoins: 1000000,
      bonusDiamonds: 500000,
      rewardFrame: 'Permanent Grand Champion Diamond Frame',
      entranceEffect: 'Global Golden Dragon Entrance',
    ),
    const VIPHonorRewardTier(
      rankRangeText: 'Top 2 - 3 Podium',
      title: 'Royal Platinum Honor',
      bonusCoins: 500000,
      bonusDiamonds: 250000,
      rewardFrame: '30-Day Royal Platinum Wings Frame',
      entranceEffect: 'Phoenix Wave Entrance Splash',
    ),
    const VIPHonorRewardTier(
      rankRangeText: 'Top 4 - 10 Elite',
      title: 'Gold Star Honor',
      bonusCoins: 200000,
      bonusDiamonds: 100000,
      rewardFrame: '15-Day Golden Star Halo Frame',
      entranceEffect: 'Gold Spotlight Effect',
    ),
  ];

  late HallOfFameRanking _hallOfFame;

  VIPHonorProvider() {
    _hallOfFame = HallOfFameRanking(
      eventId: 'hof_august_2026',
      periodTitle: 'August 2026 Season 8 Championship',
      periodEnd: DateTime(2026, 8, 31, 23, 59, 59),
      topPodium: _topPodium,
      listRankings: _listRankings,
      currentUserRank: _currentUserRank,
      rewardTiers: _rewardTiers,
    );
  }

  HallOfFameRanking get hallOfFame => _hallOfFame;

  Future<void> fetchHonorData() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));
    _isLoading = false;
    notifyListeners();
  }
}
