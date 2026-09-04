class LuckyMultiplierTier {
  final int multiplier; // e.g. 2, 5, 10, 50, 100
  final double probability; // e.g. 0.50, 0.30, 0.15, 0.04, 0.01
  final String label;

  const LuckyMultiplierTier({
    required this.multiplier,
    required this.probability,
    required this.label,
  });
}

class LuckyGiftModel {
  final String id;
  final String name;
  final String icon;
  final String animationUrl;
  final int coinPrice;
  final String badge; // 'NEW', 'LIMITED', 'JACKPOT'
  final int maxMultiplier;
  final List<LuckyMultiplierTier> rewardTable;
  final bool isActive;

  const LuckyGiftModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.animationUrl,
    required this.coinPrice,
    this.badge = 'JACKPOT',
    this.maxMultiplier = 100,
    required this.rewardTable,
    this.isActive = true,
  });
}

class LuckyGiftResultModel {
  final String transactionId;
  final String giftId;
  final String giftName;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final int quantity;
  final int totalCostCoins;
  final int multiplierWon;
  final int coinsWon;
  final DateTime timestamp;

  const LuckyGiftResultModel({
    required this.transactionId,
    required this.giftId,
    required this.giftName,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.quantity,
    required this.totalCostCoins,
    required this.multiplierWon,
    required this.coinsWon,
    required this.timestamp,
  });
}
