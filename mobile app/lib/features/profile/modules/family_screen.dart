import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text('Family Feature Unavailable', style: TextStyle(color: AppColors.getTextPrimary(isDark))),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block_rounded, size: 80, color: Colors.orangeAccent),
              const SizedBox(height: 16),
              Text(
                'Family Feature Has Been Retired',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The Family feature is no longer supported on ZeParty. Please use the Relationship module for your personal bonds and team-ups.',
                style: TextStyle(color: AppColors.getTextSecondary(isDark), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
