class LiveHostPolicyLevel {
  final int level;
  final int diamondTarget;
  final int validDaysRequired;
  final double basicSalaryUsd;

  const LiveHostPolicyLevel({
    required this.level,
    required this.diamondTarget,
    required this.validDaysRequired,
    required this.basicSalaryUsd,
  });
}

class LiveHostPolicy {
  static const String policyId = 'policy_live_host_v1';
  static const String version = '1.0.0';
  static final DateTime effectiveDate = DateTime(2026, 1, 1);
  static const int requiredLiveHostDailyMinutes = 60; // 1 verified live streaming hour

  static const List<LiveHostPolicyLevel> policyTable = [
    LiveHostPolicyLevel(level: 1, diamondTarget: 25000, validDaysRequired: 10, basicSalaryUsd: 2.0),
    LiveHostPolicyLevel(level: 2, diamondTarget: 50000, validDaysRequired: 10, basicSalaryUsd: 4.0),
    LiveHostPolicyLevel(level: 3, diamondTarget: 100000, validDaysRequired: 10, basicSalaryUsd: 8.0),
    LiveHostPolicyLevel(level: 4, diamondTarget: 250000, validDaysRequired: 10, basicSalaryUsd: 20.0),
    LiveHostPolicyLevel(level: 5, diamondTarget: 500000, validDaysRequired: 8, basicSalaryUsd: 40.0),
    LiveHostPolicyLevel(level: 6, diamondTarget: 750000, validDaysRequired: 8, basicSalaryUsd: 60.0),
    LiveHostPolicyLevel(level: 7, diamondTarget: 1000000, validDaysRequired: 8, basicSalaryUsd: 80.0),
    LiveHostPolicyLevel(level: 8, diamondTarget: 1500000, validDaysRequired: 8, basicSalaryUsd: 120.0),
    LiveHostPolicyLevel(level: 9, diamondTarget: 2000000, validDaysRequired: 8, basicSalaryUsd: 160.0),
    LiveHostPolicyLevel(level: 10, diamondTarget: 2500000, validDaysRequired: 8, basicSalaryUsd: 200.0),
    LiveHostPolicyLevel(level: 11, diamondTarget: 3000000, validDaysRequired: 5, basicSalaryUsd: 240.0),
    LiveHostPolicyLevel(level: 12, diamondTarget: 3500000, validDaysRequired: 5, basicSalaryUsd: 280.0),
    LiveHostPolicyLevel(level: 13, diamondTarget: 4000000, validDaysRequired: 5, basicSalaryUsd: 320.0),
    LiveHostPolicyLevel(level: 14, diamondTarget: 4500000, validDaysRequired: 5, basicSalaryUsd: 360.0),
    LiveHostPolicyLevel(level: 15, diamondTarget: 5000000, validDaysRequired: 5, basicSalaryUsd: 400.0),
    LiveHostPolicyLevel(level: 16, diamondTarget: 6000000, validDaysRequired: 5, basicSalaryUsd: 480.0),
    LiveHostPolicyLevel(level: 17, diamondTarget: 7000000, validDaysRequired: 5, basicSalaryUsd: 560.0),
    LiveHostPolicyLevel(level: 18, diamondTarget: 8000000, validDaysRequired: 5, basicSalaryUsd: 640.0),
    LiveHostPolicyLevel(level: 19, diamondTarget: 9000000, validDaysRequired: 5, basicSalaryUsd: 720.0),
    LiveHostPolicyLevel(level: 20, diamondTarget: 10000000, validDaysRequired: 5, basicSalaryUsd: 800.0),
    LiveHostPolicyLevel(level: 21, diamondTarget: 15000000, validDaysRequired: 5, basicSalaryUsd: 1200.0),
    LiveHostPolicyLevel(level: 22, diamondTarget: 20000000, validDaysRequired: 5, basicSalaryUsd: 1600.0),
    LiveHostPolicyLevel(level: 23, diamondTarget: 30000000, validDaysRequired: 5, basicSalaryUsd: 2400.0),
    LiveHostPolicyLevel(level: 24, diamondTarget: 40000000, validDaysRequired: 5, basicSalaryUsd: 3200.0),
    LiveHostPolicyLevel(level: 25, diamondTarget: 50000000, validDaysRequired: 5, basicSalaryUsd: 4000.0),
  ];

  static LiveHostPolicyLevel getLevelForDiamonds(int diamonds) {
    LiveHostPolicyLevel achieved = policyTable.first;
    for (final lvl in policyTable) {
      if (diamonds >= lvl.diamondTarget) {
        achieved = lvl;
      } else {
        break;
      }
    }
    return achieved;
  }

  static LiveHostPolicyLevel? getNextLevel(int currentLevel) {
    if (currentLevel >= 25) return null;
    return policyTable.firstWhere((lvl) => lvl.level == currentLevel + 1, orElse: () => policyTable.last);
  }

  static bool isTargetEligible({
    required int achievedDiamonds,
    required int completedValidDays,
    required int targetLevel,
  }) {
    final lvl = policyTable.firstWhere((l) => l.level == targetLevel, orElse: () => policyTable.first);
    return achievedDiamonds >= lvl.diamondTarget && completedValidDays >= lvl.validDaysRequired;
  }
}
