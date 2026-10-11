class BannerItemModel {
  final String id;
  final String? title;        // Nullable - if null, render clean artwork without text overlay
  final String? subtitle;     // Nullable
  final String? customText;   // Nullable
  final String imageUrl;      // Primary banner artwork
  final String? destinationUrl;
  final String placement;
  final String targetType;
  final String? countries;
  final int position;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const BannerItemModel({
    required this.id,
    this.title,
    this.subtitle,
    this.customText,
    required this.imageUrl,
    this.destinationUrl,
    this.placement = 'HOME_CAROUSEL',
    this.targetType = 'GLOBAL',
    this.countries,
    this.position = 0,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  factory BannerItemModel.fromJson(Map<String, dynamic> json) {
    return BannerItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString(),
      subtitle: json['subtitle']?.toString(),
      customText: json['customText']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image']?.toString() ?? '',
      destinationUrl: json['destinationUrl']?.toString() ?? json['linkUrl']?.toString() ?? json['action']?.toString(),
      placement: json['placement']?.toString() ?? 'HOME_CAROUSEL',
      targetType: json['targetType']?.toString() ?? 'GLOBAL',
      countries: json['countries']?.toString(),
      position: json['position'] is int
          ? json['position'] as int
          : (int.tryParse(json['priority']?.toString() ?? '0') ?? 0),
      isActive: json['isActive'] == true || (json['status']?.toString().toUpperCase() == 'ACTIVE'),
      startsAt: json['startsAt'] != null ? DateTime.tryParse(json['startsAt'].toString()) : null,
      endsAt: json['endsAt'] != null ? DateTime.tryParse(json['endsAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'customText': customText,
      'imageUrl': imageUrl,
      'destinationUrl': destinationUrl,
      'placement': placement,
      'targetType': targetType,
      'countries': countries,
      'position': position,
      'isActive': isActive,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
    };
  }
}

