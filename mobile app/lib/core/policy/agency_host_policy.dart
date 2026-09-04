class AgencyHostPolicyLevel {
  final int level;
  final int diamondTarget;
  final int validDaysRequired;
  final double basicTotalSalaryUsd;
  final double hostBasicSalaryUsd;
  final double agencySalaryUsd;
  final String specialIdBonus;

  const AgencyHostPolicyLevel({
    required this.level,
    required this.diamondTarget,
    required this.validDaysRequired,
    required this.basicTotalSalaryUsd,
    required this.hostBasicSalaryUsd,
    required this.agencySalaryUsd,
    required this.specialIdBonus,
  });
}

class AgencyHostPolicy {
  static const String policyId = 'policy_agency_host_v1';
  static const String version = '1.0.0';
  static final DateTime effectiveDate = DateTime(2026, 1, 1);
  static const int requiredAudioHostDailyMinutes = 120; // 2 hours online & unmuted

  static const List<AgencyHostPolicyLevel> policyTable = [
    AgencyHostPolicyLevel(level: 1, diamondTarget: 25000, validDaysRequired: 10, basicTotalSalaryUsd: 2.0, hostBasicSalaryUsd: 1.60, agencySalaryUsd: 0.40, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 2, diamondTarget: 50000, validDaysRequired: 10, basicTotalSalaryUsd: 4.0, hostBasicSalaryUsd: 3.20, agencySalaryUsd: 0.80, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 3, diamondTarget: 100000, validDaysRequired: 10, basicTotalSalaryUsd: 8.0, hostBasicSalaryUsd: 6.40, agencySalaryUsd: 1.60, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 4, diamondTarget: 250000, validDaysRequired: 10, basicTotalSalaryUsd: 20.0, hostBasicSalaryUsd: 16.00, agencySalaryUsd: 4.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 5, diamondTarget: 500000, validDaysRequired: 8, basicTotalSalaryUsd: 40.0, hostBasicSalaryUsd: 32.00, agencySalaryUsd: 8.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 6, diamondTarget: 750000, validDaysRequired: 8, basicTotalSalaryUsd: 60.0, hostBasicSalaryUsd: 48.00, agencySalaryUsd: 12.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 7, diamondTarget: 1000000, validDaysRequired: 8, basicTotalSalaryUsd: 80.0, hostBasicSalaryUsd: 64.00, agencySalaryUsd: 16.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 8, diamondTarget: 1500000, validDaysRequired: 8, basicTotalSalaryUsd: 120.0, hostBasicSalaryUsd: 96.00, agencySalaryUsd: 24.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 9, diamondTarget: 2000000, validDaysRequired: 8, basicTotalSalaryUsd: 160.0, hostBasicSalaryUsd: 128.00, agencySalaryUsd: 32.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 10, diamondTarget: 2500000, validDaysRequired: 8, basicTotalSalaryUsd: 200.0, hostBasicSalaryUsd: 160.00, agencySalaryUsd: 40.00, specialIdBonus: 'None'),
    AgencyHostPolicyLevel(level: 11, diamondTarget: 3000000, validDaysRequired: 5, basicTotalSalaryUsd: 240.0, hostBasicSalaryUsd: 192.00, agencySalaryUsd: 48.00, specialIdBonus: 'Special ID 3 Days'),
    AgencyHostPolicyLevel(level: 12, diamondTarget: 3500000, validDaysRequired: 5, basicTotalSalaryUsd: 280.0, hostBasicSalaryUsd: 224.00, agencySalaryUsd: 56.00, specialIdBonus: 'Special ID 3 Days'),
    AgencyHostPolicyLevel(level: 13, diamondTarget: 4000000, validDaysRequired: 5, basicTotalSalaryUsd: 320.0, hostBasicSalaryUsd: 256.00, agencySalaryUsd: 64.00, specialIdBonus: 'Special ID 3 Days'),
    AgencyHostPolicyLevel(level: 14, diamondTarget: 4500000, validDaysRequired: 5, basicTotalSalaryUsd: 360.0, hostBasicSalaryUsd: 288.00, agencySalaryUsd: 72.00, specialIdBonus: 'Special ID 7 Days'),
    AgencyHostPolicyLevel(level: 15, diamondTarget: 5000000, validDaysRequired: 5, basicTotalSalaryUsd: 400.0, hostBasicSalaryUsd: 320.00, agencySalaryUsd: 80.00, specialIdBonus: 'Special ID 15 Days'),
    AgencyHostPolicyLevel(level: 16, diamondTarget: 6000000, validDaysRequired: 5, basicTotalSalaryUsd: 480.0, hostBasicSalaryUsd: 384.00, agencySalaryUsd: 96.00, specialIdBonus: 'Special ID 15 Days'),
    AgencyHostPolicyLevel(level: 17, diamondTarget: 7000000, validDaysRequired: 5, basicTotalSalaryUsd: 560.0, hostBasicSalaryUsd: 448.00, agencySalaryUsd: 112.00, specialIdBonus: 'Special ID 15 Days'),
    AgencyHostPolicyLevel(level: 18, diamondTarget: 8000000, validDaysRequired: 5, basicTotalSalaryUsd: 640.0, hostBasicSalaryUsd: 512.00, agencySalaryUsd: 128.00, specialIdBonus: 'Special ID 30 Days'),
    AgencyHostPolicyLevel(level: 19, diamondTarget: 9000000, validDaysRequired: 5, basicTotalSalaryUsd: 720.0, hostBasicSalaryUsd: 576.00, agencySalaryUsd: 144.00, specialIdBonus: 'Special ID 30 Days'),
    AgencyHostPolicyLevel(level: 20, diamondTarget: 10000000, validDaysRequired: 5, basicTotalSalaryUsd: 800.0, hostBasicSalaryUsd: 640.00, agencySalaryUsd: 160.00, specialIdBonus: 'Special ID 60 Days'),
    AgencyHostPolicyLevel(level: 21, diamondTarget: 15000000, validDaysRequired: 5, basicTotalSalaryUsd: 1200.0, hostBasicSalaryUsd: 960.00, agencySalaryUsd: 240.00, specialIdBonus: 'Special ID 60 Days'),
    AgencyHostPolicyLevel(level: 22, diamondTarget: 20000000, validDaysRequired: 5, basicTotalSalaryUsd: 1600.0, hostBasicSalaryUsd: 1280.00, agencySalaryUsd: 320.00, specialIdBonus: 'Special ID 60 Days'),
    AgencyHostPolicyLevel(level: 23, diamondTarget: 30000000, validDaysRequired: 5, basicTotalSalaryUsd: 2400.0, hostBasicSalaryUsd: 1920.00, agencySalaryUsd: 480.00, specialIdBonus: 'Special ID 90 Days'),
    AgencyHostPolicyLevel(level: 24, diamondTarget: 40000000, validDaysRequired: 5, basicTotalSalaryUsd: 3200.0, hostBasicSalaryUsd: 2560.00, agencySalaryUsd: 640.00, specialIdBonus: 'Special ID 90 Days'),
    AgencyHostPolicyLevel(level: 25, diamondTarget: 50000000, validDaysRequired: 5, basicTotalSalaryUsd: 4000.0, hostBasicSalaryUsd: 3200.00, agencySalaryUsd: 800.00, specialIdBonus: 'Special ID 120 Days'),
  ];

  static AgencyHostPolicyLevel getLevelForDiamonds(int diamonds) {
    AgencyHostPolicyLevel achieved = policyTable.first;
    for (final lvl in policyTable) {
      if (diamonds >= lvl.diamondTarget) {
        achieved = lvl;
      } else {
        break;
      }
    }
    return achieved;
  }

  static AgencyHostPolicyLevel? getNextLevel(int currentLevel) {
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
