class AgencyModel {
  final String id;
  final String name;
  final String logoUrl;
  final String description;
  final String ownerUserId;
  final String ownerName;
  final String status; // 'Active', 'Pending', 'Suspended', 'Closed'
  final int totalHosts;
  final int totalMembers;
  final String cycle15DayId;
  final double pendingBalanceUsd;
  final double availableBalanceUsd;
  final String countryCode;
  final DateTime createdAt;

  const AgencyModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.description,
    required this.ownerUserId,
    required this.ownerName,
    this.status = 'Active',
    this.totalHosts = 0,
    this.totalMembers = 0,
    required this.cycle15DayId,
    this.pendingBalanceUsd = 0.0,
    this.availableBalanceUsd = 0.0,
    this.countryCode = 'GLOBAL',
    required this.createdAt,
  });

  AgencyModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? description,
    String? ownerUserId,
    String? ownerName,
    String? status,
    int? totalHosts,
    int? totalMembers,
    String? cycle15DayId,
    double? pendingBalanceUsd,
    double? availableBalanceUsd,
    String? countryCode,
    DateTime? createdAt,
  }) {
    return AgencyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      description: description ?? this.description,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerName: ownerName ?? this.ownerName,
      status: status ?? this.status,
      totalHosts: totalHosts ?? this.totalHosts,
      totalMembers: totalMembers ?? this.totalMembers,
      cycle15DayId: cycle15DayId ?? this.cycle15DayId,
      pendingBalanceUsd: pendingBalanceUsd ?? this.pendingBalanceUsd,
      availableBalanceUsd: availableBalanceUsd ?? this.availableBalanceUsd,
      countryCode: countryCode ?? this.countryCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logoUrl': logoUrl,
        'description': description,
        'ownerUserId': ownerUserId,
        'ownerName': ownerName,
        'status': status,
        'totalHosts': totalHosts,
        'totalMembers': totalMembers,
        'cycle15DayId': cycle15DayId,
        'pendingBalanceUsd': pendingBalanceUsd,
        'availableBalanceUsd': availableBalanceUsd,
        'countryCode': countryCode,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AgencyModel.fromJson(Map<String, dynamic> json) => AgencyModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        logoUrl: json['logoUrl'] ?? '',
        description: json['description'] ?? '',
        ownerUserId: json['ownerUserId'] ?? '',
        ownerName: json['ownerName'] ?? '',
        status: json['status'] ?? 'Active',
        totalHosts: json['totalHosts'] ?? 0,
        totalMembers: json['totalMembers'] ?? 0,
        cycle15DayId: json['cycle15DayId'] ?? '',
        pendingBalanceUsd: (json['pendingBalanceUsd'] ?? 0).toDouble(),
        availableBalanceUsd: (json['availableBalanceUsd'] ?? 0).toDouble(),
        countryCode: json['countryCode'] ?? 'GLOBAL',
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}
