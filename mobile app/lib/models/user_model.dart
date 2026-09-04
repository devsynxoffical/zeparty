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

  const UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    this.coverUrl,
    this.bio = 'Official Streamer & Content Creator 🚀 | Daily Streams 8 PM EST',
    this.gender = 'Not Specified',
    this.region = 'Global',
    this.dateOfBirth,
    this.profileCompleted = true,
    this.followers = 48900,
    this.following = 180,
    this.diamonds = 5400,
    this.coins = 12000,
    this.rCoins = 850.50,
    this.isVip = true,
    this.vipLevel = 'VIP 3',
    this.isHost = true,
    this.isAgency = false,
    this.isSeller = true,
    this.isBd = true,
    this.agencyName,
    this.sellerBalance = 50000,
    this.isOnline = true,
    this.isLive = false,
    this.liveRoomId,
    this.avatarFrame = 'Gold Crown Frame',
    this.badge = 'Top Host 🔥',
    this.referralCode = 'ZEP8892',
    this.referralCount = 14,
    this.role = UserRole.seller,
    this.hostApplicationStatus = 'none',
    this.hostRejectionReason,
    this.wealthLevel = 30,
    this.wealthXp = 823083480,
    this.charmLevel = 15,
    this.charmXp = 7800,
    this.gameLevel = 12,
    this.gameXp = 3200,
    this.accountLevel = 24,
    this.accountXp = 14200,
    this.cpPartnerId,
    this.cpPoints = 0,
    this.pendingCpRequests = const [],
    this.nobleTitle,
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
    );
  }
}

