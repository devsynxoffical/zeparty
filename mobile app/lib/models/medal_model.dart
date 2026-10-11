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
      name: 'Emperor Honor',
      description: 'Unlocks at Level 30. Supreme Emperor Status.',
      iconUrl: 'assets/nobles/emperor_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 30,
    ),
    MedalModel(
      id: 'm2',
      name: 'King Crown',
      description: 'Unlocks at Level 20. Kingdom Crown Status.',
      iconUrl: 'assets/nobles/king_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Streaming',
      requiredLevel: 20,
    ),
    MedalModel(
      id: 'm3',
      name: 'Duke Champion',
      description: 'Unlocks at Level 15. Duke Champion Status.',
      iconUrl: 'assets/nobles/duke_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Gifting',
      requiredLevel: 15,
    ),
    MedalModel(
      id: 'm4',
      name: 'Marquis Legend',
      description: 'Unlocks at Level 10. Marquis Legend Status.',
      iconUrl: 'assets/nobles/marquis_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Activity',
      requiredLevel: 10,
    ),
    MedalModel(
      id: 'm5',
      name: 'Count Shield',
      description: 'Unlocks at Level 5. Count Shield Status.',
      iconUrl: 'assets/nobles/count_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
      requiredLevel: 5,
    ),
    MedalModel(
      id: 'm6',
      name: 'Baron Supporter',
      description: 'Unlocks at Level 1. Baron Supporter Status.',
      iconUrl: 'assets/nobles/baron_badge.webp',
      isEarned: false,
      isEquipped: false,
      category: 'Nobility',
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
