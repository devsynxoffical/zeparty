import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/call_provider.dart';
import '../../core/utils/formatters.dart';
import '../../widgets/user_avatar.dart';

class VideoCallScreen extends StatefulWidget {
  final UserModel peerUser;

  const VideoCallScreen({super.key, required this.peerUser});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSelfCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CallProvider>().startCall(widget.peerUser, isVideo: true);
    });
  }

  Future<void> _initSelfCamera() async {
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        int frontIdx = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupCamera(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Call camera init: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _setupCamera(CameraDescription desc) async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
    }
    _cameraController = CameraController(desc, ResolutionPreset.low, enableAudio: false);
    try {
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Call camera setup error: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  void _switchCallCamera() async {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      setState(() => _isCameraInitialized = false);
      await _setupCamera(_cameras[_selectedCameraIndex]);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    context.read<CallProvider>().endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = context.watch<CallProvider>();

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          // Peer Full Screen Video Mock
          Positioned.fill(
            child: Image.network(
              widget.peerUser.avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(color: AppColors.darkBackground),
            ),
          ),
          Container(color: AppColors.black.withValues(alpha: 0.35)),

          // Self Picture-in-Picture Real Camera Feed
          Positioned(
            top: 50,
            right: 20,
            width: 110,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _isCameraInitialized && _cameraController != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 1,
                          height: _cameraController!.value.previewSize?.width ?? 1,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : Container(
                        color: AppColors.darkCardSecondary,
                        child: const Center(
                          child: Icon(Icons.person, color: AppColors.white, size: 36),
                        ),
                      ),
              ),
            ),
          ),

          // Top Header (Peer Name & Call Timer)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(imageUrl: widget.peerUser.avatarUrl, radius: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.peerUser.name,
                            style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            AppFormatters.formatDuration(Duration(seconds: call.callDurationSeconds)),
                            style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Actions (Mute, Camera Switch, End Call)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: call.isMuted ? AppColors.warmGold : AppColors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: Icon(call.isMuted ? Icons.mic_off : Icons.mic, color: call.isMuted ? AppColors.black : AppColors.white),
                    onPressed: () => call.toggleMute(),
                  ),
                ),
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.live,
                  child: IconButton(
                    icon: const Icon(Icons.call_end, color: AppColors.white, size: 32),
                    onPressed: () {
                      call.endCall();
                      Navigator.pop(context);
                    },
                  ),
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.cameraswitch, color: AppColors.white),
                    onPressed: _switchCallCamera,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
