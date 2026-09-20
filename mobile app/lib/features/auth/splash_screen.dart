import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import 'auth_screen.dart';
import 'profile_setup_screen.dart';
import '../main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Guaranteed transition in ~1.2-1.5s — never hangs even if network or auth is slow
    await Future.any([
      Future.wait([
        authProvider.initFuture,
        Future.delayed(const Duration(milliseconds: 1200)),
      ]),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted || _navigated) return;
    _navigated = true;

    if (authProvider.isAuthenticated) {
      if (!authProvider.currentUser.profileCompleted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      }
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen(initialMode: AuthMode.login)),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final onGoldColor = AppColors.onGold(isDark: isDark);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.getAccentGradient(isDark),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(
                    size: 130,
                    showGlow: true,
                    showBorder: true,
                    borderRadius: 30,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ZEPARTY',
                    style: TextStyle(
                      color: onGoldColor,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Social Video & Live Streaming Platform',
                    style: TextStyle(
                      color: onGoldColor.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 54),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(onGoldColor),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
