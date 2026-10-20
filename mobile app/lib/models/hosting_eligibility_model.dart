class HostingEligibilityModel {
  final String userId;
  final List<String> activeRoles;
  final List<String> pendingRequests;
  final List<String> suspendedRoles;
  final bool canApplyLiveHost;
  final bool canJoinAudioHost;
  final bool canCreateAgency;
  final bool hasConflict;
  final String? conflictCode;
  final String? conflictMessage;

  const HostingEligibilityModel({
    required this.userId,
    this.activeRoles = const [],
    this.pendingRequests = const [],
    this.suspendedRoles = const [],
    this.canApplyLiveHost = true,
    this.canJoinAudioHost = true,
    this.canCreateAgency = true,
    this.hasConflict = false,
    this.conflictCode,
    this.conflictMessage,
  });

  factory HostingEligibilityModel.fromJson(Map<String, dynamic> json) {
    return HostingEligibilityModel(
      userId: json['userId']?.toString() ?? '',
      activeRoles: (json['activeRoles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      pendingRequests: (json['pendingRequests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      suspendedRoles: (json['suspendedRoles'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      canApplyLiveHost: json['canApplyLiveHost'] == true,
      canJoinAudioHost: json['canJoinAudioHost'] == true,
      canCreateAgency: json['canCreateAgency'] == true,
      hasConflict: json['hasConflict'] == true,
      conflictCode: json['conflictCode']?.toString(),
      conflictMessage: json['conflictMessage']?.toString(),
    );
  }
}
