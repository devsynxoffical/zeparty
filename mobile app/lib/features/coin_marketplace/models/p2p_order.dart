class P2POrder {
  final String id;
  final String offerId;
  final String buyerId;
  final String buyerName;
  final String buyerAvatar;
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final int coins;
  final double fiatAmount;
  final String fiatCurrency;
  final String paymentMethod;
  final String status; // 'pending', 'paid', 'released', 'cancelled', 'disputed'
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? completedAt;

  P2POrder({
    required this.id,
    required this.offerId,
    required this.buyerId,
    required this.buyerName,
    required this.buyerAvatar,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.coins,
    required this.fiatAmount,
    required this.fiatCurrency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.completedAt,
  });

  factory P2POrder.fromJson(Map<String, dynamic> json) {
    return P2POrder(
      id: json['id'] as String,
      offerId: json['offerId'] as String,
      buyerId: json['buyerId'] as String,
      buyerName: json['buyerName'] as String,
      buyerAvatar: json['buyerAvatar'] as String,
      sellerId: json['sellerId'] as String,
      sellerName: json['sellerName'] as String,
      sellerAvatar: json['sellerAvatar'] as String,
      coins: json['coins'] as int,
      fiatAmount: (json['fiatAmount'] as num).toDouble(),
      fiatCurrency: json['fiatCurrency'] as String,
      paymentMethod: json['paymentMethod'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'offerId': offerId,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'buyerAvatar': buyerAvatar,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'coins': coins,
      'fiatAmount': fiatAmount,
      'fiatCurrency': fiatCurrency,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
