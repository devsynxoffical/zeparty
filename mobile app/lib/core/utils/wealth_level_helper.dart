library;

/// ZeParty Wealth Level Progression (Approved Schedule: 3 November 2026)
///
/// Source of Truth Specification:
/// - Maximum level is 100.
/// - Level 1 starts at zero sending coins.
/// - Level 2 requires 10,000 additional coins (Cumulative: 10,000).
/// - Level 3 requires 20,000 additional coins (Cumulative: 30,000).
/// - Level 4 requires 40,000 additional coins (Cumulative: 70,000).
/// - ...
/// - Level 100 requires exactly 250,000,000 cumulative sending coins.
/// - Never award a level using a fixed 10,000 coin calculation.
/// - Uses the highest level whose cumulative threshold has been reached.
/// - Preserves extra progress toward the next level.
/// - At Level 100: Show MAX, never display Level 101.

class WealthThreshold {
  final int level;
  final int additional;
  final int cumulativeTotal;

  const WealthThreshold({
    required this.level,
    required this.additional,
    required this.cumulativeTotal,
  });
}

class WealthLevelProgress {
  final int currentLevel;
  final int? nextLevel;
  final int currentLevelThreshold;
  final int nextLevelThreshold;
  final int additionalRequired;
  final int progressInLevel;
  final double progressRatio;
  final bool isMax;

  const WealthLevelProgress({
    required this.currentLevel,
    this.nextLevel,
    required this.currentLevelThreshold,
    required this.nextLevelThreshold,
    required this.additionalRequired,
    required this.progressInLevel,
    required this.progressRatio,
    required this.isMax,
  });
}

class WealthLevelHelper {
  static const int maxLevel = 100;
  static const int maxCumulativeCoins = 250000000;

