class WalletBalance {
  const WalletBalance({required this.walletId, required this.balance, required this.currencyType});
  final String walletId;
  final int balance;
  final String currencyType;
  factory WalletBalance.fromJson(Map<String, dynamic> j) => WalletBalance(walletId: j['walletId'] as String, balance: (j['balance'] as num).toInt(), currencyType: j['currencyType'] as String);
}

class WalletTransaction {
  const WalletTransaction({required this.transactionId, required this.type, required this.amount, required this.balanceAfter, required this.referenceId, required this.createdAt, required this.metadata});
  final String transactionId;
  final String type;
  final int amount;
  final int balanceAfter;
  final String? referenceId;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;
  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
        transactionId: j['transactionId'] as String,
        type: j['transactionType'] as String,
        amount: (j['amount'] as num).toInt(),
        balanceAfter: (j['balanceAfter'] as num).toInt(),
        referenceId: j['referenceId'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        metadata: (j['metadata'] as Map<String, dynamic>?) ?? const {},
      );

  String get label => switch (type) {
        'reward_match' => metadata['kind'] == 'win' ? 'Match win reward' : 'Match participation',
        'reward_achievement' => 'Achievement reward',
        'reward_daily' => 'Daily reward',
        'reward_tutorial' => 'Tutorial reward',
        'reward_promo' => 'Promotion',
        'purchase_cosmetic' => 'Cosmetic purchase',
        'admin_adjust' => 'Adjustment',
        _ => type,
      };
}

class Cosmetic {
  const Cosmetic({required this.cosmeticId, required this.gameId, required this.category, required this.name, required this.description, required this.price, required this.previewAsset, required this.enabled});
  final String cosmeticId;
  final String gameId;
  final String category;
  final String name;
  final String description;
  final int price;
  final String? previewAsset;
  final bool enabled;
  factory Cosmetic.fromJson(Map<String, dynamic> j) => Cosmetic(
        cosmeticId: j['cosmeticId'] as String,
        gameId: j['gameId'] as String,
        category: j['category'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        price: (j['price'] as num).toInt(),
        previewAsset: j['previewAsset'] as String?,
        enabled: j['enabled'] as bool? ?? true,
      );
  bool get isFree => price == 0;
}

class Achievement {
  const Achievement({required this.id, required this.gameId, required this.name, required this.description, required this.rewardCoins, required this.unlockedAt, required this.claimedAt});
  final String id;
  final String gameId;
  final String name;
  final String description;
  final int rewardCoins;
  final DateTime? unlockedAt;
  final DateTime? claimedAt;
  bool get unlocked => unlockedAt != null;
  bool get claimable => unlocked && claimedAt == null && rewardCoins > 0;
  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        id: j['achievementId'] as String,
        gameId: j['gameId'] as String,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        rewardCoins: (j['rewardCoins'] as num).toInt(),
        unlockedAt: j['unlockedAt'] == null ? null : DateTime.parse(j['unlockedAt'] as String),
        claimedAt: j['claimedAt'] == null ? null : DateTime.parse(j['claimedAt'] as String),
      );
}
