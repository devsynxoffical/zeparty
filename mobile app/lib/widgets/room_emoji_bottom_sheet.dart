import 'package:flutter/material.dart';
import '../core/constants/room_emoji_catalog.dart';

class RoomEmojiBottomSheet extends StatefulWidget {
  final Function(RoomEmojiItem emojiItem) onEmojiSelected;
  final String? roomId;

  const RoomEmojiBottomSheet({
    super.key,
    required this.onEmojiSelected,
    this.roomId,
  });

  static void show(
    BuildContext context, {
    required Function(RoomEmojiItem emojiItem) onEmojiSelected,
    String? roomId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RoomEmojiBottomSheet(
        onEmojiSelected: onEmojiSelected,
        roomId: roomId,
      ),
    );
  }

  @override
  State<RoomEmojiBottomSheet> createState() => _RoomEmojiBottomSheetState();
}

class _RoomEmojiBottomSheetState extends State<RoomEmojiBottomSheet> {
  int _selectedCategoryIndex = 0;

  // Category navigation icons matching reference screenshot bottom bar
  final List<Map<String, dynamic>> _categoryTabs = [
    {
      'title': 'Reactions',
      'icon': 'assets/emojis/panel_icons/emoji_showlove.png',
      'isAsset': true,
      'fallbackEmoji': '😘',
    },
    {
      'title': 'Cute',
      'icon': 'assets/emojis/panel_icons/emoji_sad.png',
      'isAsset': true,
      'fallbackEmoji': '👶',
    },
    {
      'title': 'Party',
      'icon': 'assets/emojis/panel_icons/emoji_applaud.png',
      'isAsset': true,
      'fallbackEmoji': '🏆',
    },
    {
      'title': 'Bear',
      'icon': 'assets/emojis/panel_icons/emoji_rich.png',
      'isAsset': true,
      'fallbackEmoji': '🐻',
    },
    {
      'title': 'Pet',
      'icon': 'assets/emojis/panel_icons/emoji_laugh.png',
      'isAsset': true,
      'fallbackEmoji': '🐱',
    },
    {
      'title': 'VIP',
      'icon': 'assets/emojis/panel_icons/emoji_salute.png',
      'isAsset': true,
      'fallbackEmoji': '👑',
    },
    {
      'title': 'Music',
      'icon': 'assets/emojis/panel_icons/emoji_music.png',
      'isAsset': true,
      'fallbackEmoji': '🥁',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Matches the clean reference screenshot layout and styling
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1B1728) : Colors.white;
    final labelColor = isDark ? const Color(0xFFB0A8C2) : const Color(0xFF6B7280);

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Drag Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Grid of 15 Illustrated Emojis (5 columns x 3 rows)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.88,
                ),
                itemCount: RoomEmojiCatalog.illustratedEmojis.length,
                itemBuilder: (context, index) {
                  final item = RoomEmojiCatalog.illustratedEmojis[index];
                  return _buildEmojiCell(item, labelColor);
                },
              ),
            ),

            // Category Bar at Bottom (matching Reference Screenshot 2)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141120) : const Color(0xFFF9FAFB),
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_categoryTabs.length - 1, (idx) {
                          final tab = _categoryTabs[idx];
                          final isSelected = _selectedCategoryIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedCategoryIndex = idx);
                              },
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFFFECEF))
                                      : Colors.transparent,
                                ),
                                child: Center(
                                  child: Image.asset(
                                    tab['icon'] as String,
                                    width: 22,
                                    height: 22,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => Text(
                                      tab['fallbackEmoji'] as String,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // Far Right Action Icon (Drum / Music from Reference)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategoryIndex = _categoryTabs.length - 1);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _selectedCategoryIndex == _categoryTabs.length - 1
                            ? (isDark ? Colors.purple.withValues(alpha: 0.3) : const Color(0xFFEDE7F6))
                            : Colors.transparent,
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/emojis/panel_icons/emoji_music.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text('🥁', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiCell(RoomEmojiItem item, Color labelColor) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onEmojiSelected(item);
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji Icon with optional decorative badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Image.asset(
                item.iconAsset,
                width: 46,
                height: 46,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text('✨', style: TextStyle(fontSize: 26)),
                ),
              ),

              // Decorative badge (T3, T4, T5, T6, T7, VIP) matching reference screenshot
              if (item.decorativeBadge != null)
                Positioned(
                  top: -2,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                    decoration: BoxDecoration(
                      color: item.decorativeBadge == 'VIP'
                          ? const Color(0xFF5C6BC0)
                          : const Color(0xFF2E3A59),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      item.decorativeBadge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // Name label
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
