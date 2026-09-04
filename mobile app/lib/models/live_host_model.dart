class LiveHostModel {
  final String liveHostId;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final String countryCode;
  final String status; // 'Active', 'Under Review', 'Suspended'
  final DateTime approvalDate;
  final int currentLevel;
  final int achievedDiamonds;
  final int completedValidDays;
  final int dailyLiveMinutes; // Requires 60 mins (1h) verified live streaming per valid day
  final bool isTodayValid;
  final double pendingSalaryUsd;
  final double availableSalaryUsd;

  const LiveHostModel({
    required this.liveHostId,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.countryCode,
    this.status = 'Active',
    required this.approvalDate,
    this.currentLevel = 1,
    this.achievedDiamonds = 0,
    this.completedValidDays = 0,
    this.dailyLiveMinutes = 0,
    this.isTodayValid = false,
    this.pendingSalaryUsd = 0.0,
    this.availableSalaryUsd = 0.0,
  });

  LiveHostModel copyWith({
    String? liveHostId,
    String? userId,
    String? displayName,
    String? avatarUrl,
    String? countryCode,
    String? status,
    DateTime? approvalDate,
    int? currentLevel,
    int? achievedDiamonds,
    int? completedValidDays,
    int? dailyLiveMinutes,
    bool? isTodayValid,
    double? pendingSalaryUsd,
    double? availableSalaryUsd,
  }) {
    return LiveHostModel(
      liveHostId: liveHostId ?? this.liveHostId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      countryCode: countryCode ?? this.countryCode,
      status: status ?? this.status,
      approvalDate: approvalDate ?? this.approvalDate,
      currentLevel: currentLevel ?? this.currentLevel,
      achievedDiamonds: achievedDiamonds ?? this.achievedDiamonds,
      completedValidDays: completedValidDays ?? this.completedValidDays,
      dailyLiveMinutes: dailyLiveMinutes ?? this.dailyLiveMinutes,
      isTodayValid: isTodayValid ?? this.isTodayValid,
      pendingSalaryUsd: pendingSalaryUsd ?? this.pendingSalaryUsd,
      availableSalaryUsd: availableSalaryUsd ?? this.availableSalaryUsd,
    );
  }

  Map<String, dynamic> toJson() => {
        'liveHostId': liveHostId,
        'userId': userId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'countryCode': countryCode,
        'status': status,
        'approvalDate': approvalDate.toIso8601String(),
        'currentLevel': currentLevel,
        'achievedDiamonds': achievedDiamonds,
        'completedValidDays': completedValidDays,
        'dailyLiveMinutes': dailyLiveMinutes,
        'isTodayValid': isTodayValid,
        'pendingSalaryUsd': pendingSalaryUsd,
        'availableSalaryUsd': availableSalaryUsd,
      };

  factory LiveHostModel.fromJson(Map<String, dynamic> json) => LiveHostModel(
        liveHostId: json['liveHostId'] ?? '',
        userId: json['userId'] ?? '',
        displayName: json['displayName'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        countryCode: json['countryCode'] ?? 'GLOBAL',
        status: json['status'] ?? 'Active',
        approvalDate: json['approvalDate'] != null ? DateTime.parse(json['approvalDate']) : DateTime.now(),
        currentLevel: json['currentLevel'] ?? 1,
        achievedDiamonds: json['achievedDiamonds'] ?? 0,
        completedValidDays: json['completedValidDays'] ?? 0,
        dailyLiveMinutes: json['dailyLiveMinutes'] ?? 0,
        isTodayValid: json['isTodayValid'] ?? false,
        pendingSalaryUsd: (json['pendingSalaryUsd'] ?? 0).toDouble(),
        availableSalaryUsd: (json['availableSalaryUsd'] ?? 0).toDouble(),
      );
}
