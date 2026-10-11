import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';
import '../core/utils/banner_router.dart';
import '../models/banner_item_model.dart';

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

class _BannerCarouselWidgetState extends State<BannerCarouselWidget> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  StreamSubscription? _socketBannerSub;

  // Rich default templates shown as fallbacks
  static final List<BannerItemModel> _defaultTemplates = [
    BannerItemModel(
      id: 'template_welcome',
      title: '🎉 Welcome to ZeParty!',
      subtitle: 'HD 8-Seat Voice Rooms, Live Streams & Global Chat',
      imageUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=1000&q=80',
      destinationUrl: 'zeparty://party',
    ),
    BannerItemModel(
      id: 'template_updates',
      title: '🚀 Big Updates Coming Soon!',
      subtitle: '3D Soundstages, AI Avatars & Season 4 Tournaments',
      imageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1000&q=80',
      destinationUrl: 'zeparty://updates',
    ),
    BannerItemModel(
      id: 'template_pk_live',
      title: '⚔️ Epic PK Battles & Live Stream',
      subtitle: 'Challenge Top Creators & Vote in High-Stakes Matches',
      imageUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
      destinationUrl: 'zeparty://live',
    ),
    BannerItemModel(
      id: 'template_giftings',
      title: '🎁 Send Luxury Gifts & Win Big',
      subtitle: 'Super Cars, Dragon Ships & SVIP Wealth Badges',
      imageUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&w=1000&q=80',
      destinationUrl: 'zeparty://store',
    ),
  ];

  List<BannerItemModel> _displayBanners = _defaultTemplates;

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
      final response = await ApiClient.instance.get(
        '/v1/banners/active',
        queryParameters: {'placement': 'HOME_CAROUSEL'},
      );
      if (response.statusCode == 200 && response.data != null) {
        final dynamic rawData = response.data['data'] ?? response.data;
        if (rawData is List && rawData.isNotEmpty) {
          final List<BannerItemModel> fetched = rawData
              .map((item) => BannerItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
              .where((b) => b.isActive)
              .toList();

          if (fetched.isNotEmpty && mounted) {
            setState(() {
              _displayBanners = fetched;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Fallback seamlessly to default templates if network unavailable
    }
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

  Widget _buildBannerCard(BannerItemModel banner) {
    final bool hasTitle = banner.title != null && banner.title!.trim().isNotEmpty;
    final bool hasSubtitle = banner.subtitle != null && banner.subtitle!.trim().isNotEmpty;
    final bool hasText = hasTitle || hasSubtitle;

    return GestureDetector(
      onTap: () {
        if (banner.destinationUrl == 'zeparty://updates') {
          _showUpcomingUpdatesDialog();
        } else {
          BannerRouter.handleBannerTap(
            context,
            banner.destinationUrl,
            onPartyTap: widget.onPartyTap,
            onLiveTap: widget.onLiveTap,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1E1B2E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Banner Image (Full Coverage Graphic Artwork)
              if (banner.imageUrl.isNotEmpty)
                Image.network(
                  banner.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF1E1B2E),
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 40),
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFF1E1B2E),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                      ),
                    );
                  },
                )
              else
                Container(
                  color: const Color(0xFF1E1B2E),
                  child: const Center(
                    child: Icon(Icons.style_rounded, color: Colors.amber, size: 40),
                  ),
                ),

              // 2. Text Overlay (ONLY if title or subtitle exists and is non-empty)
              if (hasText) ...[
                // Gradient protection overlay for contrast
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Title and Subtitle Text
                Positioned(
                  left: 16,
                  bottom: 16,
                  right: 32,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasTitle)
                        Text(
                          banner.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 4),
                        Text(
                          banner.subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
              return _buildBannerCard(_displayBanners[index]);
            },
          ),
        ),
        const SizedBox(height: 10),
        // Pagination Indicators
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
                      ? Colors.amber
                      : (widget.isDark ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.5),
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
