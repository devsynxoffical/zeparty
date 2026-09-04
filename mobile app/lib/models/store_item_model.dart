class StoreItemModel {
  final String id;
  final String categoryId;
  final String name;
  final String imageUrl;
  final int durationDays;
  final int priceCoins;

  const StoreItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.imageUrl,
    required this.durationDays,
    required this.priceCoins,
  });

  factory StoreItemModel.fromJson(Map<String, dynamic> json) {
    return StoreItemModel(
      id: json['id'] as String,
      categoryId: json['categoryId'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      durationDays: json['durationDays'] as int,
      priceCoins: json['priceCoins'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'imageUrl': imageUrl,
      'durationDays': durationDays,
      'priceCoins': priceCoins,
    };
  }
}
