class LiveHostApplicationModel {
  final String id;
  final String userId;
  final String legalName;
  final String displayName;
  final String dateOfBirth;
  final String gender;
  final String country;
  final String city;
  final String languages;
  final String category; // 'Music', 'Gaming', 'Chat', 'Dance', 'Talk Show'
  final String schedule;
  final String phoneOrEmail;
  final String govIdType; // 'Passport', 'National ID', 'Driving License'
  final String govIdNumber;
  final String frontIdUrl;
  final String backIdUrl;
  final String selfieUrl;
  final String status; // 'Draft', 'Submitted', 'Under Review', 'More Info Required', 'Approved', 'Rejected', 'Suspended'
  final String? rejectionReason;
  final DateTime submittedAt;

  const LiveHostApplicationModel({
    required this.id,
    required this.userId,
    required this.legalName,
    required this.displayName,
    required this.dateOfBirth,
    required this.gender,
    required this.country,
    required this.city,
    required this.languages,
    required this.category,
    required this.schedule,
    required this.phoneOrEmail,
    required this.govIdType,
    required this.govIdNumber,
    required this.frontIdUrl,
    required this.backIdUrl,
    required this.selfieUrl,
    this.status = 'Submitted',
    this.rejectionReason,
    required this.submittedAt,
  });

  LiveHostApplicationModel copyWith({
    String? id,
    String? userId,
    String? legalName,
    String? displayName,
    String? dateOfBirth,
    String? gender,
    String? country,
    String? city,
    String? languages,
    String? category,
    String? schedule,
    String? phoneOrEmail,
    String? govIdType,
    String? govIdNumber,
    String? frontIdUrl,
    String? backIdUrl,
    String? selfieUrl,
    String? status,
    String? rejectionReason,
    DateTime? submittedAt,
  }) {
    return LiveHostApplicationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      legalName: legalName ?? this.legalName,
      displayName: displayName ?? this.displayName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      country: country ?? this.country,
      city: city ?? this.city,
      languages: languages ?? this.languages,
      category: category ?? this.category,
      schedule: schedule ?? this.schedule,
      phoneOrEmail: phoneOrEmail ?? this.phoneOrEmail,
      govIdType: govIdType ?? this.govIdType,
      govIdNumber: govIdNumber ?? this.govIdNumber,
      frontIdUrl: frontIdUrl ?? this.frontIdUrl,
      backIdUrl: backIdUrl ?? this.backIdUrl,
      selfieUrl: selfieUrl ?? this.selfieUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'legalName': legalName,
        'displayName': displayName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'country': country,
        'city': city,
        'languages': languages,
        'category': category,
        'schedule': schedule,
        'phoneOrEmail': phoneOrEmail,
        'govIdType': govIdType,
        'govIdNumber': govIdNumber,
        'frontIdUrl': frontIdUrl,
        'backIdUrl': backIdUrl,
        'selfieUrl': selfieUrl,
        'status': status,
        'rejectionReason': rejectionReason,
        'submittedAt': submittedAt.toIso8601String(),
      };

  factory LiveHostApplicationModel.fromJson(Map<String, dynamic> json) => LiveHostApplicationModel(
        id: json['id'] ?? '',
        userId: json['userId'] ?? '',
        legalName: json['legalName'] ?? '',
        displayName: json['displayName'] ?? '',
        dateOfBirth: json['dateOfBirth'] ?? '',
        gender: json['gender'] ?? '',
        country: json['country'] ?? '',
        city: json['city'] ?? '',
        languages: json['languages'] ?? '',
        category: json['category'] ?? 'Music',
        schedule: json['schedule'] ?? '',
        phoneOrEmail: json['phoneOrEmail'] ?? '',
        govIdType: json['govIdType'] ?? 'National ID',
        govIdNumber: json['govIdNumber'] ?? '',
        frontIdUrl: json['frontIdUrl'] ?? '',
        backIdUrl: json['backIdUrl'] ?? '',
        selfieUrl: json['selfieUrl'] ?? '',
        status: json['status'] ?? 'Submitted',
        rejectionReason: json['rejectionReason'],
        submittedAt: json['submittedAt'] != null ? DateTime.parse(json['submittedAt']) : DateTime.now(),
      );
}
