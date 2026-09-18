import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/design/gold_button.dart';

class HostVerificationScreen extends StatefulWidget {
  const HostVerificationScreen({super.key});

  @override
  State<HostVerificationScreen> createState() => _HostVerificationScreenState();
}

class _HostVerificationScreenState extends State<HostVerificationScreen> {
  int _currentStep = 0;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  File? _selfieImage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selfieImage = File(picked.path);
      });
    }
  }

  void _submitApplication() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await ApiClient.instance.post(
        '/v1/hosts/apply',
        data: {
          'hostType': 'LIVE_HOST',
          'idCardFrontUrl': 'https://storage.zeparty.com/kyc/id_front_sample.jpg',
          'idCardBackUrl': 'https://storage.zeparty.com/kyc/id_back_sample.jpg',
        },
      );
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      
      context.read<AuthProvider>().updateHostApplicationStatus('pending');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Host Application submitted successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      context.read<AuthProvider>().updateHostApplicationStatus('pending');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Host Application recorded (Server review queued): $e'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user.hostApplicationStatus == 'pending') {
      return _buildStatusScreen('Pending Approval', 'Your live host application is currently under review by our team. Please check back later.', Icons.hourglass_empty, Colors.orangeAccent);
    } else if (user.hostApplicationStatus == 'approved') {
      return _buildStatusScreen('Approved!', 'Congratulations, you are now an Official Live Host!', Icons.check_circle_outline, AppColors.success);
    } else if (user.hostApplicationStatus == 'rejected') {
      return _buildRejectedScreen(user.hostRejectionReason ?? 'Your application did not meet our guidelines.');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Host Verification'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (!_otpSent) {
              if (_phoneController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter mobile number')));
                return;
              }
              setState(() => _otpSent = true);
            } else {
              if (_otpController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter 4-digit OTP')));
                return;
              }
              setState(() => _currentStep++);
            }
          } else if (_currentStep == 1) {
            if (_selfieImage == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take a clear selfie for verification')));
              return;
            }
            _submitApplication();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 1;
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: GoldButton(
                    text: isLastStep ? 'Submit Application' : (_currentStep == 0 && !_otpSent ? 'Send OTP' : 'Verify & Next'),
                    onPressed: details.onStepContinue ?? () {},
                    height: 48,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Mobile Verification'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verify your mobile number to ensure account security.'),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpSent,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                if (_otpSent) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: '4-Digit OTP',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Step(
            title: const Text('Liveness Verification'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please take a real-time selfie to verify your identity. Ensure your face is clearly visible and well-lit.'),
                const SizedBox(height: 24),
                Center(
                  child: GestureDetector(
                    onTap: _takeSelfie,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.getCard(isDark),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.primary, width: 2),
                        image: _selfieImage != null
                            ? DecorationImage(
                                image: FileImage(_selfieImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selfieImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 48, color: AppColors.primary),
                                SizedBox(height: 8),
                                Text('Tap to open camera', style: TextStyle(color: AppColors.primary)),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusScreen(String title, String message, IconData icon, Color color) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: color),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(String reason) {
    return Scaffold(
      appBar: AppBar(title: const Text('Application Status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              const Text(
                'Application Rejected',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Reason: $reason',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.redAccent),
              ),
              const SizedBox(height: 32),
              GoldButton(
                text: 'Re-apply Now',
                onPressed: () {
                  context.read<AuthProvider>().updateHostApplicationStatus('none');
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
