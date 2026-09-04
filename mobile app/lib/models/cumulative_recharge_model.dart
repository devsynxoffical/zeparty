enum MilestoneClaimStatus { locked, eligible, claimed, expired }

class RechargeMilestone {
  final int level;
  final double thresholdUsd;
  final int bonusCoins;
  final int bonusDiamonds;
  final String specialRewardName;
  final String specialRewardIcon;
  final MilestoneClaimStatus status;

  const RechargeMilestone({
    required this.level,
    required this.thresholdUsd,
    required this.bonusCoins,
    required this.bonusDiamonds,
    required this.specialRewardName,
    required this.specialRewardIcon,
    this.status = MilestoneClaimStatus.locked,
  });

  RechargeMilestone copyWith({
    int? level,
    double? thresholdUsd,
    int? bonusCoins,
    int? bonusDiamonds,
    String? specialRewardName,
    String? specialRewardIcon,
    MilestoneClaimStatus? status,
  }) {
    return RechargeMilestone(
      level: level ?? this.level,
      thresholdUsd: thresholdUsd ?? this.thresholdUsd,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      bonusDiamonds: bonusDiamonds ?? this.bonusDiamonds,
      specialRewardName: specialRewardName ?? this.specialRewardName,
      specialRewardIcon: specialRewardIcon ?? this.specialRewardIcon,
      status: status ?? this.status,
    );
  }
}

class CumulativeRechargeEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double currentRechargeUsd;
  final List<RechargeMilestone> milestones;

  const CumulativeRechargeEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.currentRechargeUsd,
    required this.milestones,
  });

  double get maxThreshold => milestones.isNotEmpty ? milestones.last.thresholdUsd : 3000.0;
  double get overallProgress => maxThreshold > 0 ? (currentRechargeUsd / maxThreshold).clamp(0.0, 1.0) : 0.0;

  Duration get remainingTime {
    final now = DateTime.now();
    return endDate.isAfter(now) ? endDate.difference(now) : Duration.zero;
  }
}
