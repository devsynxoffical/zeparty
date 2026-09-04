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
}
