import 'store_item_model.dart';

class VipItemModel {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String category; // Avatar Frame, Entry Effect, Badge, Crown, Username Color
  final int coinPrice;
  final String validityPeriod; // 30 Days, Permanent
  final bool isOwned;

  const VipItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
    required this.coinPrice,
    this.validityPeriod = '30 Days',
    this.isOwned = false,
  });

  factory VipItemModel.fromStoreItem(StoreItemModel item, {bool isOwned = false}) {
    String iconString = '👑';
    final type = item.assetType.toUpperCase();
    if (type.contains('CAR') || type.contains('VEHICLE')) {
      iconString = '🏎️';
    } else if (type.contains('BUBBLE')) {
      iconString = '💬';
    } else if (type.contains('EFFECT')) {
      iconString = '✨';
    } else if (type.contains('BADGE')) {
      iconString = '🛡️';
    }

    return VipItemModel(
      id: item.id,
      title: item.name,
      description: '${item.durationDays} Days VIP Privilege.',
      icon: iconString,
      category: item.categoryId,
      coinPrice: item.priceCoins,
      validityPeriod: '${item.durationDays} Days',
      isOwned: isOwned,
    );
  }
}
