enum UserRole { user, host, seller, agency, bd, admin }

class UserModel {
  final String id;
  final String username;
  final String name;
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
  );

  const UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    this.coverUrl,
    this.bio = 'Creator on ZeParty ✨',
    this.gender = 'Not Specified',
    this.region = 'Global',
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
  });

  /// Automatically calculate exact age from date of birth securely
  int get age {
    if (dateOfBirth == null) return 21; // Default fallback if not set
    final today = DateTime.now();
    int calculatedAge = today.year - dateOfBirth!.year;
    if (today.month < dateOfBirth!.month ||
        (today.month == dateOfBirth!.month && today.day < dateOfBirth!.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  /// 18+ requirement for restricted live streaming features
  bool get isAgeEligible => age >= 18;

  /// Effective cover image URL fallback
  String get effectiveCoverUrl => (coverUrl != null && coverUrl!.isNotEmpty) ? coverUrl! : avatarUrl;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] is Map<String, dynamic> ? json['profile'] as Map<String, dynamic> : {};
    final wallet = json['wallet'] is Map<String, dynamic> ? json['wallet'] as Map<String, dynamic> : {};
    final hostProfile = json['hostProfile'] is Map<String, dynamic> ? json['hostProfile'] as Map<String, dynamic> : null;

    final id = json['id']?.toString() ?? '';
    final username = json['username']?.toString() ?? (profile['displayName']?.toString() ?? 'user_$id');
    final name = profile['displayName']?.toString() ?? json['name']?.toString() ?? username;
    final avatarUrl = profile['avatarUrl']?.toString() ?? json['avatarUrl']?.toString() ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
    final bio = profile['bio']?.toString() ?? json['bio']?.toString() ?? 'Creator on ZeParty ✨';
    final gender = profile['gender']?.toString() ?? json['gender']?.toString() ?? 'Not Specified';
    final region = profile['region']?.toString() ?? profile['countryCode']?.toString() ?? json['region']?.toString() ?? 'Global';
    
    DateTime? dob;
    if (profile['birthDate'] != null) {
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

    return UserModel(
      id: id,
      username: username,
      name: name,
      avatarUrl: avatarUrl,
      coverUrl: json['coverUrl']?.toString(),
      bio: bio,
      gender: gender,
      region: region,
      dateOfBirth: dob,
      profileCompleted: json['profileCompleted'] == true || profile['displayName'] != null,
      followers: followers,
      following: following,
      diamonds: diamonds,
      coins: coins,
      rCoins: (json['rCoins'] as num?)?.toDouble() ?? 0.0,
      isVip: json['isVip'] == true || (profile['wealthLevel'] != null && (profile['wealthLevel'] as int) > 0),
      vipLevel: json['vipLevel']?.toString() ?? 'VIP 1',
      isHost: role == UserRole.host || hostProfile != null,
      isAgency: role == UserRole.agency,
      isSeller: role == UserRole.seller || sellerBalance > 0,
      isBd: role == UserRole.bd,
      agencyName: json['agencyName']?.toString(),
      sellerBalance: sellerBalance,
      isOnline: json['isOnline'] ?? true,
      isLive: json['isLive'] ?? false,
      liveRoomId: json['liveRoomId']?.toString(),
      avatarFrame: json['avatarFrame']?.toString() ?? 'Gold Crown Frame',
      badge: json['badge']?.toString() ?? 'Active Member',
      referralCode: json['referralCode']?.toString() ?? 'ZEP$id',
      referralCount: json['referralCount'] is int ? json['referralCount'] as int : 0,
      role: role,
      hostApplicationStatus: hostProfile?['status']?.toString().toLowerCase() ?? json['hostApplicationStatus']?.toString() ?? 'none',
      hostRejectionReason: hostProfile?['rejectionReason']?.toString() ?? json['hostRejectionReason']?.toString(),
      wealthLevel: profile['wealthLevel'] is int ? profile['wealthLevel'] as int : 1,
      wealthXp: profile['experience'] is int ? profile['experience'] as int : 0,
      charmLevel: profile['charmLevel'] is int ? profile['charmLevel'] as int : 1,
      charmXp: 0,
      gameLevel: 1,
      gameXp: 0,
      accountLevel: profile['level'] is int ? profile['level'] as int : 1,
      accountXp: 0,
      cpPartnerId: json['cpPartnerId']?.toString(),
      cpPoints: json['cpPoints'] is int ? json['cpPoints'] as int : 0,
      pendingCpRequests: json['pendingCpRequests'] is List ? List<String>.from(json['pendingCpRequests']) : const [],
      nobleTitle: json['nobleTitle']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
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
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
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
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      name: name ?? this.name,
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
    );
  }
}
