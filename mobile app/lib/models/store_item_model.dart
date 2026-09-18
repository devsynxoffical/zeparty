class StoreItemModel {
  final String id;
  final String name;
  final String categoryId;
  final String assetType;
  final String imageUrl;
  final String? assetUrl;
  final int durationDays;
  final int priceCoins;
  final bool isVipExclusive;
  final int minVipLevelRequired;
  final String roomAvailability;
  final bool isActive;

  const StoreItemModel({
    required this.id,
    required this.name,
    this.categoryId = 'General',
    this.assetType = 'AVATAR_FRAME',
    required this.imageUrl,
    this.assetUrl,
    this.durationDays = 30,
    required this.priceCoins,
    this.isVipExclusive = false,
    this.minVipLevelRequired = 0,
    this.roomAvailability = 'ALL',
    this.isActive = true,
  });

  factory StoreItemModel.fromJson(Map<String, dynamic> json) {
    final type = json['assetType'] as String? ?? 'AVATAR_FRAME';
    
    // Map backend assetType to display category
    String category = 'Frame';
    if (type.contains('VEHICLE') || type.contains('CAR')) {
      category = 'Cars';
    } else if (type.contains('FRAME')) {
      category = 'Frame';
    } else if (type.contains('BUBBLE')) {
      category = 'Bubble';
    } else if (type.contains('THEME') || type.contains('BACKGROUND')) {
      category = 'Background';
    } else if (type.contains('SPECIAL') || type.contains('CARD') || type.contains('ID')) {
      category = 'Special card';
    } else {
      category = json['categoryId'] as String? ?? 'General';
    }

    final rawPrice = json['priceCoins'];
    int parsedPrice = 0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toInt();
    } else if (rawPrice is String) {
      parsedPrice = int.tryParse(rawPrice) ?? 0;
    }

    return StoreItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Store Item',
      categoryId: category,
      assetType: type,
      imageUrl: json['iconUrl'] as String? ?? json['imageUrl'] as String? ?? '',
      assetUrl: json['assetUrl'] as String?,
      durationDays: (json['validDays'] as num?)?.toInt() ?? (json['durationDays'] as num?)?.toInt() ?? 30,
      priceCoins: parsedPrice,
      isVipExclusive: json['isVipExclusive'] as bool? ?? false,
      minVipLevelRequired: (json['minVipLevelRequired'] as num?)?.toInt() ?? 0,
      roomAvailability: json['roomAvailability'] as String? ?? 'ALL',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'assetType': assetType,
      'iconUrl': imageUrl,
      'imageUrl': imageUrl,
      'assetUrl': assetUrl,
      'validDays': durationDays,
      'durationDays': durationDays,
      'priceCoins': priceCoins,
      'isVipExclusive': isVipExclusive,
      'minVipLevelRequired': minVipLevelRequired,
      'roomAvailability': roomAvailability,
      'isActive': isActive,
    };
  }
}
