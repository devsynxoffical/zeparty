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

  factory MerchantModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic> ? json['user'] as Map<String, dynamic> : null;
    final wallet = user?['wallet'] is Map<String, dynamic> ? user!['wallet'] as Map<String, dynamic> : null;
    final available = int.tryParse(wallet?['sellerBalanceCoins']?.toString() ?? wallet?['coinBalance']?.toString() ?? json['availableCoins']?.toString() ?? '0') ?? 0;
    final quota = int.tryParse(json['monthlyQuotaCoins']?.toString() ?? json['dailyLimit']?.toString() ?? '0') ?? 0;
    return MerchantModel(
      id: json['id']?.toString() ?? '',
      name: json['companyName']?.toString() ?? json['name']?.toString() ?? 'Merchant Center',
      userId: json['userId']?.toString() ?? user?['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      countryCode: json['countryCode']?.toString() ?? user?['countryCode']?.toString() ?? 'GLOBAL',
      availableCoins: available,
      pendingCoins: int.tryParse(json['pendingCoins']?.toString() ?? '0') ?? 0,
      totalCoinsDistributed: int.tryParse(json['totalCoinsDistributed']?.toString() ?? '0') ?? 0,
      todaysTotalCoins: int.tryParse(json['todaysTotalCoins']?.toString() ?? '0') ?? 0,
      userRechargeTotal: int.tryParse(json['userRechargeTotal']?.toString() ?? '0') ?? 0,
      sellerRechargeTotal: int.tryParse(json['sellerRechargeTotal']?.toString() ?? '0') ?? 0,
      dailyLimit: quota,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'userId': userId,
      'status': status,
      'countryCode': countryCode,
      'availableCoins': availableCoins,
      'pendingCoins': pendingCoins,
      'totalCoinsDistributed': totalCoinsDistributed,
      'todaysTotalCoins': todaysTotalCoins,
      'userRechargeTotal': userRechargeTotal,
      'sellerRechargeTotal': sellerRechargeTotal,
      'dailyLimit': dailyLimit,
    };
  }

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

  factory MerchantTransactionModel.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : null;
    return MerchantTransactionModel(
      transactionId: json['id']?.toString() ?? json['transactionId']?.toString() ?? '',
      merchantId: metadata?['merchantId']?.toString() ?? json['merchantId']?.toString() ?? '',
      recipientType: json['recipientType']?.toString() ?? (metadata?['recipientUsername'] != null ? 'User Recharge' : 'Recharge Transfer'),
      recipientId: metadata?['recipientId']?.toString() ?? json['recipientId']?.toString() ?? '',
      recipientName: metadata?['recipientUsername']?.toString() ?? json['recipientName']?.toString() ?? 'User',
      coinAmount: (int.tryParse(json['coinDelta']?.toString() ?? json['coinAmount']?.toString() ?? '0') ?? 0).abs(),
      feeOrBonus: int.tryParse(json['feeOrBonus']?.toString() ?? '0') ?? 0,
      merchantBalanceBefore: int.tryParse(json['balanceBefore']?['sellerBalanceCoins']?.toString() ?? json['merchantBalanceBefore']?.toString() ?? '0') ?? 0,
      merchantBalanceAfter: int.tryParse(json['balanceAfter']?['sellerBalanceCoins']?.toString() ?? json['merchantBalanceAfter']?.toString() ?? '0') ?? 0,
      destinationBalanceType: json['destinationBalanceType']?.toString() ?? 'User Wallet',
      status: json['status']?.toString() ?? 'Successful',
      timestamp: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'merchantId': merchantId,
      'recipientType': recipientType,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'coinAmount': coinAmount,
      'feeOrBonus': feeOrBonus,
      'merchantBalanceBefore': merchantBalanceBefore,
      'merchantBalanceAfter': merchantBalanceAfter,
      'destinationBalanceType': destinationBalanceType,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
