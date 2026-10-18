/// Definition of a room reaction emoji from the reference asset catalog
class RoomEmojiItem {
  final String id;
  final String name;
  final String iconAsset;
  final String? reactionAsset;
  final bool isGame;
  final String? decorativeBadge; // purely visual badge (e.g. 'T5', 'T6') without locking

  const RoomEmojiItem({
    required this.id,
    required this.name,
    required this.iconAsset,
    this.reactionAsset,
    this.isGame = false,
    this.decorativeBadge,
  });
}

class RoomEmojiCatalog {
  RoomEmojiCatalog._();

  /// 15 Illustrated Reactions exactly matching Screenshot 2 and ZeParty asset pack
  static const List<RoomEmojiItem> illustratedEmojis = [
    // Row 1
    RoomEmojiItem(
      id: 'dice',
      name: 'Dice',
      iconAsset: 'assets/emojis/panel_icons/emoji_dice.png',
      isGame: true,
    ),
    RoomEmojiItem(
      id: 'number',
      name: 'Number',
      iconAsset: 'assets/emojis/panel_icons/emoji_number.png',
      isGame: true,
    ),
    RoomEmojiItem(
      id: 'salute',
      name: 'salute',
      iconAsset: 'assets/emojis/panel_icons/emoji_salute.png',
      reactionAsset: 'assets/emojis/reactions/emoji_salute_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'applaud',
      name: 'applaud',
      iconAsset: 'assets/emojis/panel_icons/emoji_applaud.png',
      reactionAsset: 'assets/emojis/reactions/emoji_applaud_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'sad',
      name: 'sad',
      iconAsset: 'assets/emojis/panel_icons/emoji_sad.png',
      reactionAsset: 'assets/emojis/reactions/emoji_sad_reaction.webp',
    ),

    // Row 2
    RoomEmojiItem(
      id: 'showlove',
      name: 'Show love',
      iconAsset: 'assets/emojis/panel_icons/emoji_showlove.png',
      reactionAsset: 'assets/emojis/reactions/emoji_showlove_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'right',
      name: 'Right',
      iconAsset: 'assets/emojis/panel_icons/emoji_right.png',
      reactionAsset: 'assets/emojis/reactions/emoji_right_reaction.webp',
      decorativeBadge: 'T5',
    ),
    RoomEmojiItem(
      id: 'left',
      name: 'Left',
      iconAsset: 'assets/emojis/panel_icons/emoji_left.png',
      reactionAsset: 'assets/emojis/reactions/emoji_left_reaction.webp',
      decorativeBadge: 'T6',
    ),
    RoomEmojiItem(
      id: 'laugh',
      name: 'Laugh',
      iconAsset: 'assets/emojis/panel_icons/emoji_laugh.png',
      reactionAsset: 'assets/emojis/reactions/emoji_laugh_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'smoking',
      name: 'Smoking',
      iconAsset: 'assets/emojis/panel_icons/emoji_smoking.png',
      reactionAsset: 'assets/emojis/reactions/emoji_smoking_reaction.webp',
      decorativeBadge: 'T7',
    ),

    // Row 3
    RoomEmojiItem(
      id: 'down',
      name: 'Down',
      iconAsset: 'assets/emojis/panel_icons/emoji_down.png',
      reactionAsset: 'assets/emojis/reactions/emoji_down_reaction.webp',
      decorativeBadge: 'T4',
    ),
    RoomEmojiItem(
      id: 'up',
      name: 'Up',
      iconAsset: 'assets/emojis/panel_icons/emoji_up.png',
      reactionAsset: 'assets/emojis/reactions/emoji_up_reaction.webp',
      decorativeBadge: 'T3',
    ),
    RoomEmojiItem(
      id: 'handclap',
      name: 'Handclap',
      iconAsset: 'assets/emojis/panel_icons/emoji_handclap.png',
      reactionAsset: 'assets/emojis/reactions/emoji_handclap_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'music',
      name: 'Music',
      iconAsset: 'assets/emojis/panel_icons/emoji_music.png',
      reactionAsset: 'assets/emojis/reactions/emoji_music_reaction.webp',
    ),
    RoomEmojiItem(
      id: 'rich',
      name: 'Rich',
      iconAsset: 'assets/emojis/panel_icons/emoji_rich.png',
      reactionAsset: 'assets/emojis/reactions/emoji_rich_reaction.webp',
      decorativeBadge: 'VIP',
    ),
  ];

  static RoomEmojiItem? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    final cleanId = id.trim().toLowerCase();
    for (final item in illustratedEmojis) {
      if (item.id.toLowerCase() == cleanId || item.name.toLowerCase() == cleanId) {
        return item;
      }
    }
    return null;
  }

  static RoomEmojiItem? findByReactionString(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.startsWith('reaction:')) {
      final sub = clean.substring('reaction:'.length).trim();
      return findById(sub);
    }
    if (clean.startsWith('[emoji_') && clean.endsWith(']')) {
      final sub = clean.substring(7, clean.length - 1).trim();
      return findById(sub);
    }
    return findById(clean);
  }

  static bool isIllustratedReaction(String text) {
    return findByReactionString(text) != null;
  }
}
