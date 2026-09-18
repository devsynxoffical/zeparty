enum GiftAnimationLevel {
  basic,     // Level 1: Heart, Rose, etc.
  standard,  // Level 2: Cake, Gift Box
  premium,   // Level 3: Rocket, Yacht
  legendary, // Level 4: King Crown, Castle, Galaxy
}

enum CatalogTypeFilter { all, gift, props }

class PropItemModel {
  final String id;
  final String name;
  final String icon;
  final String category; // 'Bags', 'SVIP/VIP', 'Noble', 'Mounts'
  final bool isOwned;
  final String? expiryText;
  final String actionLabel; // 'Use', 'Equip', 'Activate', 'Preview'

  const PropItemModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.category,
    this.isOwned = true,
    this.expiryText,
    this.actionLabel = 'Equip',
  });

  factory PropItemModel.fromJson(Map<String, dynamic> json) {
    return PropItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Prop',
      icon: json['icon'] as String? ?? json['iconUrl'] as String? ?? '🎒',
      category: json['category'] as String? ?? 'Bags',
      isOwned: json['isOwned'] as bool? ?? true,
      expiryText: json['expiryText'] as String?,
      actionLabel: json['actionLabel'] as String? ?? 'Equip',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'category': category,
      'isOwned': isOwned,
      'expiryText': expiryText,
      'actionLabel': actionLabel,
    };
  }
}

class GiftModel {
  final String id;
  final String name;
  final String icon;
  final String? iconUrl;
  final String? svgaAssetUrl;
  final int diamondPrice;
  final int priceCoins;
  final String category; // Lucky Gift, Classic, Event Gifts, Privileges, Country, Celebrity, Special
  final String giftCategory; // Backend enum: POPULAR, LUXURY, VIP, AUDIO
  final GiftAnimationLevel animationLevel;
  final String animationEffect;
  final bool supportsCombo;
  final String? soundAsset;
  final String? label;
  final bool isLuckyGift;
  final String? luckyBadge;
  final bool isAnimated;
  final bool isFullScreen;
  final bool isActive;

  const GiftModel({
    required this.id,
    required this.name,
    required this.icon,
    this.iconUrl,
    this.svgaAssetUrl,
    required this.diamondPrice,
    int? priceCoins,
    required this.category,
    this.giftCategory = 'POPULAR',
    this.animationLevel = GiftAnimationLevel.basic,
    this.animationEffect = 'sparkle',
    this.supportsCombo = true,
    this.soundAsset,
    this.label,
    this.isLuckyGift = false,
    this.luckyBadge,
    this.isAnimated = false,
    this.isFullScreen = false,
    this.isActive = true,
  }) : priceCoins = priceCoins ?? diamondPrice;

  int get price => priceCoins > 0 ? priceCoins : diamondPrice;

