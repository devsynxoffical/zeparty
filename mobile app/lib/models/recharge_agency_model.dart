class SavedCustomerModel {
  final String id;
  final String sellerId;
  final String linkedUserId;
  final String recipientName;
  final String label;
  final String contactNumber;
  final DateTime createdAt;

  const SavedCustomerModel({
    required this.id,
    required this.sellerId,
    required this.linkedUserId,
    required this.recipientName,
    required this.label,
    required this.contactNumber,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sellerId': sellerId,
        'linkedUserId': linkedUserId,
        'recipientName': recipientName,
        'label': label,
        'contactNumber': contactNumber,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedCustomerModel.fromJson(Map<String, dynamic> json) => SavedCustomerModel(
        id: json['id'] ?? '',
        sellerId: json['sellerId'] ?? '',
        linkedUserId: json['linkedUserId'] ?? '',
        recipientName: json['recipientName'] ?? '',
        label: json['label'] ?? '',
        contactNumber: json['contactNumber'] ?? '',
        createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      );
}

class SellerRechargeTransactionModel {
  final String transactionId;
  final String sellerId;
  final String sellerName;
  final String recipientUserId;
  final String recipientName;
  final String recipientAvatarUrl;
  final int coins;
  final int feeOrBonus;
  final int sellerBalanceBefore;
  final int sellerBalanceAfter;
  final String status; // 'Successful', 'Pending', 'Failed', 'Rejected', 'Reversed'
  final String countryCode;
  final DateTime timestamp;

  const SellerRechargeTransactionModel({
    required this.transactionId,
    required this.sellerId,
    required this.sellerName,
    required this.recipientUserId,
    required this.recipientName,
    required this.recipientAvatarUrl,
    required this.coins,
    required this.feeOrBonus,
    required this.sellerBalanceBefore,
    required this.sellerBalanceAfter,
    this.status = 'Successful',
    required this.countryCode,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'sellerId': sellerId,
        'sellerName': sellerName,
        'recipientUserId': recipientUserId,
        'recipientName': recipientName,
        'recipientAvatarUrl': recipientAvatarUrl,
        'coins': coins,
        'feeOrBonus': feeOrBonus,
        'sellerBalanceBefore': sellerBalanceBefore,
        'sellerBalanceAfter': sellerBalanceAfter,
        'status': status,
        'countryCode': countryCode,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SellerRechargeTransactionModel.fromJson(Map<String, dynamic> json) => SellerRechargeTransactionModel(
        transactionId: json['transactionId'] ?? '',
        sellerId: json['sellerId'] ?? '',
        sellerName: json['sellerName'] ?? '',
        recipientUserId: json['recipientUserId'] ?? '',
        recipientName: json['recipientName'] ?? '',
        recipientAvatarUrl: json['recipientAvatarUrl'] ?? '',
        coins: json['coins'] ?? 0,
        feeOrBonus: json['feeOrBonus'] ?? 0,
        sellerBalanceBefore: json['sellerBalanceBefore'] ?? 0,
        sellerBalanceAfter: json['sellerBalanceAfter'] ?? 0,
        status: json['status'] ?? 'Successful',
        countryCode: json['countryCode'] ?? 'GLOBAL',
        timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      );
}
