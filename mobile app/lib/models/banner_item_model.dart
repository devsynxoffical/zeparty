class BannerItemModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String contentType; // 'Promotional' or 'Event'
  final String destination; // 'event_101', 'room_202', 'profile', 'store', 'https://...'
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int priority;
  final String regionCode; // 'GLOBAL' or country code

  const BannerItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.contentType,
    required this.destination,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.priority = 1,
    this.regionCode = 'GLOBAL',
  });

  bool get isCurrentlyActive {
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'contentType': contentType,
        'destination': destination,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'isActive': isActive,
        'priority': priority,
        'regionCode': regionCode,
      };

  factory BannerItemModel.fromJson(Map<String, dynamic> json) => BannerItemModel(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        imageUrl: json['imageUrl'] ?? '',
        contentType: json['contentType'] ?? 'Promotional',
        destination: json['destination'] ?? '',
        startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : DateTime.now().subtract(const Duration(days: 1)),
        endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : DateTime.now().add(const Duration(days: 30)),
        isActive: json['isActive'] ?? true,
        priority: json['priority'] ?? 1,
        regionCode: json['regionCode'] ?? 'GLOBAL',
      );
}
