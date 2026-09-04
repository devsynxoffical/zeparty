class AgencyMemberModel {
  final String id;
  final String agencyId;
  final String userId;
  final String name;
  final String avatarUrl;
  final String countryCode;
  final String role; // 'Owner', 'Manager', 'Host', 'Member'
  final String status; // 'Invited', 'Pending', 'Active', 'Suspended', 'Left', 'Removed'
  final String targetStatus; // 'Target Achieved', 'In Progress', 'Not Eligible', 'Under Review', 'Settled'
  final DateTime joinedAt;

  const AgencyMemberModel({
    required this.id,
    required this.agencyId,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.countryCode,
    this.role = 'Member',
    this.status = 'Active',
    this.targetStatus = 'In Progress',
    required this.joinedAt,
  });

  AgencyMemberModel copyWith({
    String? id,
    String? agencyId,
    String? userId,
    String? name,
    String? avatarUrl,
    String? countryCode,
    String? role,
    String? status,
    String? targetStatus,
    DateTime? joinedAt,
  }) {
    return AgencyMemberModel(
      id: id ?? this.id,
      agencyId: agencyId ?? this.agencyId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      countryCode: countryCode ?? this.countryCode,
      role: role ?? this.role,
      status: status ?? this.status,
      targetStatus: targetStatus ?? this.targetStatus,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'agencyId': agencyId,
        'userId': userId,
        'name': name,
        'avatarUrl': avatarUrl,
        'countryCode': countryCode,
        'role': role,
        'status': status,
        'targetStatus': targetStatus,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory AgencyMemberModel.fromJson(Map<String, dynamic> json) => AgencyMemberModel(
        id: json['id'] ?? '',
        agencyId: json['agencyId'] ?? '',
        userId: json['userId'] ?? '',
        name: json['name'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        countryCode: json['countryCode'] ?? 'GLOBAL',
        role: json['role'] ?? 'Member',
        status: json['status'] ?? 'Active',
        targetStatus: json['targetStatus'] ?? 'In Progress',
        joinedAt: json['joinedAt'] != null ? DateTime.parse(json['joinedAt']) : DateTime.now(),
      );
}