  static const List<WealthThreshold> thresholds = [
    WealthThreshold(level: 1, additional: 0, cumulativeTotal: 0),
    WealthThreshold(level: 2, additional: 10000, cumulativeTotal: 10000),
    WealthThreshold(level: 3, additional: 20000, cumulativeTotal: 30000),
    WealthThreshold(level: 4, additional: 40000, cumulativeTotal: 70000),
    WealthThreshold(level: 5, additional: 67000, cumulativeTotal: 137000),
    WealthThreshold(level: 6, additional: 97000, cumulativeTotal: 234000),
    WealthThreshold(level: 7, additional: 129000, cumulativeTotal: 363000),
    WealthThreshold(level: 8, additional: 163000, cumulativeTotal: 526000),
    WealthThreshold(level: 9, additional: 198000, cumulativeTotal: 724000),
    WealthThreshold(level: 10, additional: 235000, cumulativeTotal: 959000),
    WealthThreshold(level: 11, additional: 273000, cumulativeTotal: 1232000),
    WealthThreshold(level: 12, additional: 312000, cumulativeTotal: 1544000),
    WealthThreshold(level: 13, additional: 352000, cumulativeTotal: 1896000),
    WealthThreshold(level: 14, additional: 394000, cumulativeTotal: 2290000),
    WealthThreshold(level: 15, additional: 436000, cumulativeTotal: 2726000),
    WealthThreshold(level: 16, additional: 479000, cumulativeTotal: 3205000),
    WealthThreshold(level: 17, additional: 523000, cumulativeTotal: 3728000),
    WealthThreshold(level: 18, additional: 568000, cumulativeTotal: 4296000),
    WealthThreshold(level: 19, additional: 614000, cumulativeTotal: 4910000),
    WealthThreshold(level: 20, additional: 660000, cumulativeTotal: 5570000),
    WealthThreshold(level: 21, additional: 707000, cumulativeTotal: 6277000),
    WealthThreshold(level: 22, additional: 755000, cumulativeTotal: 7032000),
    WealthThreshold(level: 23, additional: 804000, cumulativeTotal: 7836000),
    WealthThreshold(level: 24, additional: 853000, cumulativeTotal: 8689000),
    WealthThreshold(level: 25, additional: 903000, cumulativeTotal: 9592000),
    WealthThreshold(level: 26, additional: 953000, cumulativeTotal: 10545000),
    WealthThreshold(level: 27, additional: 1004000, cumulativeTotal: 11549000),
    WealthThreshold(level: 28, additional: 1056000, cumulativeTotal: 12605000),
    WealthThreshold(level: 29, additional: 1108000, cumulativeTotal: 13713000),
    WealthThreshold(level: 30, additional: 1160000, cumulativeTotal: 14873000),
    WealthThreshold(level: 31, additional: 1213000, cumulativeTotal: 16086000),
    WealthThreshold(level: 32, additional: 1267000, cumulativeTotal: 17353000),
    WealthThreshold(level: 33, additional: 1321000, cumulativeTotal: 18674000),
    WealthThreshold(level: 34, additional: 1376000, cumulativeTotal: 20050000),
    WealthThreshold(level: 35, additional: 1431000, cumulativeTotal: 21481000),
    WealthThreshold(level: 36, additional: 1487000, cumulativeTotal: 22968000),
    WealthThreshold(level: 37, additional: 1543000, cumulativeTotal: 24511000),
    WealthThreshold(level: 38, additional: 1599000, cumulativeTotal: 26110000),
    WealthThreshold(level: 39, additional: 1656000, cumulativeTotal: 27766000),
    WealthThreshold(level: 40, additional: 1713000, cumulativeTotal: 29479000),
    WealthThreshold(level: 41, additional: 1771000, cumulativeTotal: 31250000),
    WealthThreshold(level: 42, additional: 1829000, cumulativeTotal: 33079000),
    WealthThreshold(level: 43, additional: 1888000, cumulativeTotal: 34967000),
    WealthThreshold(level: 44, additional: 1947000, cumulativeTotal: 36914000),
    WealthThreshold(level: 45, additional: 2006000, cumulativeTotal: 38920000),
    WealthThreshold(level: 46, additional: 2066000, cumulativeTotal: 40986000),
    WealthThreshold(level: 47, additional: 2126000, cumulativeTotal: 43112000),
    WealthThreshold(level: 48, additional: 2186000, cumulativeTotal: 45298000),
    WealthThreshold(level: 49, additional: 2247000, cumulativeTotal: 47545000),
    WealthThreshold(level: 50, additional: 2308000, cumulativeTotal: 49853000),
    WealthThreshold(level: 51, additional: 2370000, cumulativeTotal: 52223000),
    WealthThreshold(level: 52, additional: 2432000, cumulativeTotal: 54655000),
    WealthThreshold(level: 53, additional: 2494000, cumulativeTotal: 57149000),
    WealthThreshold(level: 54, additional: 2556000, cumulativeTotal: 59705000),
    WealthThreshold(level: 55, additional: 2619000, cumulativeTotal: 62324000),
    WealthThreshold(level: 56, additional: 2683000, cumulativeTotal: 65007000),
    WealthThreshold(level: 57, additional: 2746000, cumulativeTotal: 67753000),
    WealthThreshold(level: 58, additional: 2810000, cumulativeTotal: 70563000),
    WealthThreshold(level: 59, additional: 2874000, cumulativeTotal: 73437000),
    WealthThreshold(level: 60, additional: 2939000, cumulativeTotal: 76376000),
    WealthThreshold(level: 61, additional: 3004000, cumulativeTotal: 79380000),
    WealthThreshold(level: 62, additional: 3069000, cumulativeTotal: 82449000),
    WealthThreshold(level: 63, additional: 3134000, cumulativeTotal: 85583000),
    WealthThreshold(level: 64, additional: 3200000, cumulativeTotal: 88783000),
    WealthThreshold(level: 65, additional: 3266000, cumulativeTotal: 92049000),
    WealthThreshold(level: 66, additional: 3332000, cumulativeTotal: 95381000),
    WealthThreshold(level: 67, additional: 3399000, cumulativeTotal: 98780000),
    WealthThreshold(level: 68, additional: 3466000, cumulativeTotal: 102246000),
    WealthThreshold(level: 69, additional: 3533000, cumulativeTotal: 105779000),
    WealthThreshold(level: 70, additional: 3600000, cumulativeTotal: 109379000),
    WealthThreshold(level: 71, additional: 3668000, cumulativeTotal: 113047000),
    WealthThreshold(level: 72, additional: 3736000, cumulativeTotal: 116783000),
    WealthThreshold(level: 73, additional: 3804000, cumulativeTotal: 120587000),
    WealthThreshold(level: 74, additional: 3872000, cumulativeTotal: 124459000),
    WealthThreshold(level: 75, additional: 3941000, cumulativeTotal: 128400000),
    WealthThreshold(level: 76, additional: 4010000, cumulativeTotal: 132410000),
    WealthThreshold(level: 77, additional: 4080000, cumulativeTotal: 136490000),
    WealthThreshold(level: 78, additional: 4149000, cumulativeTotal: 140639000),
    WealthThreshold(level: 79, additional: 4219000, cumulativeTotal: 144858000),
    WealthThreshold(level: 80, additional: 4289000, cumulativeTotal: 149147000),
    WealthThreshold(level: 81, additional: 4359000, cumulativeTotal: 153506000),
    WealthThreshold(level: 82, additional: 4430000, cumulativeTotal: 157936000),
    WealthThreshold(level: 83, additional: 4500000, cumulativeTotal: 162436000),
    WealthThreshold(level: 84, additional: 4572000, cumulativeTotal: 167008000),
    WealthThreshold(level: 85, additional: 4643000, cumulativeTotal: 171651000),
    WealthThreshold(level: 86, additional: 4714000, cumulativeTotal: 176365000),
    WealthThreshold(level: 87, additional: 4786000, cumulativeTotal: 181151000),
    WealthThreshold(level: 88, additional: 4858000, cumulativeTotal: 186009000),
    WealthThreshold(level: 89, additional: 4930000, cumulativeTotal: 190939000),
    WealthThreshold(level: 90, additional: 5003000, cumulativeTotal: 195942000),
    WealthThreshold(level: 91, additional: 5075000, cumulativeTotal: 201017000),
    WealthThreshold(level: 92, additional: 5148000, cumulativeTotal: 206165000),
    WealthThreshold(level: 93, additional: 5221000, cumulativeTotal: 211386000),
    WealthThreshold(level: 94, additional: 5295000, cumulativeTotal: 216681000),
    WealthThreshold(level: 95, additional: 5368000, cumulativeTotal: 222049000),
    WealthThreshold(level: 96, additional: 5442000, cumulativeTotal: 227491000),
    WealthThreshold(level: 97, additional: 5516000, cumulativeTotal: 233007000),
    WealthThreshold(level: 98, additional: 5590000, cumulativeTotal: 238597000),
    WealthThreshold(level: 99, additional: 5664000, cumulativeTotal: 244261000),
    WealthThreshold(level: 100, additional: 5739000, cumulativeTotal: 250000000),
  ];

