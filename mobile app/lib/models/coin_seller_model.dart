enum SellerStatus { pending, approved, suspended }
enum SellerType { official, verified, standard }

class CoinSellerModel {
  final String id;
  final String userId;
  final String name;
  final String avatarUrl;
  final String region;
  final SellerType type;
  final SellerStatus status;
  final bool isVisible;
  final List<String> paymentMethods;
  final int stockCoins;

  const CoinSellerModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.region,
    required this.type,
    required this.status,
    required this.isVisible,
    required this.paymentMethods,
    required this.stockCoins,
  });

  CoinSellerModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? avatarUrl,
    String? region,
    SellerType? type,
    SellerStatus? status,
    bool? isVisible,
    List<String>? paymentMethods,
    int? stockCoins,
  }) {
    return CoinSellerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      region: region ?? this.region,
      type: type ?? this.type,
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      stockCoins: stockCoins ?? this.stockCoins,
    );
  }

  factory CoinSellerModel.fromJson(Map<String, dynamic> json) {
    SellerStatus status = SellerStatus.pending;
    final sStr = (json['status'] ?? '').toString().toLowerCase();
    if (sStr == 'approved' || sStr == 'active') {
      status = SellerStatus.approved;
    } else if (sStr == 'suspended' || sStr == 'deactivated') {
      status = SellerStatus.suspended;
    }

    SellerType type = SellerType.standard;
    final tStr = (json['type'] ?? '').toString().toLowerCase();
    if (tStr == 'official') {
      type = SellerType.official;
    } else if (tStr == 'verified') {
      type = SellerType.verified;
    }

    List<String> payments = [];
    if (json['paymentMethods'] is List) {
      payments = (json['paymentMethods'] as List).map((e) => e.toString()).toList();
    } else if (json['supportedPaymentMethods'] is List) {
      payments = (json['supportedPaymentMethods'] as List).map((e) => e.toString()).toList();
    }

    return CoinSellerModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user']?['id'] ?? '').toString(),
      name: (json['name'] ?? json['user']?['username'] ?? json['user']?['name'] ?? 'Coin Seller').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['user']?['avatarUrl'] ?? '').toString(),
      region: (json['region'] ?? json['country'] ?? json['assignedCountry'] ?? '').toString(),
      type: type,
      status: status,
      isVisible: json['isVisible'] ?? true,
      paymentMethods: payments,
      stockCoins: json['stockCoins'] ?? json['balanceCoins'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'avatarUrl': avatarUrl,
      'region': region,
      'type': type.name,
      'status': status.name,
      'isVisible': isVisible,
      'paymentMethods': paymentMethods,
      'stockCoins': stockCoins,
    };
  }
}
