class MedalModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl; // Or locally stored asset path/icon name
  final bool isEarned;
  final bool isEquipped;
  final String category;

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
