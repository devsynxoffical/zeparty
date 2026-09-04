class P2POffer {
  final String id;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final String type; // 'buy' or 'sell'
  final int totalCoins;
  final int availableCoins;
  final double fiatPricePerCoin;
  final String fiatCurrency;
  final List<String> acceptedPaymentMethods;
  final int minLimit;
  final int maxLimit;
  final String status; // 'active', 'completed', 'cancelled'
  final DateTime createdAt;

  P2POffer({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.type,
    required this.totalCoins,
    required this.availableCoins,
    required this.fiatPricePerCoin,
    required this.fiatCurrency,
    required this.acceptedPaymentMethods,
    required this.minLimit,
    required this.maxLimit,
    required this.status,
    required this.createdAt,
  });

  factory P2POffer.fromJson(Map<String, dynamic> json) {
    return P2POffer(
      id: json['id'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      sellerAvatar: json['sellerAvatar'] as String,
      type: json['type'] as String,
      totalCoins: json['totalCoins'] as int,
      availableCoins: json['availableCoins'] as int,
      fiatPricePerCoin: (json['fiatPricePerCoin'] as num).toDouble(),
      fiatCurrency: json['fiatCurrency'] as String,
      acceptedPaymentMethods: List<String>.from(json['acceptedPaymentMethods']),
      minLimit: json['minLimit'] as int,
      maxLimit: json['maxLimit'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'type': type,
      'totalCoins': totalCoins,
      'availableCoins': availableCoins,
      'fiatPricePerCoin': fiatPricePerCoin,
      'fiatCurrency': fiatCurrency,
      'acceptedPaymentMethods': acceptedPaymentMethods,
      'minLimit': minLimit,
      'maxLimit': maxLimit,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