  factory GiftModel.fromJson(Map<String, dynamic> json) {
    final rawCoins = json['coinValue'] ?? json['priceCoins'] ?? json['diamondPrice'] ?? 0;
    int coins = 0;
    if (rawCoins is num) {
      coins = rawCoins.toInt();
    } else if (rawCoins is String) {
      coins = int.tryParse(rawCoins) ?? 0;
    }

    final backendCat = (json['giftCategory'] as String? ?? 'POPULAR').toUpperCase();
    String displayCategory = 'Classic';
    if (backendCat == 'POPULAR') {
      displayCategory = 'Classic';
    } else if (backendCat == 'LUXURY') {
      displayCategory = 'Event Gifts';
    } else if (backendCat == 'VIP') {
      displayCategory = 'Privileges';
    } else if (backendCat == 'AUDIO') {
      displayCategory = 'Special';
    } else {
      displayCategory = json['category'] as String? ?? 'Classic';
    }

    final isAnim = json['isAnimated'] as bool? ?? false;
    final isFull = json['isFullScreen'] as bool? ?? false;
    final iconString = json['icon'] as String? ?? (isFull ? '🏰' : isAnim ? '🏎️' : '🎁');

    GiftAnimationLevel animLevel = GiftAnimationLevel.basic;
    if (isFull || coins >= 10000) {
      animLevel = GiftAnimationLevel.legendary;
    } else if (coins >= 1000) {
      animLevel = GiftAnimationLevel.premium;
    } else if (coins >= 100 || isAnim) {
      animLevel = GiftAnimationLevel.standard;
    }

    return GiftModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Gift',
      icon: iconString,
      iconUrl: json['iconUrl'] as String?,
      svgaAssetUrl: json['svgaAssetUrl'] as String? ?? json['animationUrl'] as String?,
      diamondPrice: coins,
      priceCoins: coins,
      category: displayCategory,
      giftCategory: backendCat,
      animationLevel: animLevel,
      animationEffect: json['animationEffect'] as String? ?? 'sparkle',
      supportsCombo: json['supportsCombo'] as bool? ?? true,
      soundAsset: json['soundAsset'] as String?,
      label: json['label'] as String?,
      isLuckyGift: json['isLuckyGift'] as bool? ?? (backendCat == 'AUDIO' || displayCategory == 'Lucky Gift'),
      luckyBadge: json['luckyBadge'] as String?,
      isAnimated: isAnim,
      isFullScreen: isFull,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'iconUrl': iconUrl,
      'svgaAssetUrl': svgaAssetUrl,
      'coinValue': priceCoins.toString(),
      'diamondPrice': diamondPrice,
      'priceCoins': priceCoins,
      'category': category,
      'giftCategory': giftCategory,
      'animationLevel': animationLevel.name,
      'animationEffect': animationEffect,
      'supportsCombo': supportsCombo,
      'soundAsset': soundAsset,
      'label': label,
      'isLuckyGift': isLuckyGift,
      'luckyBadge': luckyBadge,
      'isAnimated': isAnimated,
      'isFullScreen': isFullScreen,
      'isActive': isActive,
    };
  }

  static const List<GiftModel> defaultCatalog = [
    // ─── Lucky Gifts ───
    GiftModel(
      id: 'lucky_ball',
      name: 'Golden Ball',
      icon: '⚽',
      diamondPrice: 50,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAX X2000',
      animationLevel: GiftAnimationLevel.standard,
    ),
    GiftModel(
      id: 'lucky_flower',
      name: 'Flower of Blessing',
      icon: '🌸',
      diamondPrice: 100,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAX X10000',
      animationLevel: GiftAnimationLevel.standard,
    ),
    GiftModel(
      id: 'lucky_book',
      name: 'Fantasy Magic',
      icon: '📖',
      diamondPrice: 500,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAGIC',
      animationLevel: GiftAnimationLevel.premium,
    ),
    GiftModel(
      id: 'lucky_dream',
      name: 'Dream Catcher',
      icon: '🕸️',
      diamondPrice: 1500,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAGIC',
      animationLevel: GiftAnimationLevel.premium,
    ),
    GiftModel(
      id: 'lucky_pumpkin',
      name: 'Lucky Pumpkin',
      icon: '🎃',
      diamondPrice: 5,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAX X2000',
      animationLevel: GiftAnimationLevel.basic,
    ),
    GiftModel(
      id: 'lucky_lamp',
      name: 'Magic Lamp',
      icon: '🪔',
      diamondPrice: 1000,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAGIC',
      animationLevel: GiftAnimationLevel.premium,
    ),
    GiftModel(
      id: 'lucky_arrow',
      name: 'Magic Arrow',
      icon: '🏹',
      diamondPrice: 1500,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'MAX X5000',
      animationLevel: GiftAnimationLevel.premium,
    ),
    GiftModel(
      id: 'lucky_song',
      name: 'Sing Song',
      icon: '🎤',
      diamondPrice: 10,
      category: 'Lucky Gift',
      isLuckyGift: true,
      luckyBadge: 'LUCKY',
      animationLevel: GiftAnimationLevel.basic,
    ),

    // ─── Classic / Popular Gifts ───
    GiftModel(
      id: 'gift_rose',
      name: 'Rose',
      icon: '🌹',
      diamondPrice: 10,
      category: 'Classic',
      animationLevel: GiftAnimationLevel.basic,
    ),
    GiftModel(
      id: 'gift_heart',
      name: 'Heart',
      icon: '❤️',
      diamondPrice: 50,
      category: 'Classic',
      animationLevel: GiftAnimationLevel.basic,
    ),
    GiftModel(
      id: 'gift_sports_car',
      name: 'Sports Car',
      icon: '🏎️',
      diamondPrice: 500,
      category: 'Classic',
      animationLevel: GiftAnimationLevel.standard,
      label: 'NEW',
    ),
    GiftModel(
      id: 'gift_private_jet',
      name: 'Private Jet',
      icon: '🛩️',
      diamondPrice: 2000,
      category: 'Classic',
      animationLevel: GiftAnimationLevel.premium,
    ),

    // ─── Event / Special Gifts ───
    GiftModel(
      id: 'gift_crown',
      name: 'King Crown',
      icon: '👑',
      diamondPrice: 5000,
      category: 'Event Gifts',
      animationLevel: GiftAnimationLevel.legendary,
      label: 'MAX',
    ),
    GiftModel(
      id: 'gift_castle',
      name: 'Royal Castle',
      icon: '🏰',
      diamondPrice: 15000,
      category: 'Event Gifts',
      animationLevel: GiftAnimationLevel.legendary,
    ),
    GiftModel(
      id: 'gift_fireworks',
      name: 'Fireworks',
      icon: '🎆',
      diamondPrice: 300,
      category: 'Event Gifts',
      animationLevel: GiftAnimationLevel.standard,
    ),

    // ─── Privileges / VIP Gifts ───
    GiftModel(
      id: 'gift_svip_throne',
      name: 'SVIP Throne',
      icon: '🛋️',
      diamondPrice: 20000,
      category: 'Privileges',
      animationLevel: GiftAnimationLevel.legendary,
      label: 'SVIP',
    ),
    GiftModel(
      id: 'gift_gold_bar',
      name: 'Gold Bar',
      icon: '🪙',
      diamondPrice: 1000,
      category: 'Privileges',
      animationLevel: GiftAnimationLevel.standard,
    ),

    // ─── Country / Special Gifts ───
    GiftModel(
      id: 'gift_flag_banner',
      name: 'Country Flag',
      icon: '🇵🇰',
      diamondPrice: 100,
      category: 'Country',
      animationLevel: GiftAnimationLevel.basic,
    ),
  ];

  static const List<PropItemModel> defaultProps = [
    PropItemModel(
      id: 'prop_mount_dragon',
      name: 'Golden Dragon Mount',
      icon: '🐉',
      category: 'Mounts',
      isOwned: true,
      expiryText: '7 Days Left',
      actionLabel: 'Equip',
    ),
    PropItemModel(
      id: 'prop_frame_svip',
      name: 'SVIP 11 Royalty Frame',
      icon: '👑',
      category: 'SVIP/VIP',
      isOwned: true,
      expiryText: 'Permanent',
      actionLabel: 'Use',
    ),
    PropItemModel(
      id: 'prop_noble_badge',
      name: 'Duke Noble Crest',
      icon: '🛡️',
      category: 'Noble',
      isOwned: true,
      expiryText: 'Active',
      actionLabel: 'Activate',
    ),
    PropItemModel(
      id: 'prop_bag_gift_box',
      name: 'Free Gift Pack (3x)',
      icon: '🎒',
      category: 'Bags',
      isOwned: true,
      expiryText: '3 Remaining',
      actionLabel: 'Use Free',
    ),
  ];
}
