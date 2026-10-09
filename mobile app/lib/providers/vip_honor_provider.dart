import 'package:flutter/material.dart';
import '../core/services/api_client.dart';
import '../models/vip_honor_model.dart';
import 'auth_provider.dart';
import 'svip_provider.dart';

class VIPHonorProvider extends ChangeNotifier {
  bool _isLoading = false;
  int _selectedTab = 0; // 0 = VIP Rank, 1 = Hall of Fame

  bool get isLoading => _isLoading;
  int get selectedTab => _selectedTab;

  List<VIPRankUser> _topPodium = [];
  List<VIPRankUser> _listRankings = [];
  VIPRankUser _currentUserRank = const VIPRankUser(
    rank: 1,
    userId: '',
    nickname: 'You',
    avatarUrl: '',
    svipLevel: 0,
    points: 0,
    countryFlag: '🌐',
  );

  // VIP Honor Reward Tiers
  final List<VIPHonorRewardTier> _rewardTiers = const [
    VIPHonorRewardTier(
      rankRangeText: 'Top 1 Champion',
      title: 'Supreme Hall of Fame Grand Trophy',
      bonusCoins: 1000000,
      bonusDiamonds: 500000,
      rewardFrame: 'Permanent Grand Champion Diamond Frame',
      entranceEffect: 'Global Golden Dragon Entrance',
    ),
    VIPHonorRewardTier(
      rankRangeText: 'Top 2 - 3 Podium',
      title: 'Royal Platinum Honor',
      bonusCoins: 500000,
      bonusDiamonds: 250000,
      rewardFrame: '30-Day Royal Platinum Wings Frame',
      entranceEffect: 'Phoenix Wave Entrance Splash',
    ),
    VIPHonorRewardTier(
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
    _initHallOfFame();
  }

  void _initHallOfFame() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final periodEnd = nextMonth.subtract(const Duration(seconds: 1));
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final periodTitle = '${months[now.month - 1]} ${now.year} Season Championship';

    _hallOfFame = HallOfFameRanking(
      eventId: 'hof_${now.year}_${now.month}',
      periodTitle: periodTitle,
      periodEnd: periodEnd,
      topPodium: _topPodium,
      listRankings: _listRankings,
      currentUserRank: _currentUserRank,
      rewardTiers: _rewardTiers,
    );
  }

  HallOfFameRanking get hallOfFame => _hallOfFame;

  void setSelectedTab(int tabIndex) {
    _selectedTab = tabIndex;
    notifyListeners();
  }

  Future<void> fetchHonorData([AuthProvider? auth, SVIPProvider? svip]) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiClient.instance.get<Map<String, dynamic>>(
        '/v1/rankings',
        queryParameters: {
          'category': 'wealth',
          'period': 'monthly',
          'limit': 50,
        },
      );

      final rawData = res.data?['data'];
      final List<VIPRankUser> loadedUsers = [];

      if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          final item = rawData[i];
          if (item is Map<String, dynamic>) {
            final rank = (item['rank'] as num?)?.toInt() ?? (i + 1);
            final userObj = item['user'] is Map<String, dynamic> ? item['user'] : item;
            final userId = userObj['_id']?.toString() ?? userObj['id']?.toString() ?? 'user_$i';
            final nickname = userObj['name']?.toString() ?? userObj['nickname']?.toString() ?? 'VIP User';
            final avatarUrl = userObj['avatar']?.toString() ?? userObj['avatarUrl']?.toString() ?? '';
            final svipLvl = (userObj['svipLevel'] as num?)?.toInt() ?? (userObj['level'] as num?)?.toInt() ?? 0;
            final points = (item['score'] as num?)?.toInt() ?? (item['points'] as num?)?.toInt() ?? (item['coins'] as num?)?.toInt() ?? 0;
            final countryFlag = userObj['countryFlag']?.toString() ?? '🌐';

            loadedUsers.add(VIPRankUser(
              rank: rank,
              userId: userId,
              nickname: nickname,
              avatarUrl: avatarUrl,
              svipLevel: svipLvl,
              points: points,
              countryFlag: countryFlag,
              badgeTitle: rank == 1 ? 'Grand Emperor ✨' : (rank == 2 ? 'Royal Queen 👑' : (rank == 3 ? 'Apex Duke ⚡' : null)),
            ));
          }
        }
      }

      _topPodium = loadedUsers.take(3).toList();
      _listRankings = loadedUsers.length > 3 ? loadedUsers.sublist(3) : [];

      if (auth != null && auth.hasUser) {
        final user = auth.currentUser;
        final myIndex = loadedUsers.indexWhere((u) => u.userId == user.id);
        final currentPoints = svip?.currentPoints ?? user.coins;
        final currentLevel = svip?.currentLevel ?? (int.tryParse(user.vipLevel) ?? 0);

        _currentUserRank = VIPRankUser(
          rank: myIndex >= 0 ? myIndex + 1 : (loadedUsers.isNotEmpty ? loadedUsers.length + 1 : 1),
          userId: user.id,
          nickname: user.name,
          avatarUrl: user.avatarUrl,
          svipLevel: currentLevel,
          points: currentPoints,
          countryFlag: '🌐',
        );
      }

      _initHallOfFame();
    } catch (e) {
      debugPrint('[VIPHonorProvider] Real ranking fetch error: $e');
      _topPodium = [];
      _listRankings = [];
      if (auth != null && auth.hasUser) {
        final user = auth.currentUser;
        _currentUserRank = VIPRankUser(
          rank: 1,
          userId: user.id,
          nickname: user.name,
          avatarUrl: user.avatarUrl,
          svipLevel: svip?.currentLevel ?? (int.tryParse(user.vipLevel) ?? 0),
          points: svip?.currentPoints ?? 0,
          countryFlag: '🌐',
        );
      }
      _initHallOfFame();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
