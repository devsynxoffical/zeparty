enum SellerStatus { pending, approved, suspended }
enum SellerType { official, verified, standard }

class UserCountryInfo {
  final String code;
  final String name;
  final String flag;
  final String label;

  const UserCountryInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.label,
  });

  factory UserCountryInfo.fromJson(Map<String, dynamic> json) {
    final flag = (json['flag'] ?? '').toString();
    final name = (json['name'] ?? '').toString();
    final label = (json['label'] ?? (flag.isNotEmpty && name.isNotEmpty ? '$flag $name' : name)).toString();
    return UserCountryInfo(
      code: (json['code'] ?? '').toString(),
      name: name,
      flag: flag,
      label: label,
    );
  }
}

class CoinSellerModel {
  final String id;
  final String userId;
  final String publicUserId;
  final String name;
  final String nickname;
  final String avatarUrl;
  final String profileImage;
  final String region;
  final String countryFlag;
  final String countryName;
  final String countryLabel;
  final SellerType type;
  final SellerStatus status;
  final bool isVisible;
  final List<String> paymentMethods;
  final int stockCoins;

  const CoinSellerModel({
    required this.id,
    required this.userId,
    this.publicUserId = '',
    required this.name,
    this.nickname = '',
    required this.avatarUrl,
    this.profileImage = '',
    required this.region,
    this.countryFlag = '',
    this.countryName = '',
    this.countryLabel = '',
    required this.type,
    required this.status,
    required this.isVisible,
    required this.paymentMethods,
    required this.stockCoins,
  });

  String get effectiveName => nickname.isNotEmpty ? nickname : name;
  String get effectiveAvatar => profileImage.isNotEmpty ? profileImage : avatarUrl;
  String get effectivePublicId => publicUserId.isNotEmpty ? publicUserId : userId;

  CoinSellerModel copyWith({
    String? id,
    String? userId,
    String? publicUserId,
    String? name,
    String? nickname,
    String? avatarUrl,
    String? profileImage,
    String? region,
    String? countryFlag,
    String? countryName,
    String? countryLabel,
    SellerType? type,
    SellerStatus? status,
    bool? isVisible,
    List<String>? paymentMethods,
    int? stockCoins,
  }) {
    return CoinSellerModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      publicUserId: publicUserId ?? this.publicUserId,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      profileImage: profileImage ?? this.profileImage,
      region: region ?? this.region,
      countryFlag: countryFlag ?? this.countryFlag,
      countryName: countryName ?? this.countryName,
      countryLabel: countryLabel ?? this.countryLabel,
      type: type ?? this.type,
      status: status ?? this.status,
      isVisible: isVisible ?? this.isVisible,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      stockCoins: stockCoins ?? this.stockCoins,
    );
  }

  factory CoinSellerModel.fromJson(Map<String, dynamic> json) {
    SellerStatus status = SellerStatus.pending;
    final sStr = (json['status'] ?? json['sellerStatus'] ?? '').toString().toLowerCase();
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

    final pId = (json['publicUserId'] ?? json['publicId'] ?? json['user']?['publicUserId'] ?? json['user']?['publicId'] ?? json['userId'] ?? '').toString();
    final nick = (json['nickname'] ?? json['displayName'] ?? json['name'] ?? json['user']?['nickname'] ?? json['user']?['displayName'] ?? json['user']?['username'] ?? 'Coin Seller').toString();
    final pImg = (json['profileImage'] ?? json['avatarUrl'] ?? json['user']?['profileImage'] ?? json['user']?['avatarUrl'] ?? '').toString();
    final cFlag = (json['countryFlag'] ?? json['userCountry']?['flag'] ?? json['user']?['countryFlag'] ?? '').toString();
    final cName = (json['countryName'] ?? json['countryLabel'] ?? json['region'] ?? '').toString();
    final cLabel = (json['countryLabel'] ?? json['countryName'] ?? json['region'] ?? '').toString();

    final rawStock = json['stockCoins'] ?? json['balanceCoins'] ?? json['resellerBalanceCoins'] ?? 0;
    final parsedStock = int.tryParse(rawStock.toString()) ?? 0;

    return CoinSellerModel(
      id: (json['id'] ?? json['sellerId'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user']?['id'] ?? '').toString(),
      publicUserId: pId,
      name: (json['name'] ?? nick).toString(),
      nickname: nick,
      avatarUrl: (json['avatarUrl'] ?? pImg).toString(),
      profileImage: pImg,
      region: (json['region'] ?? json['countryName'] ?? json['country'] ?? json['assignedCountry'] ?? '').toString(),
      countryFlag: cFlag,
      countryName: cName,
      countryLabel: cLabel,
      type: type,
      status: status,
      isVisible: json['isVisible'] ?? true,
      paymentMethods: payments,
      stockCoins: parsedStock,
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
