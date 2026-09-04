import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/animations/app_animations.dart';
import '../../core/repositories/backend_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../models/live_room_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/design/gold_button.dart';
import 'live_room_screen.dart';

class CreateLiveRoomScreen extends StatefulWidget {
  const CreateLiveRoomScreen({super.key});

  @override
  State<CreateLiveRoomScreen> createState() => _CreateLiveRoomScreenState();
}

class _CreateLiveRoomScreenState extends State<CreateLiveRoomScreen> {
  final _titleController = TextEditingController(text: '🔥 ZeParty Official Live Stream! Join In!');
  String _selectedCategory = 'Music';
  bool _isPrivate = false;
  final List<String> _categories = ['Music', 'Gaming', 'Chat', 'PK', 'Live'];

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;

  XFile? _coverImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      await Permission.camera.request();
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        int frontIndex = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
        await _setupCameraController(_cameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _setupCameraController(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (_) {}
    }
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Camera controller init error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _switchCamera() async {
    if (_cameras.length > 1) {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
      setState(() {
        _isCameraInitialized = false;
      });
      await _setupCameraController(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _coverImage = image;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick cover image: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'Start ZeParty Live Stream',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Camera Preview Box - Aspect Ratio & Cover Cropped
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primary.withValues(alpha: 0.5), width: 1.2),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.2, blur: 16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (_isCameraInitialized &&
                              _cameraController != null &&
                              _cameraController!.value.isInitialized) {
                            final cameraRatio = _cameraController!.value.aspectRatio;
                            final previewRatio = 1 / cameraRatio;

                            return SizedOverflowBox(
                              size: Size(constraints.maxWidth, constraints.maxHeight),
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxWidth / previewRatio,
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                            );
                          } else {
                            return Container(
                              color: AppColors.getCard(isDark),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.videocam_rounded, size: 52, color: primary),
                                  const SizedBox(height: 10),
                                  Text(
                                    _cameras.isEmpty
                                        ? 'Live Camera Ready (Simulation Mode)'
                                        : 'Initializing Camera...',
                                    style: TextStyle(
                                      color: AppColors.getTextSecondary(isDark),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    if (_cameras.length > 1)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.6),
                          radius: 20,
                          child: IconButton(
                            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
                            onPressed: _switchCamera,
                            tooltip: 'Flip Camera',
                          ),
                        ),
                      ),

                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.liveRed.withValues(alpha: 0.6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PulseAnimation(
                              minScale: 0.6,
                              maxScale: 1.0,
                              duration: Duration(milliseconds: 900),
                              child: Icon(Icons.fiber_manual_record, color: AppColors.liveRed, size: 12),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'PREVIEW ACTIVE',
                              style: TextStyle(color: AppColors.liveRed, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Cover Image Selector Box
            InkWell(
              onTap: _pickCoverImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.getCard(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _coverImage != null ? primary : AppColors.getBorder(isDark),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    _coverImage != null && File(_coverImage!.path).existsSync()
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(_coverImage!.path),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.add_a_photo_rounded, size: 24, color: primary),
                          ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _coverImage != null ? 'Cover Photo Selected' : 'Tap to select room cover image',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _coverImage != null ? _coverImage!.name : 'Choose from your Photo Library',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.getTextSecondary(isDark)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            CustomTextField(
              label: 'Stream Room Title',
              hint: 'Enter an engaging live stream title',
              controller: _titleController,
            ),

            const SizedBox(height: 20),

            Text(
              'Select Category',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: primary,
                  backgroundColor: AppColors.getCard(isDark),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.onPrimary(isDark: isDark) : AppColors.getTextSecondary(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: SwitchListTile(
                title: Text(
                  'Private Room',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
                subtitle: Text(
                  'Only invited users can enter',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(isDark),
                  ),
                ),
                value: _isPrivate,
                activeTrackColor: primary,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
            ),

            const SizedBox(height: 28),

            GoldButton(
              text: 'Go Live on ZeParty',
              icon: Icons.cell_tower_rounded,
              onPressed: () {
                final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
                final room = LiveRoomModel(
                  id: 'live_${DateTime.now().millisecondsSinceEpoch}',
                  title: _titleController.text.trim().isNotEmpty
                      ? _titleController.text.trim()
                      : '${currentUser.name}\'s Live Stream',
                  host: currentUser,
                  coverUrl: _coverImage != null
                      ? 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=600&q=80'
                      : currentUser.avatarUrl,
                  viewerCount: 1,
                  category: _selectedCategory,
                  isPrivate: _isPrivate,
                  startTime: DateTime.now(),
                );

                // Register live stream in backend repository so it appears in Public Live & Mine
                BackendRepository.instance.addLiveRoom(room);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (c) => LiveRoomScreen(room: room)),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
