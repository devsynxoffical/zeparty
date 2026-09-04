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
}

class GiftModel {
  final String id;
  final String name;
  final String icon;
  final int diamondPrice;
  final String category; // Lucky Gift, Classic, Event Gifts, Privileges, Country, Celebrity, Special
  final GiftAnimationLevel animationLevel;
  final String animationEffect;
  final bool supportsCombo;
  final String? soundAsset;
  final String? label;
  final bool isLuckyGift;
  final String? luckyBadge; // MAX X2000, MAGIC, LUCKY, MAX X10000

  const GiftModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.diamondPrice,
    required this.category,
    this.animationLevel = GiftAnimationLevel.basic,
    this.animationEffect = 'sparkle',
    this.supportsCombo = true,
    this.soundAsset,
    this.label,
    this.isLuckyGift = false,
    this.luckyBadge,
  });

  int get price => diamondPrice;

  static const List<GiftModel> defaultCatalog = [
    // ─── Lucky Gifts (Section 5 & Reference Image B) ───
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
