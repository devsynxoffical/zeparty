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
    MedalModel(
      id: 'm1',
      name: 'Super Creator',
      description: 'Awarded to premier live streamers and broadcasters.',
      iconUrl: 'super_creator',
      isEarned: false,
      isEquipped: false,
      category: 'Streaming',
      requiredLevel: 30,
    ),
    MedalModel(
      id: 'm2',
      name: 'Charity Champion',
      description: 'Recognized for generous room contributions and gifting.',
      iconUrl: 'charity_king',
      isEarned: false,
      isEquipped: false,
      category: 'Gifting',
      requiredLevel: 20,
    ),
    MedalModel(
      id: 'm3',
      name: 'Rising Star',
      description: 'Active community presence and trending popularity.',
      iconUrl: 'rising_star',
      isEarned: false,
      isEquipped: false,
      category: 'Activity',
      requiredLevel: 15,
    ),
    MedalModel(
      id: 'm4',
      name: 'Community Pillar',
      description: 'Consistent daily presence and audio room participation.',
      iconUrl: 'community_pillar',
      isEarned: false,
      isEquipped: false,
      category: 'Social',
      requiredLevel: 10,
    ),
    MedalModel(
      id: 'm5',
      name: 'Platform Pioneer',
      description: 'Early adopter and loyal member of the ZeParty community.',
      iconUrl: 'platform_pioneer',
      isEarned: false,
      isEquipped: false,
      category: 'Tenure',
      requiredLevel: 5,
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

  bool isUnlockedForLevel(int userLevel) => userLevel >= requiredLevel || isEarned;

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
