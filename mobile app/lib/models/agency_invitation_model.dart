class AgencyInvitationModel {
  final String id;
  final String agencyId;
  final String agencyName;
  final String inviterUserId;
  final String inviterName;
  final String targetUserId;
  final String targetName;
  final String status; // 'Invited', 'Pending', 'Accepted', 'Declined', 'Expired', 'Cancelled'
  final DateTime createdAt;
  final DateTime expiresAt;

  const AgencyInvitationModel({
    required this.id,
    required this.agencyId,
    required this.agencyName,
    required this.inviterUserId,
    required this.inviterName,
    required this.targetUserId,
    required this.targetName,
    this.status = 'Pending',
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'agencyId': agencyId,
        'agencyName': agencyName,
        'inviterUserId': inviterUserId,
        'inviterName': inviterName,
        'targetUserId': targetUserId,
        'targetName': targetName,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AgencyInvitationModel.fromJson(Map<String, dynamic> json) => AgencyInvitationModel(
        id: json['id'] ?? '',
        agencyId: json['agencyId'] ?? '',
        agencyName: json['agencyName'] ?? '',
        inviterUserId: json['inviterUserId'] ?? '',
        inviterName: json['inviterName'] ?? '',
        targetUserId: json['targetUserId'] ?? '',
        targetName: json['targetName'] ?? '',
        status: json['status'] ?? 'Pending',
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
        expiresAt: json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : DateTime.now().add(const Duration(days: 7)),
      );
}
