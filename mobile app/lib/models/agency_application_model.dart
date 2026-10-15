class AgencyApplicationModel {
  final String id;
  final String applicantUserId;
  final String applicantZePartyId;
  final String applicantName;
  final String applicantAvatar;
  final String agencyName;
  final String description;
  final String phoneNumber;
  final List<String> externalHostIds;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedByAdminId;

  const AgencyApplicationModel({
    required this.id,
    required this.applicantUserId,
    required this.applicantZePartyId,
    required this.applicantName,
    required this.applicantAvatar,
    required this.agencyName,
    required this.description,
    required this.phoneNumber,
    required this.externalHostIds,
    this.status = 'Pending',
    this.rejectionReason,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedByAdminId,
  });

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';

  AgencyApplicationModel copyWith({
    String? id,
    String? applicantUserId,
    String? applicantZePartyId,
    String? applicantName,
    String? applicantAvatar,
    String? agencyName,
    String? description,
    String? phoneNumber,
    List<String>? externalHostIds,
    String? status,
    String? rejectionReason,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedByAdminId,
  }) {
    return AgencyApplicationModel(
      id: id ?? this.id,
      applicantUserId: applicantUserId ?? this.applicantUserId,
      applicantZePartyId: applicantZePartyId ?? this.applicantZePartyId,
      applicantName: applicantName ?? this.applicantName,
      applicantAvatar: applicantAvatar ?? this.applicantAvatar,
      agencyName: agencyName ?? this.agencyName,
      description: description ?? this.description,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      externalHostIds: externalHostIds ?? this.externalHostIds,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedByAdminId: reviewedByAdminId ?? this.reviewedByAdminId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'applicantUserId': applicantUserId,
      'applicantZePartyId': applicantZePartyId,
      'applicantName': applicantName,
      'applicantAvatar': applicantAvatar,
      'agencyName': agencyName,
      'description': description,
      'phoneNumber': phoneNumber,
      'externalHostIds': externalHostIds,
      'status': status,
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedByAdminId': reviewedByAdminId,
    };
  }

  factory AgencyApplicationModel.fromJson(Map<String, dynamic> json) {
    return AgencyApplicationModel(
      id: json['id']?.toString() ?? '',
      applicantUserId: json['applicantUserId']?.toString() ?? '',
      applicantZePartyId: json['applicantZePartyId']?.toString() ?? '',
      applicantName: json['applicantName']?.toString() ?? '',
      applicantAvatar: json['applicantAvatar']?.toString() ?? '',
      agencyName: json['agencyName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      externalHostIds: json['externalHostIds'] is List
          ? (json['externalHostIds'] as List).map((e) => e.toString()).toList()
          : [],
      status: json['status']?.toString() ?? 'Pending',
      rejectionReason: json['rejectionReason']?.toString(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'].toString())
          : null,
      reviewedByAdminId: json['reviewedByAdminId']?.toString(),
    );
  }
}
