import 'package:shared_preferences/shared_preferences.dart';
import 'user_model.dart';
import 'user_asset_model.dart';

class MedalManager {
  static const String _prefPrefix = 'equipped_medal_ids_';

  /// Get the set of equipped medal IDs for a given user
  static Future<Set<String>> getEquippedMedalIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('$_prefPrefix$userId');
      if (list != null) {
        return list.toSet();
      }
    } catch (_) {}
    return <String>{};
  }

  /// Check if user has explicitly saved equipped medals before
  static Future<bool> hasSavedEquippedMedals(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey('$_prefPrefix$userId');
    } catch (_) {}
    return false;
  }

  /// Save equipped medal IDs for a given user
  static Future<void> saveEquippedMedalIds(String userId, Set<String> equippedIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$_prefPrefix$userId', equippedIds.toList());
    } catch (_) {}
  }
}

class MedalModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl; // Or locally stored asset path/icon name
  final bool isEarned;
  final bool isEquipped;
  final String category;
  final int requiredLevel;

  static const List<MedalModel> defaultMedals = [
    // ─── 1. Nobility / Aristocracy Medals ───
    MedalModel(
      id: 'noble_emperor',
      name: 'Emperor Aristocracy',
      description: 'Highest Sovereign Rank in ZeParty Aristocracy.',
      iconUrl: 'assets/nobles/emperor_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_king',
      name: 'King Aristocracy',
      description: 'Supreme Royal King Entitlement in ZeParty Aristocracy.',
      iconUrl: 'assets/nobles/ZP-037_tier-6-king_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_duke',
      name: 'Duke Aristocracy',
      description: 'Grand Aristocratic Title in ZeParty Grand Council.',
      iconUrl: 'assets/nobles/duke_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_marquis',
      name: 'Marquis Aristocracy',
      description: 'Prestigious Aristocratic Rank in ZeParty.',
      iconUrl: 'assets/nobles/marquis_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_count',
      name: 'Count Aristocracy',
      description: 'Honorable Nobility Title in ZeParty.',
      iconUrl: 'assets/nobles/count_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_viscount',
      name: 'Viscount Aristocracy',
      description: 'Distinguished Aristocratic Rank in ZeParty.',
      iconUrl: 'assets/nobles/viscount_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'noble_baron',
      name: 'Baron Aristocracy',
      description: 'Initiate Nobility Title in ZeParty Aristocracy.',
      iconUrl: 'assets/nobles/baron_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 1,
    ),

    // ─── 2. Platform Role & Agency Medals ───
    MedalModel(
      id: 'role_merchant',
      name: 'Official Merchant',
      description: 'Authorized ZeParty Merchant with payment processing privileges.',
      iconUrl: 'assets/roles/marchent_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Roles',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'role_seller',
      name: 'Coins Agency Seller',
      description: 'Certified Coins Agency Seller in ZeParty Recharge Network.',
      iconUrl: 'assets/roles/ZP-182_agency_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Roles',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'role_bd',
      name: 'Business Development',
      description: 'Official ZeParty BD Representative managing agencies and hosts.',
      iconUrl: 'assets/roles/ZP-188_bd_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Roles',
      requiredLevel: 1,
    ),
    MedalModel(
      id: 'role_host',
      name: 'Verified Broadcaster',
      description: 'Authorized live broadcaster and stage host in ZeParty.',
      iconUrl: 'assets/roles/host_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Roles',
      requiredLevel: 1,
    ),

    // ─── 3. Prestige Club Medals ───
    MedalModel(
      id: 'prestige_svip',
      name: 'SVIP Prestige',
      description: 'Privileged member of the ZeParty SVIP Supreme Club.',
      iconUrl: 'assets/svip/svip-7_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Prestige',
      requiredLevel: 1,
    ),
  ];

  const MedalModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    this.isEarned = false,
    this.isEquipped = false,
    this.category = 'All',
    this.requiredLevel = 1,
  });

  /// Real data: Only returns true if the user actually earned/unlocked the medal
  bool isUnlockedForLevel(int userLevel) => isEarned;

  /// Authoritative resolver that maps user entitlement to real earned medals.
  /// If [equippedMedalIds] is provided, only matching medals have [isEquipped = true].
  /// If not yet explicitly set, defaults the user's active noble medal (if any) as equipped.
  static List<MedalModel> resolveUserMedals(
    UserModel user, {
    List<UserAssetModel>? honorAssets,
    Set<String>? equippedMedalIds,
    bool hasExplicitEquippedSelection = false,
  }) {
    final nobleTitle = user.nobleTitle?.toLowerCase().trim() ?? '';
    final isKing = nobleTitle.contains('king');
    final isEmperor = nobleTitle.contains('emperor');
    final isDuke = nobleTitle.contains('duke');
    final isMarquis = nobleTitle.contains('marquis');
    final isCount = nobleTitle.contains('count');
    final isViscount = nobleTitle.contains('viscount');
    final isBaron = nobleTitle.contains('baron');
    final isMerchant = user.isMerchant;
    final isSeller = user.isSeller;
    final isBd = user.isBd;
    final isHost = user.isHost;
    final isSvip = user.svipLevel > 0 || user.isVip;

    // If user has not explicitly configured equipped medals, default their active noble medal as equipped
    String? defaultEquippedId;
    if (!hasExplicitEquippedSelection && (equippedMedalIds == null || equippedMedalIds.isEmpty)) {
      if (isKing) {
        defaultEquippedId = 'noble_king';
      } else if (isEmperor) {
        defaultEquippedId = 'noble_emperor';
      } else if (isDuke) {
        defaultEquippedId = 'noble_duke';
      } else if (isMarquis) {
        defaultEquippedId = 'noble_marquis';
      } else if (isCount) {
        defaultEquippedId = 'noble_count';
      } else if (isViscount) {
        defaultEquippedId = 'noble_viscount';
      } else if (isBaron) {
        defaultEquippedId = 'noble_baron';
      } else if (isMerchant) {
        defaultEquippedId = 'role_merchant';
      } else if (isSeller) {
        defaultEquippedId = 'role_seller';
      }
    }

    final resolved = defaultMedals.map((m) {
      bool earned = false;
      String icon = m.iconUrl;

      switch (m.id) {
        case 'noble_emperor':
          earned = isEmperor;
          break;
        case 'noble_king':
          earned = isKing;
          icon = 'assets/nobles/ZP-037_tier-6-king_badge.webp';
          break;
        case 'noble_duke':
          earned = isDuke;
          break;
        case 'noble_marquis':
          earned = isMarquis;
          break;
        case 'noble_count':
          earned = isCount;
          break;
        case 'noble_viscount':
          earned = isViscount;
          break;
        case 'noble_baron':
          earned = isBaron;
          break;
        case 'role_merchant':
          earned = isMerchant;
          break;
        case 'role_seller':
          earned = isSeller;
          break;
        case 'role_bd':
          earned = isBd;
          break;
        case 'role_host':
          earned = isHost;
          break;
        case 'prestige_svip':
          earned = isSvip;
          if (user.svipLevel > 0) {
            icon = 'assets/svip/svip-${user.svipLevel.clamp(1, 16)}_badge.webp';
          }
          break;
      }

      final bool equipped = earned && (
        hasExplicitEquippedSelection || (equippedMedalIds != null && equippedMedalIds.isNotEmpty)
            ? (equippedMedalIds != null && equippedMedalIds.contains(m.id))
            : (defaultEquippedId == m.id)
      );

      return m.copyWith(
        isEarned: earned,
        isEquipped: equipped,
        iconUrl: icon,
      );
    }).toList();

    // Dynamically append any real backpack honor assets (e.g. granted by admin or system)
    if (honorAssets != null && honorAssets.isNotEmpty) {
      for (final ha in honorAssets) {
        final a = ha.asset;
        if (a == null) continue;
        final isMedalOrBadge = a.categoryId.toLowerCase().contains('badge') ||
            a.assetType.toUpperCase().contains('MEDAL') ||
            a.assetType.toUpperCase().contains('BADGE');
        if (!isMedalOrBadge) continue;
        final assetMedalId = ha.assetId.isNotEmpty ? ha.assetId : ha.id;
        if (!resolved.any((rm) => rm.id == assetMedalId)) {
          final isEarned = !ha.isExpired;
          final bool equipped = isEarned && (
            hasExplicitEquippedSelection || (equippedMedalIds != null && equippedMedalIds.isNotEmpty)
                ? (equippedMedalIds != null && equippedMedalIds.contains(assetMedalId))
                : ha.isEquipped
          );
          resolved.add(MedalModel(
            id: assetMedalId,
            name: a.name,
            description: 'Exclusive Honor Award granted to your profile.',
            iconUrl: a.imageUrl,
            isEarned: isEarned,
            isEquipped: equipped,
            category: 'Honor',
            requiredLevel: 1,
          ));
        }
      }
    }

    return resolved;
  }

  MedalModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    bool? isEarned,
    bool? isEquipped,
    String? category,
    int? requiredLevel,
  }) {
    return MedalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      isEarned: isEarned ?? this.isEarned,
      isEquipped: isEquipped ?? this.isEquipped,
      category: category ?? this.category,
      requiredLevel: requiredLevel ?? this.requiredLevel,
    );
  }
}
