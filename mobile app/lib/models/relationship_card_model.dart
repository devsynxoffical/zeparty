class RelationshipCardModel {
  final String id;
  final String name;
  final String type; // 'CP', 'Best Friend', 'Bro/Sis', 'Game Friend', 'Good Friend'
  final String imageUrl;
  final int coinPrice;
  final String benefits;
  final int maxCount; // e.g., 1 for CP, 5 for Best Friend
  final int expiryHours; // invitation expiry
  final String refundPolicy;

  const RelationshipCardModel({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.coinPrice,
    required this.benefits,
    this.maxCount = 1,
    this.expiryHours = 48,
    this.refundPolicy = 'Full refund if declined or expired',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'imageUrl': imageUrl,
        'coinPrice': coinPrice,
        'benefits': benefits,
        'maxCount': maxCount,
        'expiryHours': expiryHours,
        'refundPolicy': refundPolicy,
      };

  factory RelationshipCardModel.fromJson(Map<String, dynamic> json) => RelationshipCardModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        type: json['type'] ?? 'CP',
        imageUrl: json['imageUrl'] ?? '',
        coinPrice: json['coinPrice'] ?? 1000,
        benefits: json['benefits'] ?? '',
        maxCount: json['maxCount'] ?? 1,
        expiryHours: json['expiryHours'] ?? 48,
        refundPolicy: json['refundPolicy'] ?? 'Full refund if declined or expired',
      );
}
