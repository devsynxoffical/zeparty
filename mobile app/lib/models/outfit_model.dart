enum OutfitCategory { frame, bubble, effect, car }
enum OutfitStatus { active, expired, available }

class OutfitModel {
  final String id;
  final String name;
  final OutfitCategory category;
  final String imageUrl;
  final OutfitStatus status;
  final int daysRemaining; // For expired/active tracking

  const OutfitModel({
    required this.id,
    required this.name,
    required this.category,
    required this.imageUrl,
    this.status = OutfitStatus.available,
    this.daysRemaining = 0,
  });

  OutfitModel copyWith({
    String? id,
    String? name,
    OutfitCategory? category,
    String? imageUrl,
    OutfitStatus? status,
    int? daysRemaining,
  }) {
    return OutfitModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      daysRemaining: daysRemaining ?? this.daysRemaining,
    );
  }
}
