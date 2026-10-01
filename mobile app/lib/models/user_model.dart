enum UserRole { user, host, seller, agency, bd, admin }

class UserModel {
  final String id;
  final String username;
  final String name;
  final String? email;
  final String? phone;
  final String avatarUrl;
  final String? coverUrl;
  final String bio;
  final String gender;
  final String region;
  final DateTime? dateOfBirth;
  final bool profileCompleted;
  final int followers;
  final int following;
  final int diamonds;
  final int coins;
  final double rCoins;
  final bool isVip;
  final String vipLevel;
  final bool isHost;
  final bool isAgency;
  final bool isSeller;
  final bool isBd;
  final String? agencyName;
  final int sellerBalance;
  final bool isOnline;
  final bool isLive;
  final String? liveRoomId;
  final String avatarFrame;
  final String badge;
  final String referralCode;
  final int referralCount;
  final UserRole role;
  
  // Host Application
  final String hostApplicationStatus; // 'none', 'pending', 'approved', 'rejected', 're_verify'
  final String? hostRejectionReason;

  // Levels
  final int wealthLevel;
  final int wealthXp;
  final int charmLevel;
  final int charmXp;
  final int gameLevel;
  final int gameXp;
  final int accountLevel;
  final int accountXp;

  // Relationship (CP)
  final String? cpPartnerId;
  final int cpPoints;
  final List<String> pendingCpRequests;

  // Noble Title (Addendum 32)
  final String? nobleTitle;
  final String status;
  final int likesReceived;
  final bool isCountryLocked;


  static const UserModel empty = UserModel(
    id: '',
    username: '',
    name: 'Guest',
    avatarUrl: '',
    bio: '',
    followers: 0,
    following: 0,
    diamonds: 0,
    coins: 0,
    rCoins: 0.0,
    isVip: false,
    vipLevel: 'None',
    isHost: false,
    isAgency: false,
    isSeller: false,
    isBd: false,
    sellerBalance: 0,
    isOnline: false,
    isLive: false,
    avatarFrame: '',
    badge: '',
    referralCode: '',
    referralCount: 0,
    role: UserRole.user,
    hostApplicationStatus: 'none',
    wealthLevel: 1,
    wealthXp: 0,
    charmLevel: 1,
    charmXp: 0,
    gameLevel: 1,
    gameXp: 0,
    accountLevel: 1,
    accountXp: 0,
    profileCompleted: false,
    likesReceived: 0,
    isCountryLocked: false,
  );

  const UserModel({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.phone,
    required this.avatarUrl,
    this.coverUrl,
    this.bio = '',
    this.gender = 'Not Specified',
    this.region = '🇵🇰 Pakistan',
    this.dateOfBirth,
    this.profileCompleted = true,
    this.followers = 0,
    this.following = 0,
    this.diamonds = 0,
    this.coins = 0,
    this.rCoins = 0.0,
    this.isVip = false,
    this.vipLevel = 'None',
    this.isHost = false,
    this.isAgency = false,
    this.isSeller = false,
    this.isBd = false,
    this.agencyName,
    this.sellerBalance = 0,
    this.isOnline = true,
    this.isLive = false,
    this.liveRoomId,
    this.avatarFrame = '',
    this.badge = '',
    this.referralCode = '',
    this.referralCount = 0,
    this.role = UserRole.user,
    this.hostApplicationStatus = 'none',
    this.hostRejectionReason,
    this.wealthLevel = 1,
    this.wealthXp = 0,
    this.charmLevel = 1,
    this.charmXp = 0,
    this.gameLevel = 1,
    this.gameXp = 0,
    this.accountLevel = 1,
    this.accountXp = 0,
    this.cpPartnerId,
    this.cpPoints = 0,
    this.pendingCpRequests = const [],
    this.nobleTitle,
    this.status = 'ACTIVE',
    this.likesReceived = 0,
    this.isCountryLocked = false,
  });

  /// Automatically calculate exact age from date of birth securely
  int get age {
    if (dateOfBirth == null) return 21; // Safe fallback when profile DOB is loading
    final today = DateTime.now();
    int calculatedAge = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month ||
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge > 0 ? calculatedAge : 0;
  }

  /// 18+ requirement for restricted live streaming features
  bool get isAgeEligible => age >= 18;

  /// Effective display name
  String get displayName {
    if (name.isNotEmpty && name != 'null' && name != 'undefined') {
      return name;
    }
    if (username.isNotEmpty && username != 'null' && username != 'undefined') {
      return username;
    }
    if (email != null && email!.contains('@')) {
      final handle = email!.split('@').first.trim();
      if (handle.isNotEmpty) {
        return handle[0].toUpperCase() + handle.substring(1);
      }
    }
    return 'ZeParty Member';
  }