  /// Get authoritative Wealth Level (1..100) based on lifetime cumulative sending coins
  static int getLevelFromSending(num cumulativeCoins) {
    final coins = cumulativeCoins.toInt();
    if (coins <= 0) return 1;
    if (coins >= maxCumulativeCoins) return maxLevel;

    int level = 1;
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (coins >= thresholds[i].cumulativeTotal) {
        level = thresholds[i].level;
        break;
      }
    }
    return level.clamp(1, maxLevel);
  }

  /// Get detailed progress details for current level, next level, and progress bar
  static WealthLevelProgress getProgress(num cumulativeCoins) {
    final coins = cumulativeCoins.toInt();
    if (coins >= maxCumulativeCoins) {
      return const WealthLevelProgress(
        currentLevel: maxLevel,
        nextLevel: null,
        currentLevelThreshold: maxCumulativeCoins,
        nextLevelThreshold: maxCumulativeCoins,
        additionalRequired: 0,
        progressInLevel: 0,
        progressRatio: 1.0,
        isMax: true,
      );
    }

    final currentLevel = getLevelFromSending(coins);
    final currentThreshold = thresholds[currentLevel - 1];
    final nextThreshold = thresholds[currentLevel]; // nextLevel = currentLevel + 1

    final progressInLevel = coins - currentThreshold.cumulativeTotal;
    final additionalRequired = nextThreshold.additional;
    final progressRatio = additionalRequired > 0
        ? (progressInLevel / additionalRequired).clamp(0.0, 1.0)
        : 1.0;

    return WealthLevelProgress(
      currentLevel: currentLevel,
      nextLevel: currentLevel + 1,
      currentLevelThreshold: currentThreshold.cumulativeTotal,
      nextLevelThreshold: nextThreshold.cumulativeTotal,
      additionalRequired: additionalRequired,
      progressInLevel: progressInLevel,
      progressRatio: progressRatio,
      isMax: false,
    );
  }
}
