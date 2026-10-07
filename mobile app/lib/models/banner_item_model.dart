class BannerItemModel {
  final String id;
  final String title;
  final String imageUrl;
  final String? destinationUrl;
  final int position;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const BannerItemModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.destinationUrl,
    this.position = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  factory BannerItemModel.fromJson(Map<String, dynamic> json) {
    return BannerItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      destinationUrl: json['destinationUrl']?.toString() ?? json['linkUrl']?.toString() ?? json['action']?.toString(),
      position: json['position'] is int ? json['position'] : (int.tryParse(json['priority']?.toString() ?? '0') ?? 0),
      isActive: json['isActive'] is bool ? json['isActive'] : (json['status']?.toString().toUpperCase() != 'INACTIVE'),
      startsAt: json['startsAt'] != null ? DateTime.tryParse(json['startsAt'].toString()) : null,
      endsAt: json['endsAt'] != null ? DateTime.tryParse(json['endsAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'imageUrl': imageUrl,
      'destinationUrl': destinationUrl,
      'position': position,
      'isActive': isActive,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
    };
  }
}
