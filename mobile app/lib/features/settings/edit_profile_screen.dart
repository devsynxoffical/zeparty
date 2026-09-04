import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _regionController;

  String _selectedGender = 'Not Specified';
  DateTime? _selectedBirthday;
  String? _coverImagePath;
  String? _avatarImagePath;
  bool _isSaving = false;

  late String _initialName;
  late String _initialBio;
  late String _initialRegion;
  late String _initialGender;

  final List<String> _selectedTags = [];

  static const List<String> _availableTags = [
    'Music 🎵',
    'Gaming 🎮',
    'Dancing 💃',
    'Streaming 🎙️',
    'Chatting 💬',
    'Anime 🌸',
    'Fashion 👠',
    'Travel ✈️',
    'Fitness 🏋️',
  ];

  static const List<String> _prohibitedWords = [
    'admin',
    'administrator',
    'moderator',
    'official',
    'support',
    'system',
    'zeparty',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _initialName = user.name;
    _initialBio = user.bio;
    _initialRegion = user.region;
    _initialGender = user.gender.isEmpty ? 'Not Specified' : user.gender;

    _nameController = TextEditingController(text: _initialName);
    _bioController = TextEditingController(text: _initialBio);
    _regionController = TextEditingController(text: _initialRegion);
    _selectedGender = _initialGender;
    _selectedBirthday = DateTime.now().subtract(Duration(days: user.age * 365));
    _selectedTags.addAll(['Music 🎵', 'Streaming 🎙️']);

    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _regionController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _nameController.text.trim() != _initialName.trim() ||
        _bioController.text.trim() != _initialBio.trim() ||
        _regionController.text.trim() != _initialRegion.trim() ||
        _selectedGender != _initialGender ||
        _coverImagePath != null ||
        _avatarImagePath != null;
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _avatarImagePath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Avatar image selected! Tap Save to apply.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick avatar: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _coverImagePath = pickedFile.path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🖼️ Profile cover image selected!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick cover image: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Change Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoverOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Change Profile Cover', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: const Text('Take Cover Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_rounded, color: Colors.amberAccent),
              title: const Text('Choose Cover from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickCoverImage(ImageSource.gallery);
              },
            ),
            if (_coverImagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove Cover Image', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _coverImagePath = null);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  bool _containsProhibitedWords(String text) {
    final lower = text.toLowerCase();
    for (final word in _prohibitedWords) {
      if (lower.contains(word)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges || _isSaving) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final region = _regionController.text.trim();

    if (name.length < 2 || name.length > 25) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display Name must be between 2 and 25 characters.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (_containsProhibitedWords(name) || _containsProhibitedWords(bio)) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Security & Title Filter Alert'),
          content: const Text(
            'Your proposed Name or Bio contains prohibited terms or reserved Admin titles ("admin", "official", "support", etc.). Please choose a different title.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (_avatarImagePath != null) {
      auth.updateAvatar(_avatarImagePath!);
    }

    auth.updateProfile(
      name: name,
      bio: bio,
      gender: _selectedGender,
      region: region.isEmpty ? 'Global' : region,
    );

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Profile updated successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pop(context);
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text('You have unsaved changes to your profile. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Continue Editing', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = AppColors.getCard(isDark);
    final borderColor = AppColors.getBorder(isDark);
    final primaryText = AppColors.getTextPrimary(isDark);
    final secondaryText = AppColors.getTextSecondary(isDark);

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscardChanges();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(isDark),
        appBar: AppBar(
          title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.getBackground(isDark),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: _hasChanges ? AppColors.primary : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Profile Cover Header ───
              GestureDetector(
                onTap: () => _showCoverOptions(context, isDark),
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E1A47), Color(0xFF120F24)],
                    ),
                    image: _coverImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_coverImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Edit Cover', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── Avatar Header ───
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showAvatarOptions(context, isDark),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatarImagePath != null
                              ? CircleAvatar(
                                  radius: 46,
                                  backgroundImage: FileImage(File(_avatarImagePath!)),
                                )
                              : UserAvatar(imageUrl: user.avatarUrl, radius: 46),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _showAvatarOptions(context, isDark),
                      child: const Text('Change Avatar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── User Profile Editable Fields ───
              Text('Personal Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryText)),
              const SizedBox(height: 12),

              // Display Name
              TextField(
                controller: _nameController,
                maxLength: 25,
                decoration: InputDecoration(
                  labelText: 'Display Name (Nickname)',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Personal Note / Bio
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Personal Note / Bio',
                  hintText: 'Share a note about yourself...',
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),

              // Region / Country
              TextField(
                controller: _regionController,
                decoration: InputDecoration(
                  labelText: 'Country / Region',
                  prefixIcon: const Icon(Icons.public),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  helperText: 'Region changes follow product account policy',
                ),
              ),
              const SizedBox(height: 16),

              // Gender Selection
              Text('Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Female', 'Male', 'Non-Binary', 'Not Specified'].map((g) {
                  final isSelected = _selectedGender == g;
                  return ChoiceChip(
                    label: Text(g),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : primaryText),
                    onSelected: (val) {
                      if (val) setState(() => _selectedGender = g);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Birthday Picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_rounded, color: Colors.pinkAccent),
                title: const Text('Birthdate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  _selectedBirthday != null
                      ? '${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}'
                      : 'Select Birthdate',
                  style: TextStyle(color: secondaryText, fontSize: 12),
                ),
                trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                onTap: _selectBirthday,
              ),

              const SizedBox(height: 16),

              // Interest Tags Multi-Select
              Text('Interest Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: Colors.amberAccent,
                    labelStyle: TextStyle(color: isSelected ? Colors.black : primaryText, fontSize: 11),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // ─── Prohibited / Server-Protected Fields Section ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shield_rounded, color: Colors.orangeAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Server-Protected Fields (Read-Only)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'User ID, financial balances, levels, and identity credentials are permanent server-authoritative fields.',
                      style: TextStyle(fontSize: 10.5, color: secondaryText),
                    ),
                    const SizedBox(height: 12),
                    _buildReadOnlyRow('User ID', user.id, isDark),
                    _buildReadOnlyRow('Coins Balance', '${AppFormatters.formatNumber(user.coins)} 🪙', isDark),
                    _buildReadOnlyRow('Diamonds Count', '${AppFormatters.formatNumber(user.diamonds)} 💎', isDark),
                    _buildReadOnlyRow('Wealth / Charm / Game Levels', 'Lv. ${user.wealthLevel} / Lv. ${user.charmLevel} / Lv. ${user.gameLevel}', isDark),
                    _buildReadOnlyRow('SVIP Tier', 'SVIP 11', isDark),
                    _buildReadOnlyRow('Agency Affiliation', user.agencyName ?? 'Independent', isDark),
                    _buildReadOnlyRow('Registration Date', '2026-01-01', isDark),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
            ),
          ),
        ],
      ),
    );
  }
}
