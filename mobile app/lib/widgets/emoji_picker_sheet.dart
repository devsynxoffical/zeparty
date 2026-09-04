import 'package:flutter/material.dart';

class EmojiPickerSheet extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;

  const EmojiPickerSheet({
    super.key,
    required this.onEmojiSelected,
  });

  static void show(BuildContext context, {required Function(String emoji) onEmojiSelected}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EmojiPickerSheet(onEmojiSelected: onEmojiSelected),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Map<String, dynamic>> _categories = [
    {
      'title': 'Popular',
      'icon': Icons.local_fire_department_rounded,
      'emojis': ['❤️', '😂', '😍', '🔥', '👏', '😘', '🎉', '😎', '🥰', '🤣', '👍', '💯', '✨', '🚀', '💎', '👑']
    },
    {
      'title': 'Love',
      'icon': Icons.favorite_rounded,
      'emojis': ['❤️', '💖', '💕', '💗', '💓', '💘', '💙', '💜', '💚', '🧡', '💛', '🤍', '🤎', '❣️', '💔']
    },
    {
      'title': 'Party',
      'icon': Icons.celebration_rounded,
      'emojis': ['🎉', '🥳', '🍾', '🎆', '✨', '🌟', '👑', '🏆', '💎', '🚀', '💣', '💥', '🎶', '🎵', '🎤']
    },
    {
      'title': 'Faces',
      'icon': Icons.sentiment_very_satisfied_rounded,
      'emojis': ['😂', '🤣', '😍', '😎', '🥰', '😘', '🤩', '😜', '😇', '🥳', '🤯', '😏', '🤤', '🤠', '🤡']
    },
    {
      'title': 'Hands',
      'icon': Icons.pan_tool_rounded,
      'emojis': ['👏', '👍', '🙌', '🤝', '👊', '✊', '🤘', '✌️', '🤌', '👈', '👉', '👇', '👆', '👋', '🙏']
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B2E) : const Color(0xFF2B243B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: false,
            indicatorColor: Colors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: _categories.map((c) => Tab(icon: Icon(c['icon'] as IconData, size: 20))).toList(),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Emojis Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((cat) {
                final List<String> emojis = cat['emojis'] as List<String>;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: emojis.length,
                  itemBuilder: (context, index) {
                    final emoji = emojis[index];
                    return GestureDetector(
                      onTap: () {
                        widget.onEmojiSelected(emoji);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
