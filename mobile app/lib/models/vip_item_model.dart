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
}