  /// Effective cover image URL fallback
  String get effectiveCoverUrl => (coverUrl != null && coverUrl!.isNotEmpty) ? coverUrl! : avatarUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map<String, dynamic> ? json['profile'] as Map<String, dynamic> : {};
    final wallet = json['wallet'] is Map<String, dynamic> ? json['wallet'] as Map<String, dynamic> : {};
    final hostProfile = json['hostProfile'] is Map<String, dynamic> ? json['hostProfile'] as Map<String, dynamic> : null;

    final id = json['id']?.toString() ?? json['_id']?.toString() ?? '';
    final email = json['email']?.toString();

    final rawUsername = (json['username']?.toString() ?? '').trim();
    final rawDisplayName = (profile['displayName']?.toString() ?? '').trim();
    final rawName = (json['name']?.toString() ?? '').trim();
    final rawDisplayNameFallback = (json['displayName']?.toString() ?? '').trim();

    String username = rawUsername.isNotEmpty
        ? rawUsername
        : (email != null && email.contains('@') ? email.split('@').first.toLowerCase() : (id.isNotEmpty ? 'user_${id.substring(0, id.length > 8 ? 8 : id.length)}' : 'user'));

    String name = rawDisplayName.isNotEmpty
        ? rawDisplayName
        : (rawDisplayNameFallback.isNotEmpty
            ? rawDisplayNameFallback
            : (rawName.isNotEmpty
                ? rawName
                : (rawUsername.isNotEmpty ? rawUsername : 'ZeParty Member')));

    final phone = json['phone']?.toString();
    final avatarUrl = profile['avatarUrl']?.toString() ?? json['avatarUrl']?.toString() ?? profile['avatar']?.toString() ?? json['avatar']?.toString() ?? '';
    final bio = profile['bio']?.toString() ?? json['bio']?.toString() ?? '';
    final gender = profile['gender']?.toString() ?? json['gender']?.toString() ?? 'Not Specified';
    final region = profile['region']?.toString() ?? profile['countryCode']?.toString() ?? json['region']?.toString() ?? 'Global';
    
    DateTime? dob;
    if (json['dob'] != null) {
      dob = DateTime.tryParse(json['dob'].toString());
    } else if (profile['birthDate'] != null) {
      dob = DateTime.tryParse(profile['birthDate'].toString());
    } else if (json['dateOfBirth'] != null) {
      dob = DateTime.tryParse(json['dateOfBirth'].toString());
    }

    final coins = int.tryParse(wallet['coinBalance']?.toString() ?? '') ?? (json['coins'] is int ? json['coins'] as int : 0);
    final diamonds = int.tryParse(wallet['diamondBalance']?.toString() ?? '') ?? (json['diamonds'] is int ? json['diamonds'] as int : 0);
    final sellerBalance = int.tryParse(wallet['sellerBalanceCoins']?.toString() ?? '') ?? (json['sellerBalance'] is int ? json['sellerBalance'] as int : 0);
    final followers = profile['followersCount'] is int ? profile['followersCount'] as int : (json['followers'] is int ? json['followers'] as int : 0);
    final following = profile['followingCount'] is int ? profile['followingCount'] as int : (json['following'] is int ? json['following'] as int : 0);

    final userType = json['userType']?.toString().toUpperCase();
    UserRole role = UserRole.user;
    if (userType == 'HOST' || hostProfile != null) role = UserRole.host;
    if (userType == 'SELLER') role = UserRole.seller;
    if (userType == 'AGENCY') role = UserRole.agency;
    if (userType == 'BD') role = UserRole.bd;
    if (userType == 'ADMIN') role = UserRole.admin;

    final int wealthLevel = profile['wealthLevel'] is int ? profile['wealthLevel'] as int : (json['wealthLevel'] is int ? json['wealthLevel'] as int : 1);
    final int charmLevel = profile['charmLevel'] is int ? profile['charmLevel'] as int : (json['charmLevel'] is int ? json['charmLevel'] as int : 1);
    final int accountLevel = profile['level'] is int ? profile['level'] as int : (json['accountLevel'] is int ? json['accountLevel'] as int : 1);
    final bool isVipUser = json['isVip'] == true || (wealthLevel > 10);

