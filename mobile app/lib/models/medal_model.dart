class MedalModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl; // Or locally stored asset path/icon name
  final bool isEarned;
  final bool isEquipped;
  final String category;

  static const List<MedalModel> defaultMedals = [
    MedalModel(
      id: 'm1',
      name: 'Super Creator',
      description: 'Streamed over 50 hours in a single month.',
      iconUrl: 'super_creator',
      isEarned: false,
      isEquipped: false,
      category: 'Streamer',
    ),
    MedalModel(
      id: 'm2',
      name: 'Charity King',
      description: 'Sent over 100,000 diamonds in gift rewards.',
      iconUrl: 'charity_king',
      isEarned: false,
      category: 'Gifting',
    ),
    MedalModel(
      id: 'm3',
      name: 'Rising Star',
      description: 'Gained 1,000 followers in a single day.',
      iconUrl: 'rising_star',
      isEarned: false,
      category: 'Activity',
    ),
    MedalModel(
      id: 'm4',
      name: 'ZeParty Legend',
      description: 'Won 10 consecutive PK battles.',
      iconUrl: 'zep_legend',
      isEarned: false,
      category: 'Activity',
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
  });

  MedalModel copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    bool? isEarned,
    bool? isEquipped,
    String? category,
  }) {
    return MedalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      isEarned: isEarned ?? this.isEarned,
      isEquipped: isEquipped ?? this.isEquipped,
      category: category ?? this.category,
    );
  }
}
