import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../features/social/short_videos_screen.dart';
import '../features/games/game_lobby_screen.dart';

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

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Weekend PK Battle!',
      'subtitle': 'Join the ultimate showdown',
      'color': Colors.redAccent,
      'icon': Icons.flash_on_rounded,
      'action': 'live'
    },
    {
      'title': 'Party Rooms',
      'subtitle': 'Hangout with up to 8 friends',
      'color': Colors.orangeAccent,
      'icon': Icons.groups_rounded,
      'action': 'party'
    },
    {
      'title': 'Trending Shorts',
      'subtitle': 'Discover viral moments',
      'color': Colors.pinkAccent,
      'icon': Icons.movie_filter_rounded,
      'action': 'shorts'
    },
    {
      'title': 'Game Center',
      'subtitle': 'Play & win big rewards',
      'color': Colors.purpleAccent,
      'icon': Icons.sports_esports_rounded,
      'action': 'games'
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int nextPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleBannerTap(String action) {
    switch (action) {
      case 'live':
        widget.onLiveTap();
        break;
      case 'party':
        widget.onPartyTap();
        break;
      case 'shorts':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShortVideosScreen()));
        break;
      case 'games':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GameLobbyScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final color = banner['color'] as Color;

              return GestureDetector(
                onTap: () => _handleBannerTap(banner['action'] as String),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          banner['icon'] as IconData,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              banner['title'] as String,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              banner['subtitle'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: _currentPage == index ? 16 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.getPrimary(widget.isDark)
                    : AppColors.getTextSecondary(widget.isDark).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
