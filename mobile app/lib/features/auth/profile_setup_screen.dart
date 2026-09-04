import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../widgets/design/gold_button.dart';
import '../../providers/auth_provider.dart';
import 'under_age_screen.dart';
import '../main_layout.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Profile Picture
  String? _selectedImagePath;

  // Step 2: Username
  final _usernameController = TextEditingController();
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameStatusText;

  // Step 3: Gender
  String _selectedGender = 'Male';
  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  // Step 4: Date of Birth & Age Calculation
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _usernameController.text = currentUser.username;
    _checkUsername(currentUser.username);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _checkUsername(String username) async {
    if (username.trim().length < 3) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameStatusText = 'Username must be at least 3 characters';
      });
      return;
    }
    setState(() {
      _isCheckingUsername = true;
      _usernameStatusText = 'Checking availability...';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final available = await authProvider.checkUsernameAvailable(username);

    if (mounted) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
        _usernameStatusText = available ? 'Username available!' : 'Username already taken';
      });
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 20, now.month, now.day);
    final firstDate = DateTime(1920);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _finishProfileSetup() async {
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your Date of Birth')),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final calculatedAge = _calculateAge(_selectedDob!);

    final success = await authProvider.completeProfileOnboarding(
      username: _usernameController.text.trim(),
      gender: _selectedGender,
      dateOfBirth: _selectedDob!,
      avatarUrl: _selectedImagePath ?? authProvider.currentUser.avatarUrl,
    );

    if (success && mounted) {
      if (calculatedAge < 18) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UnderAgeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 1 && _isUsernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an available username')),
      );
      return;
    }
    if (_currentStep == 3 && _selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _finishProfileSetup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Create Profile'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Progress Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalSteps, (index) {
                  final isActive = index <= _currentStep;
                  return AnimatedContainer(
                    duration: AppAnimations.normal,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.getPrimary(isDark)
                          : AppColors.getBorder(isDark),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Step Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_currentStep == 0) _buildProfilePictureStep(isDark),
                      if (_currentStep == 1) _buildUsernameStep(isDark),
                      if (_currentStep == 2) _buildGenderStep(isDark),
                      if (_currentStep == 3) _buildDobStep(isDark),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation CTA Button
              GoldButton(
                text: _currentStep == _totalSteps - 1 ? 'COMPLETE PROFILE' : 'CONTINUE',
                onPressed: _nextStep,
                isLoading: authProvider.isLoading,
                height: 52,
                radius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 1: PROFILE PICTURE
  Widget _buildProfilePictureStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Choose Profile Picture',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add a photo so your audience and friends recognize you',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const SizedBox(height: 36),

        // Avatar Preview with Metallic/Gold Ring
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.getAccentGradient(isDark),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.getPrimary(isDark).withValues(alpha: 0.3),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 64,
                backgroundColor: AppColors.getCard(isDark),
                backgroundImage: _selectedImagePath != null
                    ? FileImage(File(_selectedImagePath!)) as ImageProvider
                    : const NetworkImage(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=300&q=80',
                      ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(isDark),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.getCard(isDark), width: 2),
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: AppColors.onGold(isDark: isDark),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_rounded),
              label: const Text('Camera'),
            ),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Gallery'),
            ),
          ],
        ),
      ],
    );
  }

  // STEP 2: USERNAME
  Widget _buildUsernameStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Choose Username',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your unique handle across live streams and videos',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const SizedBox(height: 36),

        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isUsernameAvailable == true
                  ? AppColors.success
                  : (_isUsernameAvailable == false ? AppColors.liveRed : AppColors.getBorder(isDark)),
              width: 1.2,
            ),
          ),
          child: TextField(
            controller: _usernameController,
            onChanged: (val) => _checkUsername(val),
            style: TextStyle(color: AppColors.getTextPrimary(isDark)),
            decoration: InputDecoration(
              hintText: 'Enter username',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: _isCheckingUsername
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_isUsernameAvailable == true
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                      : (_isUsernameAvailable == false
                          ? const Icon(Icons.cancel_rounded, color: AppColors.liveRed)
                          : null)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_usernameStatusText != null)
          AnimatedDefaultTextStyle(
            duration: AppAnimations.fast,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isUsernameAvailable == true
                  ? AppColors.success
                  : (_isUsernameAvailable == false ? AppColors.liveRed : AppColors.getTextSecondary(isDark)),
            ),
            child: Text(_usernameStatusText!),
          ),
      ],
    );
  }

  // STEP 3: GENDER
  Widget _buildGenderStep(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Select Gender',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Helps personalize your recommendation feed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const SizedBox(height: 28),

        ..._genderOptions.map((gender) {
          final isSelected = _selectedGender == gender;
          return GestureDetector(
            onTap: () => setState(() => _selectedGender = gender),
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.getPrimary(isDark).withValues(alpha: 0.12)
                    : AppColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.getPrimary(isDark)
                      : AppColors.getBorder(isDark),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    gender,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.getPrimary(isDark)
                          : AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle_rounded, color: AppColors.getPrimary(isDark)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // STEP 4: DATE OF BIRTH & AGE CALCULATION
  Widget _buildDobStep(bool isDark) {
    final int? calculatedAge = _selectedDob != null ? _calculateAge(_selectedDob!) : null;

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Required for community safety and age eligibility verification',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
        const SizedBox(height: 32),

        GestureDetector(
          onTap: () => _selectDateOfBirth(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.getCard(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(isDark)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.getPrimary(isDark),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      _selectedDob != null
                          ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                          : 'Select your birth date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedDob != null
                            ? AppColors.getTextPrimary(isDark)
                            : AppColors.getTextSecondary(isDark),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTextSecondary(isDark)),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        if (calculatedAge != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: calculatedAge >= 18
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.liveRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: calculatedAge >= 18 ? AppColors.success : AppColors.liveRed,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  calculatedAge >= 18 ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                  color: calculatedAge >= 18 ? AppColors.success : AppColors.liveRed,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calculated Age: $calculatedAge years old',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: calculatedAge >= 18 ? AppColors.success : AppColors.liveRed,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        calculatedAge >= 18
                            ? 'Eligible for all Live Broadcasting & Battle features! 🎉'
                            : 'Live streaming features require age 18+. Standard features remain accessible.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
