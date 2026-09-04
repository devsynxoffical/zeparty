import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../main_layout.dart';

class UnderAgeScreen extends StatelessWidget {
  const UnderAgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.getPrimary(isDark).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 64,
                  color: AppColors.getPrimary(isDark),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Age Requirement',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Live streaming features are available only to users who are 18 or older.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can still enjoy short videos, social posts, messaging, and community feeds!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 48),
              GoldButton(
                text: 'CONTINUE TO FEED',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainLayout()),
                  );
                },
                height: 52,
                radius: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
