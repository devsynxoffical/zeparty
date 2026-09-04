class MerchantModel {
  final String id;
  final String name;
  final String userId;
  final String status; // 'Active', 'Pending', 'Suspended', 'Expired'
  final String countryCode;
  final int availableCoins;
  final int pendingCoins;
  final int totalCoinsDistributed;
  final int todaysTotalCoins;
  final int userRechargeTotal;
  final int sellerRechargeTotal;
  final int dailyLimit;

  const MerchantModel({
    required this.id,
    required this.name,
    required this.userId,
    this.status = 'Active',
    this.countryCode = 'GLOBAL',
    this.availableCoins = 5000000,
    this.pendingCoins = 0,
    this.totalCoinsDistributed = 15000000,
    this.todaysTotalCoins = 250000,
    this.userRechargeTotal = 10000000,
    this.sellerRechargeTotal = 5000000,
    this.dailyLimit = 10000000,
  });

  MerchantModel copyWith({
    String? id,
    String? name,
    String? userId,
    String? status,
    String? countryCode,
    int? availableCoins,
    int? pendingCoins,
    int? totalCoinsDistributed,
    int? todaysTotalCoins,
    int? userRechargeTotal,
    int? sellerRechargeTotal,
    int? dailyLimit,
  }) {
    return MerchantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      countryCode: countryCode ?? this.countryCode,
      availableCoins: availableCoins ?? this.availableCoins,
      pendingCoins: pendingCoins ?? this.pendingCoins,
      totalCoinsDistributed: totalCoinsDistributed ?? this.totalCoinsDistributed,
      todaysTotalCoins: todaysTotalCoins ?? this.todaysTotalCoins,
      userRechargeTotal: userRechargeTotal ?? this.userRechargeTotal,
      sellerRechargeTotal: sellerRechargeTotal ?? this.sellerRechargeTotal,
      dailyLimit: dailyLimit ?? this.dailyLimit,
    );
  }
}

class MerchantTransactionModel {
  final String transactionId;
  final String merchantId;
  final String recipientType; // 'User Recharge' or 'Coin Seller Recharge'
  final String recipientId; // User ID or Seller ID
  final String recipientName;
  final int coinAmount;
  final int feeOrBonus;
  final int merchantBalanceBefore;
  final int merchantBalanceAfter;
  final String destinationBalanceType; // 'User Wallet' or 'Seller Recharge Operational Balance'
  final String status; // 'Successful', 'Pending', 'Failed', 'Rejected', 'Reversed'
  final DateTime timestamp;

  const MerchantTransactionModel({
    required this.transactionId,
    required this.merchantId,
    required this.recipientType,
    required this.recipientId,
    required this.recipientName,
    required this.coinAmount,
    required this.feeOrBonus,
    required this.merchantBalanceBefore,
    required this.merchantBalanceAfter,
    required this.destinationBalanceType,
    this.status = 'Successful',
    required this.timestamp,
  });
}
