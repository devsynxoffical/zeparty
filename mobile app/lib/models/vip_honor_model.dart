class VIPRankUser {
  final int rank;
  final String userId;
  final String nickname;
  final String avatarUrl;
  final int svipLevel;
  final int points;
  final String countryFlag;
  final String? badgeTitle;

  const VIPRankUser({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    required this.svipLevel,
    required this.points,
    this.countryFlag = '🌐',
    this.badgeTitle,
  });
}

class VIPHonorRewardTier {
  final String rankRangeText; // e.g. 'Top 1', 'Top 2-3', 'Top 4-10'
  final String title;
  final int bonusCoins;
  final int bonusDiamonds;
  final String rewardFrame;
  final String entranceEffect;

  const VIPHonorRewardTier({
    required this.rankRangeText,
    required this.title,
    required this.bonusCoins,
    required this.bonusDiamonds,
    required this.rewardFrame,
    required this.entranceEffect,
  });
}

class HallOfFameRanking {
  final String eventId;
  final String periodTitle;
  final DateTime periodEnd;
  final List<VIPRankUser> topPodium; // Ranks 1, 2, 3
  final List<VIPRankUser> listRankings; // Ranks 4+
  final VIPRankUser currentUserRank;
  final List<VIPHonorRewardTier> rewardTiers;

  const HallOfFameRanking({
    required this.eventId,
    required this.periodTitle,
    required this.periodEnd,
    required this.topPodium,
    required this.listRankings,
    required this.currentUserRank,
    required this.rewardTiers,
  });

  Duration get remainingDuration {
    final now = DateTime.now();
    return periodEnd.isAfter(now) ? periodEnd.difference(now) : Duration.zero;
  }
}
