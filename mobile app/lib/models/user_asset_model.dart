import 'store_item_model.dart';

class UserAssetModel {
  final String id;
  final String userId;
  final String assetId;
  final bool isEquipped;
  final DateTime expiresAt;
  final bool isExpired;
  final StoreItemModel? asset;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserAssetModel({
    required this.id,
    required this.userId,
    required this.assetId,
    this.isEquipped = false,
    required this.expiresAt,
    this.isExpired = false,
    this.asset,
    this.createdAt,
    this.updatedAt,
  });

  factory UserAssetModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedExpiresAt = DateTime.now().add(const Duration(days: 30));
    if (json['expiresAt'] != null) {
      parsedExpiresAt = DateTime.tryParse(json['expiresAt'] as String) ?? parsedExpiresAt;
    }

    return UserAssetModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      assetId: json['assetId'] as String? ?? '',
      isEquipped: json['isEquipped'] as bool? ?? false,
      expiresAt: parsedExpiresAt,
      isExpired: json['isExpired'] as bool? ?? (parsedExpiresAt.isBefore(DateTime.now())),
      asset: json['asset'] != null && json['asset'] is Map<String, dynamic>
          ? StoreItemModel.fromJson(json['asset'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'assetId': assetId,
      'isEquipped': isEquipped,
      'expiresAt': expiresAt.toIso8601String(),
      'isExpired': isExpired,
      'asset': asset?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserAssetModel copyWith({
    String? id,
    String? userId,
    String? assetId,
    bool? isEquipped,
    DateTime? expiresAt,
    bool? isExpired,
    StoreItemModel? asset,
  }) {
    return UserAssetModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      assetId: assetId ?? this.assetId,
      isEquipped: isEquipped ?? this.isEquipped,
      expiresAt: expiresAt ?? this.expiresAt,
      isExpired: isExpired ?? this.isExpired,
      asset: asset ?? this.asset,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
