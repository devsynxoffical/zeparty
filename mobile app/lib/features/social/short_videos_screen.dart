import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/repositories/backend_repository.dart';
import '../../models/short_video_model.dart';
import '../profile/profile_screen.dart';
import '../../widgets/comments_sheet.dart';

class ShortVideosScreen extends StatefulWidget {
  const ShortVideosScreen({super.key});

  @override
  State<ShortVideosScreen> createState() => _ShortVideosScreenState();
}

class _ShortVideosScreenState extends State<ShortVideosScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _discAnimController;
  final List<FloatingHeartAnimation> _floatingHearts = [];
  int _selectedTabIndex = 1; // 0 = Following, 1 = For You
  int _currentPageIndex = 0;
  final Map<String, bool> _followedCreators = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _discAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTapVideo(TapDownDetails details, ShortVideoModel video) {
    BackendRepository.instance.toggleVideoLike(video.id);
    final position = details.localPosition;
    setState(() {
      _floatingHearts.add(
        FloatingHeartAnimation(
          position: position,
          onComplete: () {
            setState(() {
              if (_floatingHearts.isNotEmpty) _floatingHearts.removeAt(0);
            });
          },
        ),
      );
    });
  }

  void _showCommentsBottomSheet(BuildContext context, ShortVideoModel video, bool isDark) {
    CommentsSheet.show(
      context,
      targetId: video.id,
      title: 'Video Comments',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final allVideos = BackendRepository.instance.shortVideos;
    final primary = AppColors.getPrimary(isDark);

    // Filter videos based on tab selection
    final videos = _selectedTabIndex == 0
        ? allVideos.where((v) => v.isLiked || v.creator.isVip).toList()
        : allVideos;

    final activeVideosList = videos.isEmpty ? allVideos : videos;

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // 9:16 Vertical Video Feed PageView
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: activeVideosList.length,
            onPageChanged: (index) {
              setState(() => _currentPageIndex = index);
            },
            itemBuilder: (context, index) {
              final video = activeVideosList[index];
              final isCurrent = index == _currentPageIndex;
              return GestureDetector(
                onDoubleTapDown: (details) => _onDoubleTapVideo(details, video),
                onDoubleTap: () {},
                child: _buildVideoPage(context, video, isDark, isCurrent),
              );
            },
          ),

          // Double Tap Floating Hearts Layer
          ..._floatingHearts,

          // TOP BAR: TIKTOK STYLE TABS (Following | For You) Centered Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedTabIndex = 0);
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(0);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Following',
                        style: TextStyle(
                          color: _selectedTabIndex == 0 ? Colors.white : Colors.white60,
                          fontSize: 16,
                          fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 0 ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedTabIndex = 1);
                    if (_pageController.hasClients) {
                      _pageController.jumpToPage(0);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'For You',
                        style: TextStyle(
                          color: _selectedTabIndex == 1 ? Colors.white : Colors.white60,
                          fontSize: 16,
                          fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: _selectedTabIndex == 1 ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPage(BuildContext context, ShortVideoModel video, bool isDark, bool isCurrent) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // PLAYABLE VIDEO PLAYER WIDGET
        PlayableVideoWidget(
          videoUrl: video.videoUrl,
          isSelected: isCurrent,
        ),

        // Gradient Shadow Overlay for Controls
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.black.withValues(alpha: 0.35),
                AppColors.transparent,
                AppColors.black.withValues(alpha: 0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // RIGHT ACTION BUTTONS SIDEBAR
        Positioned(
          right: 14,
          bottom: 100,
          child: Column(
            children: [
              // Creator Avatar & Follow Button
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen(user: video.creator)),
                      );
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(video.creator.avatarUrl),
                    ),
                  ),
                  Positioned(
                    bottom: -8,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _followedCreators[video.creator.id] = !(_followedCreators[video.creator.id] ?? false);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              (_followedCreators[video.creator.id] ?? false)
                                  ? '✔ Following @${video.creator.username}!'
                                  : 'Unfollowed @${video.creator.username}',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: (_followedCreators[video.creator.id] ?? false)
                              ? AppColors.liveGreen
                              : AppColors.getPrimary(isDark),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (_followedCreators[video.creator.id] ?? false) ? Icons.check_rounded : Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Like Action Button
              GestureDetector(
                onTap: () => BackendRepository.instance.toggleVideoLike(video.id),
                child: Column(
                  children: [
                    Icon(
                      video.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: video.isLiked ? AppColors.liveRed : Colors.white,
                      size: 34,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.likes}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Comment Action Button
              GestureDetector(
                onTap: () => _showCommentsBottomSheet(context, video, isDark),
                child: Column(
                  children: [
                    const Icon(Icons.mode_comment_rounded, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      '${video.comments}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Share Action Button
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📤 Video link copied! Share with your friends.')),
                  );
                },
                child: const Column(
                  children: [
                    Icon(Icons.share_rounded, color: Colors.white, size: 32),
                    SizedBox(height: 4),
                    Text('Share', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Spinning Sound Disc
              RotationTransition(
                turns: _discAnimController,
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    backgroundImage: NetworkImage(video.creator.avatarUrl),
                  ),
                ),
              ),
            ],
          ),
        ),

        // BOTTOM METADATA (Username, Caption, Music Track)
        Positioned(
          left: 16,
          right: 80,
          bottom: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${video.creator.username}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                video.caption,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      video.musicTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// Interactive Playable Video Controller Component
class PlayableVideoWidget extends StatefulWidget {
  final String videoUrl;
  final bool isSelected;

  const PlayableVideoWidget({
    super.key,
    required this.videoUrl,
    this.isSelected = true,
  });

  @override
  State<PlayableVideoWidget> createState() => _PlayableVideoWidgetState();
}

class _PlayableVideoWidgetState extends State<PlayableVideoWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(covariant PlayableVideoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
    } else if (widget.isSelected && _isInitialized && !_isPlaying) {
      _controller?.play();
      setState(() => _isPlaying = true);
    } else if (!widget.isSelected && _isPlaying) {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _initializePlayer() async {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;

    final String targetUrl = widget.videoUrl.isNotEmpty
        ? widget.videoUrl
        : 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

    try {
      if (targetUrl.startsWith('http://') || targetUrl.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(targetUrl));
      } else {
        final file = File(targetUrl);
        if (await file.exists()) {
          _controller = VideoPlayerController.file(file);
        } else {
          _controller = VideoPlayerController.networkUrl(
            Uri.parse('https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
          );
        }
      }

      await _controller!.initialize();
      _controller!.setLooping(true);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.isSelected) {
            _controller!.play();
            _isPlaying = true;
          }
        });
      }
    } catch (e) {
      debugPrint('Video Player Init Exception: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      setState(() {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
          _isPlaying = false;
        } else {
          _controller!.play();
          _isPlaying = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null) {
      return GestureDetector(
        onTap: _togglePlayPause,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 9,
                height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 16,
                child: VideoPlayer(_controller!),
              ),
            ),
            if (!_isPlaying)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, size: 72, color: Colors.white70),
                ),
              ),
          ],
        ),
      );
    }

    // Fallback Animated Live Video Texture Container
    return GestureDetector(
      onTap: _initializePlayer,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F172A), Color(0xFF020617), Colors.black],
          ),
        ),
        child: const Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseAnimation(
                    minScale: 0.85,
                    maxScale: 1.15,
                    duration: Duration(seconds: 2),
                    child: Icon(Icons.play_circle_fill_rounded, size: 72, color: AppColors.primary),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tap to Play Video Stream',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
