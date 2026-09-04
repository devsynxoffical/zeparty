import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/social_provider.dart';
import '../../core/constants/dummy_data.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isPublishing = false;

  Future<void> _pickPostImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  Future<void> _publishPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) return;
    
    setState(() => _isPublishing = true);
    final mediaList = _selectedImage != null ? [_selectedImage!.path] : <String>[];
    context.read<SocialProvider>().addPost(
          _contentController.text.trim(),
          mediaList,
          DummyData.currentUser,
        );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Post'),
        actions: [
          _isPublishing
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: GoldButton(
                    text: 'Post',
                    height: 36,
                    expand: false,
                    onPressed: _publishPost,
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(imageUrl: DummyData.currentUser.avatarUrl, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: "What's happening in your live party world today?",
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Image.file(
                      File(_selectedImage!.path),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            const Divider(),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.photo_library_rounded, color: primary, size: 28),
                  onPressed: () => _pickPostImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: Icon(Icons.camera_alt_rounded, color: isDark ? AppColors.metallicGold : AppColors.metallicBlue, size: 28),
                  onPressed: () => _pickPostImage(ImageSource.camera),
                ),
                IconButton(
                  icon: Icon(Icons.emoji_emotions_rounded, color: primary, size: 28),
                  onPressed: () {
                    _contentController.text += ' 🔥✨';
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
