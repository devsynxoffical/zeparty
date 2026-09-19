import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import 'upload_video_screen.dart';

class VideoEditorScreen extends StatefulWidget {
  final String videoPath;
  const VideoEditorScreen({super.key, required this.videoPath});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  double _playbackSpeed = 1.0;
  final List<double> _speeds = [0.3, 0.5, 1.0, 2.0, 3.0];
  String _selectedFilter = 'Normal';
  final List<String> _filters = ['Normal', 'Vivid', 'Vintage', 'Mono', 'Warm', 'Cool'];

  double _trimStart = 0.0;
  double _trimEnd = 1.0;
  bool _isPlaying = true;
  double _videoProgress = 0.0;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  Future<void> _initVideoPlayer() async {
    try {
      if (widget.videoPath.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoPath));
      } else {
        _videoController = VideoPlayerController.file(File(widget.videoPath));
      }
      await _videoController?.initialize();
      _videoController?.setLooping(true);
      _videoController?.setPlaybackSpeed(_playbackSpeed);
      await _videoController?.play();

      _videoController?.addListener(() {
        if (mounted && _videoController != null && _videoController!.value.isInitialized) {
          final pos = _videoController!.value.position.inMilliseconds;
          final dur = _videoController!.value.duration.inMilliseconds;
          setState(() {
            _videoProgress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
            _isPlaying = _videoController!.value.isPlaying;
          });
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Video editor player error: $e');
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController?.pause();
      } else {
        _videoController?.play();
      }
    } else {
      setState(() {
        _isPlaying = !_isPlaying;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        foregroundColor: AppColors.getTextPrimary(isDark),
        title: Text(
          'Video Preview & Edit',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UploadVideoScreen(videoPath: widget.videoPath),
                ),
              );
            },
            child: Text(
              'NEXT',
              style: TextStyle(
                color: primary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Video Preview Aspect Box
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : AppColors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.2),
                          boxShadow: AppColors.primaryGlow(isDark, alpha: 0.2, blur: 16),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_videoController != null && _videoController!.value.isInitialized)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: SizedOverflowBox(
                                  size: Size.infinite,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            // Animated Play/Pause overlay icon
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isPlaying ? 0.3 : 0.9,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  size: 44,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Video Progress Slider
                            Positioned(
                              bottom: 34,
                              left: 12,
                              right: 12,
                              child: LinearProgressIndicator(
                                value: _videoProgress,
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(primary),
                                minHeight: 3,
                              ),
                            ),

                            Positioned(
                              bottom: 10,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '🔊 Audio On • Filter: $_selectedFilter | Speed: ${_playbackSpeed}x',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // EDITOR CONTROLS PANEL
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trim Bar Slider Simulation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trim Timeline',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
                      ),
                      Text(
                        '${(_trimStart * 15).toInt()}s - ${(_trimEnd * 15).toInt()}s',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(_trimStart, _trimEnd),
                    onChanged: (values) {
                      setState(() {
                        _trimStart = values.start;
                        _trimEnd = values.end;
                      });
                    },
                    activeColor: primary,
                    inactiveColor: AppColors.getBorder(isDark),
                  ),

                  const SizedBox(height: 6),

                  // Speed Selectors (Horizontal Scrollable ListView)
                  Text(
                    'Playback Speed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _speeds.map((s) {
                        final isSelected = _playbackSpeed == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${s}x'),
                            selected: isSelected,
                            selectedColor: primary,
                            backgroundColor: AppColors.getCard(isDark),
                            labelStyle: TextStyle(
                              color: isSelected ? onPrimary : AppColors.getTextSecondary(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() => _playbackSpeed = s),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Filters Selector (Horizontal Scrollable ListView)
                  Text(
                    'Video Filters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _filters.map((f) {
                        final isSelected = _selectedFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f),
                            selected: isSelected,
                            selectedColor: primary,
                            backgroundColor: AppColors.getCard(isDark),
                            labelStyle: TextStyle(
                              color: isSelected ? onPrimary : AppColors.getTextSecondary(isDark),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setState(() => _selectedFilter = f),
                          ),
                        );
                      }).toList(),
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
}
