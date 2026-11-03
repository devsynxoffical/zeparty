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

  factory RelationshipCardModel.fromJson(Map<String, dynamic> json) {
    int parsedPrice = 1000;
    if (json['priceCoins'] is num) {
      parsedPrice = (json['priceCoins'] as num).toInt();
    } else if (json['coinPrice'] is num) {
      parsedPrice = (json['coinPrice'] as num).toInt();
    } else if (json['priceCoins'] != null) {
      parsedPrice = int.tryParse(json['priceCoins'].toString()) ?? 1000;
    } else if (json['coinPrice'] != null) {
      parsedPrice = int.tryParse(json['coinPrice'].toString()) ?? 1000;
    }

    int parsedMax = 1;
    if (json['limit'] is num) {
      parsedMax = (json['limit'] as num).toInt();
    } else if (json['maxCount'] is num) {
      parsedMax = (json['maxCount'] as num).toInt();
    } else if (json['limit'] == 'ONLY_ONE') {
      parsedMax = 1;
    }

    String cardType = json['type']?.toString() ?? json['key']?.toString() ?? 'CP';
    if (cardType == 'CP_LOVE') cardType = 'CP';

    return RelationshipCardModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Relationship Card',
      type: cardType,
      imageUrl: json['imageUrl']?.toString() ?? 'assets/images/cp_ring.png',
      coinPrice: parsedPrice,
      benefits: json['benefits']?.toString() ?? 'Exclusive relationship badge and privileges',
      maxCount: parsedMax,
      expiryHours: json['expiryHours'] is num ? (json['expiryHours'] as num).toInt() : 48,
      refundPolicy: json['refundPolicy']?.toString() ?? 'Full refund if declined or expired',
    );
  }
}