    return UserModel(
      id: id,
      username: username,
      name: name,
      email: email,
      phone: phone,
      avatarUrl: avatarUrl,
      coverUrl: json['coverUrl']?.toString(),
      bio: bio,
      gender: gender,
      region: region,
      dateOfBirth: dob,
      profileCompleted: json['profileCompleted'] == true ||
          (profile['displayName'] != null && profile['displayName'].toString().trim().isNotEmpty) ||
          (name.isNotEmpty && name != 'Guest') ||
          (username.isNotEmpty && !username.startsWith('user_')),
      followers: followers,
      following: following,
      diamonds: diamonds,
      coins: coins,
      rCoins: (json['rCoins'] as num?)?.toDouble() ?? 0.0,
      isVip: isVipUser,
      vipLevel: isVipUser ? (json['vipLevel']?.toString() ?? 'VIP 1') : 'None',
      isHost: role == UserRole.host || hostProfile != null,
      isAgency: role == UserRole.agency,
      isSeller: role == UserRole.seller || sellerBalance > 0,
      isBd: role == UserRole.bd,
      agencyName: json['agencyName']?.toString(),
      sellerBalance: sellerBalance,
      isOnline: json['isOnline'] ?? true,
      isLive: json['isLive'] ?? false,
      liveRoomId: json['liveRoomId']?.toString(),
      avatarFrame: json['avatarFrame']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '',
      referralCode: json['referralCode']?.toString() ?? 'ZEP$id',
      referralCount: json['referralCount'] is int ? json['referralCount'] as int : 0,
      role: role,
      hostApplicationStatus: hostProfile?['status']?.toString().toLowerCase() ?? json['hostApplicationStatus']?.toString() ?? 'none',
      hostRejectionReason: hostProfile?['rejectionReason']?.toString() ?? json['hostRejectionReason']?.toString(),
      wealthLevel: wealthLevel,
      wealthXp: profile['experience'] is int ? profile['experience'] as int : (json['wealthXp'] is int ? json['wealthXp'] as int : 0),
      charmLevel: charmLevel,
      charmXp: 0,
      gameLevel: json['gameLevel'] is int ? json['gameLevel'] as int : 1,
      gameXp: 0,
      accountLevel: accountLevel,
      accountXp: 0,
      cpPartnerId: json['cpPartnerId']?.toString(),
      nobleTitle: json['nobleTitle']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      likesReceived: profile['likesReceived'] is int
          ? profile['likesReceived'] as int
          : (json['likesReceived'] is int
              ? json['likesReceived'] as int
              : (json['likesCount'] is int ? json['likesCount'] as int : 0)),
      isCountryLocked: json['isCountryLocked'] == true || profile['isCountryLocked'] == true,
    );
  }

  /// Extracts or computes country flag for display on user ID and profile
  String get countryFlag {
    if (region.isEmpty) return '🇵🇰';

    // 1. Extract emoji flag directly if present in region string
    final emojiRegExp = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
    final match = emojiRegExp.firstMatch(region);
    if (match != null) return match.group(0)!;

    final lower = region.toLowerCase().trim();
    if (lower.contains('pakistan') || lower == 'pk') return '🇵🇰';
    if (lower.contains('united states') || lower.contains('usa') || lower == 'us') return '🇺🇸';
    if (lower.contains('united kingdom') || lower.contains('uk') || lower == 'gb') return '🇬🇧';
    if (lower.contains('saudi') || lower == 'sa') return '🇸🇦';
    if (lower.contains('emirates') || lower.contains('uae') || lower == 'ae') return '🇦🇪';
    if (lower.contains('india') || lower == 'in') return '🇮🇳';
    if (lower.contains('bangladesh') || lower == 'bd') return '🇧🇩';
    if (lower.contains('canada') || lower == 'ca') return '🇨🇦';
    if (lower.contains('australia') || lower == 'au') return '🇦🇺';
    if (lower.contains('germany') || lower == 'de') return '🇩🇪';
    if (lower.contains('france') || lower == 'fr') return '🇫🇷';
    if (lower.contains('turkey') || lower == 'tr') return '🇹🇷';
    if (lower.contains('egypt') || lower == 'eg') return '🇪🇬';
    if (lower.contains('indonesia') || lower == 'id') return '🇮🇩';
    if (lower.contains('malaysia') || lower == 'my') return '🇲🇾';
    if (lower.contains('philippines') || lower == 'ph') return '🇵🇭';
    if (lower.contains('japan') || lower == 'jp') return '🇯🇵';
    if (lower.contains('korea') || lower == 'kr') return '🇰🇷';
    if (lower.contains('china') || lower == 'cn') return '🇨🇳';
    if (lower.contains('qatar') || lower == 'qa') return '🇶🇦';
    if (lower.contains('kuwait') || lower == 'kw') return '🇰🇼';
    if (lower.contains('oman') || lower == 'om') return '🇴🇲';
    if (lower.contains('bahrain') || lower == 'bh') return '🇧🇭';

    return '🇵🇰';
  }

  /// Clean country name without flag emoji prefix
  String get cleanCountryName {
    return region.replaceAll(RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true), '').trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'coverUrl': coverUrl,
      'bio': bio,
      'gender': gender,
      'region': region,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'profileCompleted': profileCompleted,
      'followers': followers,
      'following': following,
      'diamonds': diamonds,
      'coins': coins,
      'rCoins': rCoins,
      'isVip': isVip,
      'vipLevel': vipLevel,
      'isHost': isHost,
      'isAgency': isAgency,
      'isSeller': isSeller,
      'isBd': isBd,
      'agencyName': agencyName,
      'sellerBalance': sellerBalance,
      'isOnline': isOnline,
      'isLive': isLive,
      'liveRoomId': liveRoomId,
      'avatarFrame': avatarFrame,
      'badge': badge,
      'referralCode': referralCode,
      'referralCount': referralCount,
      'role': role.name,
      'wealthLevel': wealthLevel,
      'charmLevel': charmLevel,
      'accountLevel': accountLevel,
      'likesReceived': likesReceived,
      'isCountryLocked': isCountryLocked,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? coverUrl,
    String? bio,
    String? gender,
    String? region,
    DateTime? dateOfBirth,
    bool? profileCompleted,
    int? followers,
    int? following,
    int? diamonds,
    int? coins,
    double? rCoins,
    bool? isVip,
    String? vipLevel,
    bool? isHost,
    bool? isAgency,
    bool? isSeller,
    bool? isBd,
    String? agencyName,
    int? sellerBalance,
    bool? isOnline,
    bool? isLive,
    String? liveRoomId,
    String? avatarFrame,
    String? badge,
    String? referralCode,
    int? referralCount,
    UserRole? role,
    String? hostApplicationStatus,
    String? hostRejectionReason,
    int? wealthLevel,
    int? wealthXp,
    int? charmLevel,
    int? charmXp,
    int? gameLevel,
    int? gameXp,
    int? accountLevel,
    int? accountXp,
    String? cpPartnerId,
    int? cpPoints,
    List<String>? pendingCpRequests,
    String? nobleTitle,
    String? status,
    int? likesReceived,
    bool? isCountryLocked,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      region: region ?? this.region,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      diamonds: diamonds ?? this.diamonds,
      coins: coins ?? this.coins,
      rCoins: rCoins ?? this.rCoins,
      isVip: isVip ?? this.isVip,
      vipLevel: vipLevel ?? this.vipLevel,
      isHost: isHost ?? this.isHost,
      isAgency: isAgency ?? this.isAgency,
      isSeller: isSeller ?? this.isSeller,
      isBd: isBd ?? this.isBd,
      agencyName: agencyName ?? this.agencyName,
      sellerBalance: sellerBalance ?? this.sellerBalance,
      isOnline: isOnline ?? this.isOnline,
      isLive: isLive ?? this.isLive,
      liveRoomId: liveRoomId ?? this.liveRoomId,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      badge: badge ?? this.badge,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
      role: role ?? this.role,
      hostApplicationStatus: hostApplicationStatus ?? this.hostApplicationStatus,
      hostRejectionReason: hostRejectionReason ?? this.hostRejectionReason,
      wealthLevel: wealthLevel ?? this.wealthLevel,
      wealthXp: wealthXp ?? this.wealthXp,
      charmLevel: charmLevel ?? this.charmLevel,
      charmXp: charmXp ?? this.charmXp,
      gameLevel: gameLevel ?? this.gameLevel,
      gameXp: gameXp ?? this.gameXp,
      accountLevel: accountLevel ?? this.accountLevel,
      accountXp: accountXp ?? this.accountXp,
      cpPartnerId: cpPartnerId ?? this.cpPartnerId,
      cpPoints: cpPoints ?? this.cpPoints,
      pendingCpRequests: pendingCpRequests ?? this.pendingCpRequests,
      nobleTitle: nobleTitle ?? this.nobleTitle,
      status: status ?? this.status,
      likesReceived: likesReceived ?? this.likesReceived,
      isCountryLocked: isCountryLocked ?? this.isCountryLocked,
    );
  }
}

