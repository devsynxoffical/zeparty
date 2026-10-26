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

class HostTargetCycle {
  final String hostType;
  final int cycleDays;
  final int cycleIndex;
  final int totalCycles;
  final int startDay;
  final int endDay;
  final DateTime? cycleStartDate;
  final DateTime? cycleEndDate;
  final int daysRemaining;
  final String cycleIdentifier;
  final String formattedCycle;
  final String formattedLabel;

  const HostTargetCycle({
    required this.hostType,
    required this.cycleDays,
    required this.cycleIndex,
    required this.totalCycles,
    required this.startDay,
    required this.endDay,
    this.cycleStartDate,
    this.cycleEndDate,
    required this.daysRemaining,
    required this.cycleIdentifier,
    required this.formattedCycle,
    required this.formattedLabel,
  });

  factory HostTargetCycle.fromJson(Map<String, dynamic> json, {String defaultHostType = 'LIVE_HOST'}) {
    final type = (json['hostType'] ?? defaultHostType).toString();
    final defaultDays = type == 'LIVE_HOST' ? 10 : 15;
    final cDays = int.tryParse(json['cycleDays']?.toString() ?? '') ?? defaultDays;

    return HostTargetCycle(
      hostType: type,
      cycleDays: cDays,
      cycleIndex: int.tryParse(json['cycleIndex']?.toString() ?? '1') ?? 1,
      totalCycles: int.tryParse(json['totalCycles']?.toString() ?? (cDays == 10 ? '3' : '2')) ?? (cDays == 10 ? 3 : 2),
      startDay: int.tryParse(json['startDay']?.toString() ?? '1') ?? 1,
      endDay: int.tryParse(json['endDay']?.toString() ?? '$cDays') ?? cDays,
      cycleStartDate: json['cycleStartDate'] != null ? DateTime.tryParse(json['cycleStartDate'].toString()) : null,
      cycleEndDate: json['cycleEndDate'] != null ? DateTime.tryParse(json['cycleEndDate'].toString()) : null,
      daysRemaining: int.tryParse(json['daysRemaining']?.toString() ?? '0') ?? 0,
      cycleIdentifier: json['cycleIdentifier']?.toString() ?? '',
      formattedCycle: json['formattedCycle']?.toString() ?? '',
      formattedLabel: json['formattedLabel']?.toString() ?? 'Cycle ($cDays days)',
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
  final HostTargetCycle? cycle;

  int get cycleDays => cycle?.cycleDays ?? (hostType == 'LIVE_HOST' ? 10 : 15);
  String get cycleBadge => '$cycleDays-Day Settlement Cycle';
  String get cycleDateRange => cycle?.formattedCycle ?? (cycle?.formattedLabel ?? 'Current Cycle');
  int get countdownDays => cycle?.daysRemaining ?? 0;

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
    this.cycle,
  });

  factory HostTargetSummaryModel.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] is Map<String, dynamic> ? json['metrics'] as Map<String, dynamic> : null;
    final cycleMap = json['cycle'] is Map<String, dynamic> ? json['cycle'] as Map<String, dynamic> : null;
    final hType = (json['hostType'] ?? 'LIVE_HOST').toString();

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

    final parsedCycle = cycleMap != null
        ? HostTargetCycle.fromJson(cycleMap, defaultHostType: hType)
        : null;

    return HostTargetSummaryModel(
      isHost: json['isHost'] == true,
      isHostActive: json['isHostActive'] == true,
      hostType: hType,
      achievedCoins: achieved,
      nextTargetCoins: finalTarget,
      remainingCoins: remaining,
      progressPercent: normalizedProgress.clamp(0.0, 1.0),
      currentTier: cTier,
      nextTier: nTier,
      agencyName: json['agencyName']?.toString(),
      cycleIdentifier: parsedCycle?.cycleIdentifier ?? cycleMap?['cycleIdentifier']?.toString() ?? json['cycleIdentifier']?.toString(),
      formula: json['formula']?.toString() ?? '100% normal gift coins + 10% lucky gift coins',
      cycle: parsedCycle,
    );
  }
}

