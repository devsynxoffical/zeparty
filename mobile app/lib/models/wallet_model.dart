class WalletModel {
  final String id;
  final String userId;
  final int coinBalance;
  final int diamondBalance;
  final int sellerBalanceCoins;
  final int lockedCoins;
  final int version;
  final DateTime? updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    this.coinBalance = 0,
    this.diamondBalance = 0,
    this.sellerBalanceCoins = 0,
    this.lockedCoins = 0,
    this.version = 1,
    this.updatedAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      coinBalance: int.tryParse(json['coinBalance']?.toString() ?? '') ?? 0,
      diamondBalance: int.tryParse(json['diamondBalance']?.toString() ?? '') ?? 0,
      sellerBalanceCoins: int.tryParse(json['sellerBalanceCoins']?.toString() ?? '') ?? 0,
      lockedCoins: int.tryParse(json['lockedCoins']?.toString() ?? '') ?? 0,
      version: json['version'] is int ? json['version'] as int : 1,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'coinBalance': coinBalance,
      'diamondBalance': diamondBalance,
      'sellerBalanceCoins': sellerBalanceCoins,
      'lockedCoins': lockedCoins,
      'version': version,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  WalletModel copyWith({
    String? id,
    String? userId,
    int? coinBalance,
    int? diamondBalance,
    int? sellerBalanceCoins,
    int? lockedCoins,
    int? version,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      coinBalance: coinBalance ?? this.coinBalance,
      diamondBalance: diamondBalance ?? this.diamondBalance,
      sellerBalanceCoins: sellerBalanceCoins ?? this.sellerBalanceCoins,
      lockedCoins: lockedCoins ?? this.lockedCoins,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
