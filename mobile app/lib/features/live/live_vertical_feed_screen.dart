import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/utils/auth_guard.dart';
import '../../models/live_room_model.dart';
import '../../core/repositories/backend_repository.dart';
import '../../widgets/design/gold_icon_button.dart';
import '../../widgets/gift_dialog.dart';
import '../../widgets/gift_animation_overlay.dart';
import '../../providers/auth_provider.dart';
import '../../providers/live_provider.dart';
import '../party_room/widgets/room_info_sheet.dart';

class LiveVerticalFeedScreen extends StatefulWidget {
  final int initialIndex;
  const LiveVerticalFeedScreen({super.key, this.initialIndex = 0});

  @override
  State<LiveVerticalFeedScreen> createState() => _LiveVerticalFeedScreenState();
}

class _LiveVerticalFeedScreenState extends State<LiveVerticalFeedScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  final List<FloatingHeartAnimation> _floatingHearts = [];
  final Set<String> _followedHostIds = {};

  final List<String> _chatMessages = [
    'Sophia: Welcome to the stream everyone! ✨',
    'Alex: Amazing music performance! 🎙️🔥',
    'David: Sent 10 Roses 🌹🌹',
    'Elena: Hi from California! 👋',
    'Marcus: Drop that beat!! 🎧',
  ];

  final _commentController = TextEditingController();
  final GlobalKey<GiftAnimationOverlayState> _giftOverlayKey = GlobalKey<GiftAnimationOverlayState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _chatMessages.add('You: $text');
        _commentController.clear();
      });
      FocusScope.of(context).unfocus();
    }
  }

  void _showGiftPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.transparent,
      builder: (ctx) => GiftDialog(
        onGiftSent: (gift) {
          _giftOverlayKey.currentState?.playGiftAnimation(gift);
          setState(() {
            _chatMessages.add('You sent ${gift.icon} ${gift.name}!');
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final liveRooms = BackendRepository.instance.liveRooms;

    if (liveRooms.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(title: const Text('Live Stream')),
        body: const Center(child: Text('No active live streams right now.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Vertical Swipable PageView between Live Rooms
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: liveRooms.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final room = liveRooms[index];
              return _buildSingleLiveStream(context, room, isDark);
            },
          ),

          // Gift Animation Overlay Layer
          GiftAnimationOverlay(key: _giftOverlayKey),
        ],
      ),
    );
  }

  Widget _buildSingleLiveStream(BuildContext context, LiveRoomModel room, bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [

        // Live Stream Video Background Image Simulation
        Image.network(
          room.coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, e, err) => Container(color: AppColors.cardBlack),
        ),

        // Double Tap Detector for Like Hearts
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (details) {
              AuthGuard.require(context, () {
                try {
                  context.read<LiveProvider>().sendLike();
                } catch (_) {}
                final pos = details.localPosition;
                setState(() {
                  _floatingHearts.add(
                    FloatingHeartAnimation(
                      position: pos,
                      onComplete: () {
                        if (mounted && _floatingHearts.isNotEmpty) {
                          setState(() => _floatingHearts.removeAt(0));
                        }
                      },
                    ),
                  );
                });
              }, reason: 'Sign in to like live streams');
            },
            onDoubleTap: () {},
          ),
        ),

        // Double Tap Floating Hearts Layer
        ..._floatingHearts,

        // Translucent Gradient Overlay for Text Readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.black.withValues(alpha: 0.6),
                AppColors.transparent,
                AppColors.black.withValues(alpha: 0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // TOP LIVE HEADER
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    // Host Info Pill
                    Flexible(
                      child: GestureDetector(
                        onTap: () {
                          final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => RoomInfoSheet(
                              room: room,
                              canManage: room.host.id == currentUser.id,
                              isDark: isDark,
                              participants: null, // Viewer list can be added later if needed
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: NetworkImage(room.host.avatarUrl),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      room.host.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.remove_red_eye_rounded, size: 11, color: AppColors.secondaryText),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${room.viewerCount}',
                                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_followedHostIds.contains(room.host.id)) {
                                      _followedHostIds.remove(room.host.id);
                                    } else {
                                      _followedHostIds.add(room.host.id);
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_followedHostIds.contains(room.host.id) ? '✔ Following ${room.host.name}!' : 'Unfollowed ${room.host.name}'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _followedHostIds.contains(room.host.id) ? AppColors.liveGreen : null,
                                    gradient: _followedHostIds.contains(room.host.id) ? null : AppColors.getAccentGradient(isDark),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _followedHostIds.contains(room.host.id) ? Icons.check_rounded : Icons.add_rounded,
                                        size: 12,
                                        color: _followedHostIds.contains(room.host.id) ? Colors.white : AppColors.onGold(),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        _followedHostIds.contains(room.host.id) ? 'Following' : 'Follow',
                                        style: TextStyle(
                                          color: _followedHostIds.contains(room.host.id) ? Colors.white : AppColors.onGold(),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Live Badge
                    PulseAnimation(
                      minScale: 0.94,
                      maxScale: 1.0,
                      duration: const Duration(milliseconds: 1100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.liveRed,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.liveRed.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sensors_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 3),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    IconButton(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // BOTTOM LIVE CHAT & INTERACTION BAR
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Room Title Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  room.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 12),

              // Live Real-Time Chat Stream (Scrollable)
              SizedBox(
                height: 160,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, idx) {
                    final msg = _chatMessages[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Comment Input & Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.black.withValues(alpha: 0.65)
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark
                              ? AppColors.getBorderStrong(isDark).withValues(alpha: 0.4)
                              : AppColors.royalBlue.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : AppColors.royalBlue.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              style: TextStyle(
                                color: isDark ? AppColors.white : AppColors.lightTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Send a comment...',
                                hintStyle: TextStyle(
                                  color: isDark ? AppColors.secondaryText : AppColors.lightTextSecondary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                              ),
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          GoldFilledIconButton(
                            icon: Icons.send_rounded,
                            size: 34,
                            onPressed: _sendComment,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Gift Button
                  GestureDetector(
                    onTap: () => _showGiftPanel(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.getAccentGradient(isDark),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.getPrimary(isDark).withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.card_giftcard_rounded,
                        color: AppColors.onPrimary(isDark: isDark),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Like Heart Button
                  GestureDetector(
                    onTap: () {
                      final size = MediaQuery.of(context).size;
                      final centerPos = Offset(size.width / 2, size.height / 2);
                      setState(() {
                        _floatingHearts.add(
                          FloatingHeartAnimation(
                            position: centerPos,
                            onComplete: () {
                              if (_floatingHearts.isNotEmpty) {
                                setState(() => _floatingHearts.removeAt(0));
                              }
                            },
                          ),
                        );
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.liveRed.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.liveRed.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Share Button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
