import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';
import 'upload_video_screen.dart';
import 'video_editor_screen.dart';
import 'music_picker_sheet.dart';

class CameraRecorderScreen extends StatefulWidget {
  const CameraRecorderScreen({super.key});

  @override
  State<CameraRecorderScreen> createState() => _CameraRecorderScreenState();
}

class _CameraRecorderScreenState extends State<CameraRecorderScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;

  bool _isCameraReady = false;
  bool _isRecording = false;
  bool _isInitializing = true;
  String? _errorMessage;

  FlashMode _flashMode = FlashMode.off;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  int _maxRecordSeconds = 60;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;
  double _selectedSpeed = 1.0;
  MusicTrack? _selectedMusic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCameras() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (cameraStatus.isDenied || cameraStatus.isPermanentlyDenied || micStatus.isDenied || micStatus.isPermanentlyDenied) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Camera and Microphone permissions required. Please grant access to record videos.';
        });
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'No camera found on this device.';
        });
        return;
      }
      int frontIndex =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
      await _setupController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Camera initialization failed: $e';
      });
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    final oldController = _controller;
    if (oldController != null) {
      _controller = null;
      await oldController.dispose();
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;

    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        setState(() => _errorMessage = 'Camera error: ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      final minZ = await controller.getMinZoomLevel();
      final maxZ = await controller.getMaxZoomLevel();

      if (mounted) {
        setState(() {
          _minZoom = minZ;
          _maxZoom = maxZ > 5.0 ? 5.0 : maxZ;
          _currentZoom = minZ;
          _isCameraReady = true;
          _isInitializing = false;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isCameraReady = false;
          _errorMessage = _cameraErrorMessage(e);
        });
      }
    }
  }

  String _cameraErrorMessage(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
        return 'Camera permission denied. Please grant camera access in Settings.';
      case 'AudioAccessDenied':
        return 'Microphone permission denied. Please grant microphone access in Settings.';
      default:
        return 'Camera error: ${e.description}';
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isRecording) return;
    setState(() {
      _isCameraReady = false;
      _isInitializing = true;
    });
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isCameraReady) return;
    final nextFlash = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await _controller!.setFlashMode(nextFlash);
      setState(() => _flashMode = nextFlash);
    } catch (_) {}
  }

  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_isCameraReady) return;
    try {
      await _controller!.setZoomLevel(zoom);
      setState(() => _currentZoom = zoom);
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_isCameraReady || _isRecording) return;
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordingDuration = Duration(seconds: timer.tick);
        });
        if (timer.tick >= _maxRecordSeconds) {
          _stopRecording();
        }
      });
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: ${e.description}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    String videoPath = '';
    if (_controller != null && _isRecording) {
      try {
        final XFile videoFile = await _controller!.stopVideoRecording();
        videoPath = videoFile.path;
      } catch (e) {
        debugPrint('Camera stop recording exception: $e');
        videoPath = 'recorded_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      }
    } else {
      videoPath = 'recorded_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }

    if (mounted) {
      setState(() => _isRecording = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => VideoEditorScreen(videoPath: videoPath),
        ),
      );
    }
  }

  void _openMusicPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MusicPickerSheet(
        onTrackSelected: (track) {
          setState(() {
            _selectedMusic = track;
          });
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraReady && _controller != null)
            _buildCameraPreview()
          else if (_isInitializing)
            _buildInitializingOverlay()
          else
            _buildErrorOverlay(),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          if (_isCameraReady)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: _buildSideControls(),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final controller = _controller!;
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return RotatedBox(
      quarterTurns: 0,
      child: CameraPreview(controller),
    );
  }

  Widget _buildInitializingOverlay() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 20),
          Text(
            'Starting camera...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.amberAccent, size: 64),
            const SizedBox(height: 20),
            Text(
              _errorMessage ?? 'Camera permission denied or unavailable.',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.security_rounded, color: AppColors.black),
                  label: const Text('Grant Access', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold)),
                  onPressed: _initCameras,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  label: const Text('Open Settings', style: TextStyle(color: Colors.white)),
                  onPressed: () => openAppSettings(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.black.withValues(alpha: 0.6), AppColors.transparent],
          ),
        ),
        child: Row(
          children: [
            _iconButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),

            // Music sound selector pill
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final primaryColor = AppColors.getPrimary(isDark);
                return GestureDetector(
                  onTap: _openMusicPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_note_rounded, color: primaryColor, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _selectedMusic != null ? _selectedMusic!.title : 'Add Sound',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const Spacer(),
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.live,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulseAnimation(
                      minScale: 0.5,
                      maxScale: 1.0,
                      duration: Duration(milliseconds: 900),
                      child: Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),
            _iconButton(
              icon: _flashMode == FlashMode.off
                  ? Icons.flash_off_rounded
                  : Icons.flash_on_rounded,
              onTap: _toggleFlash,
              highlighted: _flashMode == FlashMode.torch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_cameras.length > 1)
          _sideButton(
            icon: Icons.cameraswitch_rounded,
            label: 'Flip',
            onTap: _isRecording ? null : _switchCamera,
          ),
        const SizedBox(height: 16),

        // Speed Selector
        PopupMenuButton<double>(
          onSelected: (spd) => setState(() => _selectedSpeed = spd),
          itemBuilder: (ctx) => [0.3, 0.5, 1.0, 2.0, 3.0].map((s) {
            return PopupMenuItem(
              value: s,
              child: Text('${s}x Speed'),
            );
          }).toList(),
          child: _sideButton(
            icon: Icons.speed_rounded,
            label: '${_selectedSpeed}x',
            onTap: null,
          ),
        ),

        const SizedBox(height: 16),

        // Duration selector
        PopupMenuButton<int>(
          onSelected: (sec) => setState(() => _maxRecordSeconds = sec),
          itemBuilder: (ctx) => [15, 30, 60, 90].map((s) {
            return PopupMenuItem(
              value: s,
              child: Text('${s}s Max'),
            );
          }).toList(),
          child: _sideButton(
            icon: Icons.timer_rounded,
            label: '${_maxRecordSeconds}s',
            onTap: null,
          ),
        ),

        const SizedBox(height: 16),

        // Zoom Slider control
        Builder(
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = AppColors.getPrimary(isDark);
            return Column(
              children: [
                const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                SizedBox(
                  height: 100,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _currentZoom,
                      min: _minZoom,
                      max: _maxZoom,
                      activeColor: primaryColor,
                      onChanged: (z) => _setZoom(z),
                    ),
                  ),
                ),
                Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final recordProgress = _recordingDuration.inSeconds / _maxRecordSeconds;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.black.withValues(alpha: 0.8), AppColors.transparent],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 40, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: recordProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.live),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_maxRecordSeconds - _recordingDuration.inSeconds}s remaining',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              if (!_isRecording)
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const UploadVideoScreen(),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Icon(
                          Icons.video_library_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Gallery',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 72),

              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 72 : 80,
                  height: _isRecording ? 72 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    gradient: _isRecording
                        ? const LinearGradient(
                            colors: [AppColors.live, AppColors.danger],
                          )
                        : AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? AppColors.live : AppColors.primary)
                            .withValues(alpha: 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isRecording
                          ? const Icon(
                              Icons.stop_rounded,
                              color: Colors.white,
                              size: 32,
                              key: ValueKey('stop'),
                            )
                          : Icon(
                              Icons.fiber_manual_record,
                              color: AppColors.black,
                              size: 36,
                              key: const ValueKey('record'),
                            ),
                    ),
                  ),
                ),
              ),

              if (_isRecording)
                GestureDetector(
                  onTap: _stopRecording,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.live,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.live.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Next',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(width: 52),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            _isRecording
                ? 'Tap ■ to stop recording'
                : 'Tap ● to start recording (max ${_maxRecordSeconds}s)',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted
              ? primary.withValues(alpha: 0.85)
              : Colors.black38,
        ),
        child: Icon(icon, color: highlighted ? onPrimary : Colors.white, size: 22),
      ),
    );
  }

  Widget _sideButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black38,
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

