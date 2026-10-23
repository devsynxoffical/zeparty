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

  String get id => transactionId;
  String get referenceId => transactionId;
  int get amountCoins => coins;
  String get recipientPublicId => recipientUserId;
  DateTime get createdAt => timestamp;

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

  factory SellerRechargeTransactionModel.fromJson(Map<String, dynamic> json) {
    final ref = (json['referenceId'] ?? json['transactionId'] ?? json['id'] ?? '').toString();
    final recipientObj = json['recipient'] is Map<String, dynamic> ? json['recipient'] as Map<String, dynamic> : null;

    final rId = (json['recipientPublicUserId'] ??
            json['recipientPublicId'] ??
            json['recipientUserId'] ??
            recipientObj?['publicUserId'] ??
            recipientObj?['accountId'] ??
            json['recipientAccountId'] ??
            '')
        .toString();

    final rName = (json['recipientName'] ??
            json['recipientNickname'] ??
            recipientObj?['nickname'] ??
            recipientObj?['displayName'] ??
            'ZeParty User')
        .toString();

    final rAvatar = (json['recipientAvatarUrl'] ??
            json['recipientProfileImage'] ??
            recipientObj?['profileImage'] ??
            recipientObj?['avatarUrl'] ??
            '')
        .toString();

    final rawCoins = json['coins'] ?? json['amountCoins'] ?? json['transferAmount'] ?? json['amount'] ?? 0;
    final coins = rawCoins is int ? rawCoins : int.tryParse(rawCoins.toString()) ?? 0;

    final before = int.tryParse(json['sellerBalanceBefore']?.toString() ?? '0') ?? 0;
    final after = int.tryParse(json['sellerBalanceAfter']?.toString() ??
            json['remainingSellerBalanceCoins']?.toString() ??
            json['availableBalanceCoins']?.toString() ??
            '0') ??
        0;

    final dateStr = json['createdAt']?.toString() ?? json['timestamp']?.toString();
    final dt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    return SellerRechargeTransactionModel(
      transactionId: ref,
      sellerId: (json['sellerId'] ?? '').toString(),
      sellerName: (json['sellerName'] ?? 'Authorized Seller').toString(),
      recipientUserId: rId,
      recipientName: rName,
      recipientAvatarUrl: rAvatar,
      coins: coins,
      feeOrBonus: int.tryParse(json['feeOrBonus']?.toString() ?? '0') ?? 0,
      sellerBalanceBefore: before,
      sellerBalanceAfter: after,
      status: (json['status'] ?? 'Successful').toString(),
      countryCode: (json['countryCode'] ?? 'GLOBAL').toString(),
      timestamp: dt,
    );
  }
}

class SellerRechargeResult {
  final bool success;
  final String transactionId;
  final String referenceId;
  final int coins;
  final int remainingSellerBalanceCoins;
  final int todayRechargedCoins;
  final String status;
  final String? message;
  final String recipientName;
  final String recipientPublicId;
  final String creditedTo;
  final int recipientNewBalance;

  const SellerRechargeResult({
    required this.success,
    required this.transactionId,
    required this.referenceId,
    required this.coins,
    required this.remainingSellerBalanceCoins,
    required this.todayRechargedCoins,
    this.status = 'Successful',
    this.message,
    this.recipientName = '',
    this.recipientPublicId = '',
    this.creditedTo = '',
    this.recipientNewBalance = 0,
  });

  int get amountCoins => coins;
  int get sellerNewBalance => remainingSellerBalanceCoins;

  factory SellerRechargeResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    final ref = (data['referenceId'] ?? data['transactionId'] ?? '').toString();
    final rawCoins = data['transferAmount'] ?? data['amountCoins'] ?? data['coins'] ?? data['rechargedCoins'] ?? 0;
    final coins = rawCoins is int ? rawCoins : int.tryParse(rawCoins.toString()) ?? 0;

    final remaining = int.tryParse(
            data['sellerNewBalance']?.toString() ??
            data['remainingSellerBalanceCoins']?.toString() ??
            data['availableBalanceCoins']?.toString() ??
            '0') ??
        0;
    final today = int.tryParse(
            data['todayRechargedCoins']?.toString() ?? data['todayRecharged']?.toString() ?? '0') ??
        0;

    final rec = data['recipient'] is Map<String, dynamic> ? data['recipient'] as Map<String, dynamic> : null;
    final recipientBal = int.tryParse(data['recipientNewBalance']?.toString() ?? '0') ?? 0;

    return SellerRechargeResult(
      success: json['success'] == true || data['success'] == true || data['status'] == 'Successful' || data['status'] == 'COMPLETED',
      transactionId: ref,
      referenceId: ref,
      coins: coins,
      remainingSellerBalanceCoins: remaining,
      todayRechargedCoins: today,
      status: (data['status'] ?? 'Successful').toString(),
      message: (json['message'] ?? data['message'])?.toString(),
      recipientName: (data['recipientName'] ?? data['recipientNickname'] ?? rec?['nickname'] ?? '').toString(),
      recipientPublicId: (data['recipientPublicId'] ?? data['recipientPublicUserId'] ?? rec?['publicUserId'] ?? '').toString(),
      creditedTo: (data['creditedTo'] ?? data['recipientUserId'] ?? '').toString(),
      recipientNewBalance: recipientBal,
    );
  }
}


class VerifiedRecipientModel {
  final String accountId;
  final String publicUserId;
  final String nickname;
  final String? profileImage;
  final String countryCode;
  final bool isVerified;

  const VerifiedRecipientModel({
    required this.accountId,
    required this.publicUserId,
    required this.nickname,
    this.profileImage,
    this.countryCode = 'GLOBAL',
    this.isVerified = true,
  });

  factory VerifiedRecipientModel.fromJson(Map<String, dynamic> json) {
    return VerifiedRecipientModel(
      accountId: (json['accountId'] ?? json['userId'] ?? json['id'] ?? '').toString(),
      publicUserId: (json['publicUserId'] ?? json['username'] ?? json['userId'] ?? '').toString(),
      nickname: (json['nickname'] ?? json['displayName'] ?? json['name'] ?? 'ZeParty User').toString(),
      profileImage: json['profileImage']?.toString() ?? json['avatarUrl']?.toString(),
      countryCode: (json['countryCode'] ?? 'GLOBAL').toString(),
      isVerified: json['isVerified'] == true || json['isVerified'] == null,
    );
  }

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'publicUserId': publicUserId,
        'nickname': nickname,
        'profileImage': profileImage,
        'countryCode': countryCode,
        'isVerified': isVerified,
        // Backward-compatibility keys
        'userId': accountId,
        'name': nickname,
        'avatarUrl': profileImage ?? '',
        'status': isVerified ? 'Active' : 'Unverified',
      };

  dynamic operator [](String key) {
    switch (key) {
      case 'accountId':
      case 'userId':
      case 'id':
        return accountId;
      case 'publicUserId':
      case 'username':
        return publicUserId;
      case 'nickname':
      case 'name':
      case 'displayName':
        return nickname;
      case 'profileImage':
      case 'avatarUrl':
        return profileImage ?? '';
      case 'countryCode':
        return countryCode;
      case 'isVerified':
        return isVerified;
      case 'status':
        return isVerified ? 'Active' : 'Unverified';
      default:
        return null;
    }
  }

  bool containsKey(String key) {
    return ['accountId', 'userId', 'id', 'publicUserId', 'username', 'nickname', 'name', 'displayName', 'profileImage', 'avatarUrl', 'countryCode', 'isVerified', 'status'].contains(key);
  }
}

