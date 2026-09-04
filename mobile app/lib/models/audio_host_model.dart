class AudioHostModel {
  final String hostId;
  final String userId;
  final String userName;
  final String avatarUrl;
  final String agencyId;
  final String agencyName;
  final String status; // 'Active', 'Pending', 'Suspended', 'Removed'
  final DateTime joinDate;
  final int currentLevel;
  final int achievedDiamonds;
  final int completedValidDays;
  final int dailyOnlineMinutes; // Requires 120 mins (2h) online & unmuted per valid day
  final bool isTodayValid;
  final double pendingSalaryUsd;
  final double availableSalaryUsd;

  const AudioHostModel({
    required this.hostId,
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    required this.agencyId,
    required this.agencyName,
    this.status = 'Active',
    required this.joinDate,
    this.currentLevel = 1,
    this.achievedDiamonds = 0,
    this.completedValidDays = 0,
    this.dailyOnlineMinutes = 0,
    this.isTodayValid = false,
    this.pendingSalaryUsd = 0.0,
    this.availableSalaryUsd = 0.0,
  });

  AudioHostModel copyWith({
    String? hostId,
    String? userId,
    String? userName,
    String? avatarUrl,
    String? agencyId,
    String? agencyName,
    String? status,
    DateTime? joinDate,
    int? currentLevel,
    int? achievedDiamonds,
    int? completedValidDays,
    int? dailyOnlineMinutes,
    bool? isTodayValid,
    double? pendingSalaryUsd,
    double? availableSalaryUsd,
  }) {
    return AudioHostModel(
      hostId: hostId ?? this.hostId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      agencyId: agencyId ?? this.agencyId,
      agencyName: agencyName ?? this.agencyName,
      status: status ?? this.status,
      joinDate: joinDate ?? this.joinDate,
      currentLevel: currentLevel ?? this.currentLevel,
      achievedDiamonds: achievedDiamonds ?? this.achievedDiamonds,
      completedValidDays: completedValidDays ?? this.completedValidDays,
      dailyOnlineMinutes: dailyOnlineMinutes ?? this.dailyOnlineMinutes,
      isTodayValid: isTodayValid ?? this.isTodayValid,
      pendingSalaryUsd: pendingSalaryUsd ?? this.pendingSalaryUsd,
      availableSalaryUsd: availableSalaryUsd ?? this.availableSalaryUsd,
    );
  }

  Map<String, dynamic> toJson() => {
        'hostId': hostId,
        'userId': userId,
        'userName': userName,
        'avatarUrl': avatarUrl,
        'agencyId': agencyId,
        'agencyName': agencyName,
        'status': status,
        'joinDate': joinDate.toIso8601String(),
        'currentLevel': currentLevel,
        'achievedDiamonds': achievedDiamonds,
        'completedValidDays': completedValidDays,
        'dailyOnlineMinutes': dailyOnlineMinutes,
        'isTodayValid': isTodayValid,
        'pendingSalaryUsd': pendingSalaryUsd,
        'availableSalaryUsd': availableSalaryUsd,
      };

  factory AudioHostModel.fromJson(Map<String, dynamic> json) => AudioHostModel(
        hostId: json['hostId'] ?? '',
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        agencyId: json['agencyId'] ?? '',
        agencyName: json['agencyName'] ?? '',
        status: json['status'] ?? 'Active',
        joinDate: json['joinDate'] != null ? DateTime.parse(json['joinDate']) : DateTime.now(),
        currentLevel: json['currentLevel'] ?? 1,
        achievedDiamonds: json['achievedDiamonds'] ?? 0,
        completedValidDays: json['completedValidDays'] ?? 0,
        dailyOnlineMinutes: json['dailyOnlineMinutes'] ?? 0,
        isTodayValid: json['isTodayValid'] ?? false,
        pendingSalaryUsd: (json['pendingSalaryUsd'] ?? 0).toDouble(),
        availableSalaryUsd: (json['availableSalaryUsd'] ?? 0).toDouble(),
      );
}
