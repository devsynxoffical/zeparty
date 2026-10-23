class HostTargetTier {
  final int level;
  final int targetCoins;
  final double basicSalaryUSD;
  final double hostSalaryUSD;
  final double agencySalaryUSD;

  const HostTargetTier({
    required this.level,
    required this.targetCoins,
    required this.basicSalaryUSD,
    required this.hostSalaryUSD,
    required this.agencySalaryUSD,
  });

  factory HostTargetTier.fromJson(Map<String, dynamic> json) {
    return HostTargetTier(
      level: int.tryParse(json['level']?.toString() ?? '1') ?? 1,
      targetCoins: int.tryParse(json['targetCoins']?.toString() ?? '0') ?? 0,
      basicSalaryUSD: double.tryParse(json['basicSalaryUSD']?.toString() ?? '0') ?? 0.0,
      hostSalaryUSD: double.tryParse(json['hostSalaryUSD']?.toString() ?? '0') ?? 0.0,
      agencySalaryUSD: double.tryParse(json['agencySalaryUSD']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class HostTargetSummaryModel {
  final bool isHost;
  final bool isHostActive;
  final String hostType; // LIVE_HOST, AUDIO_HOST
  final int achievedCoins;
  final int nextTargetCoins;
  final int remainingCoins;
  final double progressPercent; // Normalized 0.0 to 1.0
  final HostTargetTier? currentTier;
  final HostTargetTier? nextTier;
  final String? agencyName;
  final String? cycleIdentifier;
  final String? formula;

  const HostTargetSummaryModel({
    required this.isHost,
    this.isHostActive = false,
    this.hostType = 'LIVE_HOST',
    required this.achievedCoins,
    required this.nextTargetCoins,
    required this.remainingCoins,
    required this.progressPercent,
    this.currentTier,
    this.nextTier,
    this.agencyName,
    this.cycleIdentifier,
    this.formula,
  });

  factory HostTargetSummaryModel.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] is Map<String, dynamic> ? json['metrics'] as Map<String, dynamic> : null;
    final cycle = json['cycle'] is Map<String, dynamic> ? json['cycle'] as Map<String, dynamic> : null;

    final achieved = int.tryParse(
            json['achievedCoins']?.toString() ?? metrics?['achievedCoins']?.toString() ?? json['currentCoins']?.toString() ?? '0') ??
        0;

    final nextTarget = int.tryParse(
            json['nextTargetCoins']?.toString() ?? metrics?['nextTargetCoins']?.toString() ?? json['totalTargetCoins']?.toString() ?? '0') ??
        0;

    final remaining = int.tryParse(
            json['remainingCoins']?.toString() ?? metrics?['remainingCoins']?.toString() ?? '0') ??
        0;

    final rawProgress = double.tryParse(
            json['progressPercent']?.toString() ?? metrics?['progressPercent']?.toString() ?? '0') ??
        0.0;
    final normalizedProgress = rawProgress > 1.0 ? (rawProgress / 100.0) : rawProgress;

    final cTier = json['currentTier'] is Map<String, dynamic>
        ? HostTargetTier.fromJson(json['currentTier'] as Map<String, dynamic>)
        : null;

    final nTier = json['nextTier'] is Map<String, dynamic>
        ? HostTargetTier.fromJson(json['nextTier'] as Map<String, dynamic>)
        : null;

    final finalTarget = nextTarget > 0 ? nextTarget : (nTier?.targetCoins ?? (cTier?.targetCoins ?? achieved));

    return HostTargetSummaryModel(
      isHost: json['isHost'] == true,
      isHostActive: json['isHostActive'] == true,
      hostType: (json['hostType'] ?? 'LIVE_HOST').toString(),
      achievedCoins: achieved,
      nextTargetCoins: finalTarget,
      remainingCoins: remaining,
      progressPercent: normalizedProgress.clamp(0.0, 1.0),
      currentTier: cTier,
      nextTier: nTier,
      agencyName: json['agencyName']?.toString(),
      cycleIdentifier: cycle?['cycleIdentifier']?.toString() ?? json['cycleIdentifier']?.toString(),
      formula: json['formula']?.toString() ?? '100% normal gift coins + 10% lucky gift coins',
    );
  }
}

