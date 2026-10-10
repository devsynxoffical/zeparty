import 'package:flutter/material.dart';
import '../core/services/api_client.dart';

class EmojiPickerSheet extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;
  final String? roomId;

  const EmojiPickerSheet({
    super.key,
    required this.onEmojiSelected,
    this.roomId,
  });

  static void show(
    BuildContext context, {
    required Function(String emoji) onEmojiSelected,
    String? roomId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EmojiPickerSheet(
        onEmojiSelected: onEmojiSelected,
        roomId: roomId,
      ),
    );
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _dynamicCategories = [];

  static const List<Map<String, dynamic>> _defaultCategories = [
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
    _tabController = TabController(length: _defaultCategories.length, vsync: this);
    _fetchBackendEmojiTray();
  }

  Future<void> _fetchBackendEmojiTray() async {
    try {
      final response = await ApiClient.instance.get('/v1/emojis/tray');
      if (response.statusCode == 200 && response.data?['success'] == true) {
        final List dynamicList = response.data['data'] as List? ?? [];
        if (dynamicList.isNotEmpty) {
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final item in dynamicList) {
            if (item is Map<String, dynamic>) {
              final cat = item['category']?.toString() ?? 'Custom';
              grouped.putIfAbsent(cat, () => []).add(item);
            }
          }

          final List<Map<String, dynamic>> loadedCategories = [];
          grouped.forEach((catName, emojiItems) {
            loadedCategories.add({
              'title': catName,
              'icon': _getCategoryIcon(catName),
              'items': emojiItems,
            });
          });

          if (mounted && loadedCategories.isNotEmpty) {
            setState(() {
              _dynamicCategories = loadedCategories;
              _tabController.dispose();
              _tabController = TabController(length: _dynamicCategories.length, vsync: this);
              _isLoading = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('vip') || lower.contains('svip')) return Icons.workspace_premium_rounded;
    if (lower.contains('noble')) return Icons.shield_rounded;
    if (lower.contains('animated') || lower.contains('motion')) return Icons.auto_awesome_rounded;
    if (lower.contains('love') || lower.contains('heart')) return Icons.favorite_rounded;
    if (lower.contains('party') || lower.contains('fire')) return Icons.local_fire_department_rounded;
    return Icons.emoji_emotions_rounded;
  }

  Future<void> _onSelectCustomEmoji(Map<String, dynamic> item) async {
    final symbol = item['symbol']?.toString() ?? item['code']?.toString() ?? '✨';
    final emojiId = item['id']?.toString();

    if (emojiId != null && widget.roomId != null) {
      try {
        await ApiClient.instance.post('/v1/emojis/send', data: {
          'emojiId': emojiId,
          'roomId': widget.roomId,
        });
      } catch (_) {}
    }

    widget.onEmojiSelected(symbol);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCategories = _dynamicCategories.isNotEmpty ? _dynamicCategories : _defaultCategories;

    return Container(
      height: 340,
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
            isScrollable: activeCategories.length > 5,
            indicatorColor: Colors.amber,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white54,
            tabs: activeCategories.map((c) => Tab(
              icon: Icon(c['icon'] as IconData, size: 20),
              text: c['title'] as String?,
            )).toList(),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Emojis Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : TabBarView(
                    controller: _tabController,
                    children: activeCategories.map((cat) {
                      if (_dynamicCategories.isNotEmpty) {
                        final List items = cat['items'] as List? ?? [];
                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index] as Map<String, dynamic>;
                            final symbol = item['symbol']?.toString() ?? item['icon']?.toString() ?? '✨';
                            final isLocked = item['isLocked'] == true;

                            return GestureDetector(
                              onTap: isLocked ? null : () => _onSelectCustomEmoji(item),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isLocked
                                      ? Colors.white.withValues(alpha: 0.02)
                                      : Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: isLocked
                                      ? Border.all(color: Colors.white12)
                                      : null,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      symbol,
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: isLocked ? Colors.white38 : Colors.white,
                                      ),
                                    ),
                                    if (isLocked)
                                      const Positioned(
                                        right: 4,
                                        bottom: 4,
                                        child: Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }

                      // Default static fallback
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

