/// Room Level Progression Helper for ZeParty Audio & Video Rooms
///
/// Room level strictly starts at LV.0 at 0 coins and grows monotonically
/// with eligible completed gift transactions within the specific room ID.
class RoomLevelProgress {
  final int currentLevel;
  final int? nextLevel;
  final num currentLevelThreshold;
  final num nextLevelThreshold;
  final num additionalRequired;
  final num progressInLevel;
  final double progressRatio;
  final bool isMax;

  const RoomLevelProgress({
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

class RoomLevelHelper {
  static const int maxRoomLevel = 30;

  // Cumulative coin thresholds for Room Levels starting at LV.0
  static const List<num> thresholds = [
    0, // LV.0
    1000, // LV.1
    5000, // LV.2
    10000, // LV.3
    25000, // LV.4
    50000, // LV.5
    100000, // LV.6
    250000, // LV.7
    500000, // LV.8
    1000000, // LV.9
    2000000, // LV.10
    3500000, // LV.11
    5000000, // LV.12
    7500000, // LV.13
    10000000, // LV.14
    15000000, // LV.15
    20000000, // LV.16
    30000000, // LV.17
    45000000, // LV.18
    60000000, // LV.19
    80000000, // LV.20
    100000000, // LV.21
    130000000, // LV.22
    160000000, // LV.23
    200000000, // LV.24
    250000000, // LV.25
    300000000, // LV.26
    360000000, // LV.27
    420000000, // LV.28
    480000000, // LV.29
    550000000, // LV.30 (Max)
  ];

  static int getRoomLevel(num totalGifts) {
    if (totalGifts <= 0) return 0;
    int lvl = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (totalGifts >= thresholds[i]) {
        lvl = i;
      } else {
        break;
      }
    }
    return lvl.clamp(0, maxRoomLevel);
  }

  static RoomLevelProgress getRoomLevelProgress(num totalGifts) {
    final coins = totalGifts < 0 ? 0 : totalGifts;
    final currentLvl = getRoomLevel(coins);

    if (currentLvl >= maxRoomLevel) {
      final maxThresh = thresholds[maxRoomLevel];
      return RoomLevelProgress(
        currentLevel: maxRoomLevel,
        nextLevel: null,
        currentLevelThreshold: maxThresh,
        nextLevelThreshold: maxThresh,
        additionalRequired: 0,
        progressInLevel: 0,
        progressRatio: 1.0,
        isMax: true,
      );
    }

    final curThresh = thresholds[currentLvl];
    final nextThresh = thresholds[currentLvl + 1];
    final additional = nextThresh - curThresh;
    final progressInLevel = coins - curThresh;
    final ratio = additional > 0 ? (progressInLevel / additional).clamp(0.0, 1.0) : 1.0;

    return RoomLevelProgress(
      currentLevel: currentLvl,
      nextLevel: currentLvl + 1,
      currentLevelThreshold: curThresh,
      nextLevelThreshold: nextThresh,
      additionalRequired: additional,
      progressInLevel: progressInLevel,
      progressRatio: ratio,
      isMax: false,
    );
  }

  static String formatCoins(num amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}M';
    }
    if (amount >= 1000) {
      final val = amount / 1000;
      return '${val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1)}k';
    }
    return '$amount';
  }
}

