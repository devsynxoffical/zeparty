enum AnnouncementType { gift, luckyWin, gameBet }

enum AnnouncementTier { highValue, superValue, megaValue }

class AnnouncementEvent {
  final String userId;
  final String userName;
  final String avatarUrl;
  final int vipLevel;
  final AnnouncementType type;
  final int amount;
  final String description; // e.g. "Sent Rose x100" or "Won Lucky Game"
  final String? iconAsset; // e.g. "assets/images/gift_rose.jpg"

  AnnouncementEvent({
    required this.userId,
    required this.userName,
    required this.avatarUrl,
    this.vipLevel = 0,
    required this.type,
    required this.amount,
    required this.description,
    this.iconAsset,
  });

  AnnouncementTier get tier {
    if (amount >= 1000000) return AnnouncementTier.megaValue;
    if (amount >= 500000) return AnnouncementTier.superValue;
    return AnnouncementTier.highValue;
  }
}
