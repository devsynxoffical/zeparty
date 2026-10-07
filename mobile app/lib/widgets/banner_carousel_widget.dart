import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_colors.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';
import '../models/banner_item_model.dart';
import '../features/social/short_videos_screen.dart';
import '../features/games/game_lobby_screen.dart';
import '../features/store/store_screen.dart';
import '../features/vip/vip_store_screen.dart';

class BannerCarouselWidget extends StatefulWidget {
  final bool isDark;
  final VoidCallback onPartyTap;
  final VoidCallback onLiveTap;

  const BannerCarouselWidget({
    super.key,
    required this.isDark,
    required this.onPartyTap,
    required this.onLiveTap,
  });

  @override
  State<BannerCarouselWidget> createState() => _BannerCarouselWidgetState();
}

class _BannerCardData {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String? imageUrl;
  final String action;
  final List<Color> gradientColors;
  final Color accentColor;
  final IconData icon;

  const _BannerCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    this.imageUrl,
    required this.action,
    required this.gradientColors,
    required this.accentColor,
    required this.icon,
  });
}

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  StreamSubscription? _socketBannerSub;
  bool _isLoading = false;

  // 4 Built-in Rich Preset Templates
  static final List<_BannerCardData> _defaultTemplates = [
    const _BannerCardData(
      id: 'template_welcome',
      title: '🎉 Welcome to ZeParty!',
      subtitle: 'HD 8-Seat Voice Rooms, Live Streams & Global Chat',
      tag: 'WELCOME',
      action: 'zeparty://party',
      imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1000&q=80',
      gradientColors: [Color(0xFF4C1D95), Color(0xFF2E1065), Color(0xFF1E1B4B)],
      accentColor: Color(0xFFFFD700),
      icon: Icons.celebration_rounded,
    ),
    const _BannerCardData(
      id: 'template_updates',
      title: '🚀 Big Updates Coming Soon!',
      subtitle: '3D Soundstages, AI Avatars & Season 4 Tournaments',
      tag: 'SNEAK PEEK',
      action: 'zeparty://updates',
      imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1000&q=80',
      gradientColors: [Color(0xFF0369A1), Color(0xFF0C4A6E), Color(0xFF082F49)],
      accentColor: Color(0xFF38BDF8),
      icon: Icons.rocket_launch_rounded,
    ),
    const _BannerCardData(
      id: 'template_pk_live',
      title: '⚔️ Epic PK Battles & Live Stream',
      subtitle: 'Challenge Top Creators & Vote in High-Stakes Matches',
      tag: 'HOT BATTLE',
      action: 'zeparty://live',
      imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      gradientColors: [Color(0xFF991B1B), Color(0xFF7F1D1D), Color(0xFF450A0A)],
      accentColor: Color(0xFFFB923C),
      icon: Icons.local_fire_department_rounded,
    ),
    const _BannerCardData(
      id: 'template_giftings',
      title: '🎁 Send Luxury Gifts & Win Big',
      subtitle: 'Super Cars, Dragon Ships & SVIP Wealth Badges',
      tag: 'EXCLUSIVE REWARDS',
      action: 'zeparty://store',
      imageUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=1000&q=80',
      gradientColors: [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
      accentColor: Color(0xFFFBBF24),
      icon: Icons.card_giftcard_rounded,
    ),
  ];

  List<_BannerCardData> _displayBanners = _defaultTemplates;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchBanners();
    _listenToRealtimeBanners();
    _startTimer();
  }

  void _listenToRealtimeBanners() {
    _socketBannerSub = SocketService.instance.onBannerUpdated.listen((_) {
      if (mounted) {
        _fetchBanners();
      }
    });
  }

  Future<void> _fetchBanners() async {
    try {
      final response = await ApiClient.instance.get('/v1/banners/active');
      if (response.statusCode == 200 && response.data != null) {
        final dynamic rawData = response.data['data'] ?? response.data;
        if (rawData is List && rawData.isNotEmpty) {
          final List<BannerItemModel> fetched = rawData
              .map((item) => BannerItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .where((b) => b.isActive)
              .toList();

          if (fetched.isNotEmpty && mounted) {
            setState(() {
              _displayBanners = fetched.map((b) => _mapModelToCard(b)).toList();
            });
            return;
          }
        }
      }
    } catch (_) {
      // Fallback seamlessly to default templates if network unavailable
    }
  }

  _BannerCardData _mapModelToCard(BannerItemModel model) {
    final titleLower = model.title.toLowerCase();
    
    // Choose dynamic styling based on keywords or index
    if (titleLower.contains('welcome') || titleLower.contains('party')) {
      return _BannerCardData(
        id: model.id,
        title: model.title,
        subtitle: 'HD 8-Seat Voice Rooms, Live Streams & Global Chat',
        tag: 'FEATURED',
        imageUrl: model.imageUrl.isNotEmpty ? model.imageUrl : null,
        action: model.destinationUrl ?? 'zeparty://party',
        gradientColors: const [Color(0xFF4C1D95), Color(0xFF2E1065), Color(0xFF1E1B4B)],
        accentColor: const Color(0xFFFFD700),
        icon: Icons.celebration_rounded,
      );
    } else if (titleLower.contains('update') || titleLower.contains('soon') || titleLower.contains('coming')) {
      return _BannerCardData(
        id: model.id,
        title: model.title,
        subtitle: 'New features, rewards and exciting updates arriving soon',
        tag: 'SNEAK PEEK',
        imageUrl: model.imageUrl.isNotEmpty ? model.imageUrl : null,
        action: model.destinationUrl ?? 'zeparty://updates',
        gradientColors: const [Color(0xFF0369A1), Color(0xFF0C4A6E), Color(0xFF082F49)],
        accentColor: const Color(0xFF38BDF8),
        icon: Icons.rocket_launch_rounded,
      );
    } else if (titleLower.contains('pk') || titleLower.contains('live') || titleLower.contains('battle')) {
      return _BannerCardData(
        id: model.id,
        title: model.title,
        subtitle: 'High-Stakes Live Battles, Dynamic Combos & Leaderboards',
        tag: 'HOT BATTLE',
        imageUrl: model.imageUrl.isNotEmpty ? model.imageUrl : null,
        action: model.destinationUrl ?? 'zeparty://live',
        gradientColors: const [Color(0xFF991B1B), Color(0xFF7F1D1D), Color(0xFF450A0A)],
        accentColor: const Color(0xFFFB923C),
        icon: Icons.local_fire_department_rounded,
      );
    } else if (titleLower.contains('gift') || titleLower.contains('reward') || titleLower.contains('store')) {
      return _BannerCardData(
        id: model.id,
        title: model.title,
        subtitle: 'Send Super 3D Gifts, unlock VIP badges & earn rewards',
        tag: 'EXCLUSIVE',
        imageUrl: model.imageUrl.isNotEmpty ? model.imageUrl : null,
        action: model.destinationUrl ?? 'zeparty://store',
        gradientColors: const [Color(0xFF065F46), Color(0xFF064E3B), Color(0xFF022C22)],
        accentColor: const Color(0xFFFBBF24),
        icon: Icons.card_giftcard_rounded,
      );
    }

    // Generic Custom Banner
    return _BannerCardData(
      id: model.id,
      title: model.title,
      subtitle: 'Tap to explore special events and exclusive activities',
      tag: 'PROMO',
      imageUrl: model.imageUrl.isNotEmpty ? model.imageUrl : null,
      action: model.destinationUrl ?? 'zeparty://party',
      gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
      accentColor: const Color(0xFFFFD700),
      icon: Icons.auto_awesome_rounded,
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pageController.hasClients && _displayBanners.isNotEmpty) {
        int nextPage = (_currentPage + 1) % _displayBanners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _socketBannerSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(String action) {
    final cleanAction = action.trim();

    if (cleanAction == 'zeparty://party' || cleanAction == 'party') {
      widget.onPartyTap();
    } else if (cleanAction == 'zeparty://live' || cleanAction == 'live') {
      widget.onLiveTap();
    } else if (cleanAction == 'zeparty://updates' || cleanAction == 'updates') {
      _showUpcomingUpdatesDialog();
    } else if (cleanAction == 'zeparty://store' || cleanAction == 'store' || cleanAction == 'gifts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreScreen()));
    } else if (cleanAction == 'zeparty://vip' || cleanAction == 'vip') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const VipStoreScreen()));
    } else if (cleanAction == 'zeparty://shorts' || cleanAction == 'shorts') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ShortVideosScreen()));
    } else if (cleanAction == 'zeparty://games' || cleanAction == 'games') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLobbyScreen()));
    } else if (cleanAction.startsWith('http://') || cleanAction.startsWith('https://')) {
      final uri = Uri.tryParse(cleanAction);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      widget.onPartyTap();
    }
  }

  void _showUpcomingUpdatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                blurRadius: 28,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rocket_launch_rounded, color: Color(0xFF38BDF8), size: 14),
                        SizedBox(width: 5),
                        Text(
                          'VERSION 2.4 ROADMAP',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  )
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                '🚀 Exciting Features Coming Soon!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildUpdateFeatureRow(
                icon: Icons.spatial_audio_rounded,
                title: '3D Spatial Audio Soundstages',
                description: 'Dynamic voice positioning and immersive spatial room acoustics.',
              ),
              const SizedBox(height: 10),
              _buildUpdateFeatureRow(
                icon: Icons.face_retouching_natural_rounded,
                title: 'AI 3D Avatar Studio',
                description: 'Personalize animated avatars with custom outfits and reactive emotes.',
              ),
              const SizedBox(height: 10),
              _buildUpdateFeatureRow(
                icon: Icons.emoji_events_rounded,
                title: 'Season 4 PK Grand Tournament',
                description: 'Compete globally with coin prizes, SVIP frames, and physical trophies.',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Awesome, Stay Tuned!', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(color: Colors.white60, fontSize: 11, height: 1.3),
              ),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_displayBanners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 136,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _displayBanners.length,
            itemBuilder: (context, index) {
              final banner = _displayBanners[index];

              return GestureDetector(
                onTap: () => _handleBannerTap(banner.action),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: banner.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: banner.accentColor.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: banner.gradientColors.first.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(21),
                    child: Stack(
                      children: [
                        // Background image if provided
                        if (banner.imageUrl != null && banner.imageUrl!.isNotEmpty)
                          Positioned.fill(
                            child: Image.network(
                              banner.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return Opacity(opacity: 0.35, child: child);
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),

                        // Gradient protection overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  banner.gradientColors.first.withValues(alpha: 0.92),
                                  banner.gradientColors.last.withValues(alpha: 0.65),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.6, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          ),
                        ),

                        // Decorative floating background icon
                        Positioned(
                          right: -14,
                          bottom: -14,
                          child: Icon(
                            banner.icon,
                            size: 116,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),

                        // Banner Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: banner.accentColor.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: banner.accentColor.withValues(alpha: 0.6),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  banner.tag,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: banner.accentColor,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Title
                              Text(
                                banner.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      offset: Offset(0, 1),
                                      blurRadius: 3,
                                    )
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Subtitle
                              Text(
                                banner.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.82),
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Modern Pill Pagination Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _displayBanners.length,
            (index) {
              final isSelected = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                height: 5,
                width: isSelected ? 20 : 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (_displayBanners[index].accentColor)
                      : (widget.isDark ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _displayBanners[index].accentColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
