class RechargePlanModel {
  final String id;
  final String name;
  final int coinAmount;
  final double priceUSD;
  final int bonusCoins;
  final String badgeText;
  final bool isActive;
  final bool isRecommended;

  const RechargePlanModel({
    required this.id,
    required this.name,
    required this.coinAmount,
    required this.priceUSD,
    this.bonusCoins = 0,
    this.badgeText = '',
    this.isActive = true,
    this.isRecommended = false,
  });

  factory RechargePlanModel.fromJson(Map<String, dynamic> json) {
    final coins = int.tryParse(json['coinAmount']?.toString() ?? '') ?? 0;
    final bonus = int.tryParse(json['bonusCoins']?.toString() ?? '') ?? 0;
    final price = double.tryParse(json['priceUSD']?.toString() ?? '') ?? 0.0;
    final badge = json['badgeText']?.toString() ?? (json['badge']?.toString() ?? '');
    final name = json['name']?.toString() ?? '$coins Coins Pack';

    return RechargePlanModel(
      id: json['id']?.toString() ?? '',
      name: name,
      coinAmount: coins,
      priceUSD: price,
      bonusCoins: bonus,
      badgeText: badge,
      isActive: json['isActive'] != false,
      isRecommended: badge.toLowerCase().contains('best') || badge.toLowerCase().contains('value') || badge.toLowerCase().contains('popular'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coinAmount': coinAmount,
      'priceUSD': priceUSD,
      'bonusCoins': bonusCoins,
      'badgeText': badgeText,
      'isActive': isActive,
    };
  }
}
