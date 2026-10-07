import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../core/utils/auth_guard.dart';
import '../widgets/glass_nav_bar.dart';
import 'home/home_screen.dart';
import 'social/social_feed_screen.dart';
import 'social/camera_recorder_screen.dart';
import 'social/upload_video_screen.dart';
import 'live/create_live_room_screen.dart';
import 'party_room/create_party_screen.dart';
import 'pk_battle/pk_battle_screen.dart';
import 'pk_battle/pk_match_screen.dart';
import 'profile/profile_screen.dart';
import 'messages/inbox_screen.dart';
import 'auth/under_age_screen.dart';
import 'live_host/apply_live_host_screen.dart';
import '../providers/live_host_provider.dart';
import '../providers/auth_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  static const Duration _exitTimeout = Duration(seconds: 2);

  void _onTabSelected(int index) {
    if (index == 2) return; // centre button handled separately
    if (index == 3) {
      AuthGuard.require(context, () {
        setState(() {
          _currentIndex = index;
        });
      }, reason: 'Sign in to access your direct messages');
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) return;

    // 1. If user is on an inner bottom navigation tab (Social, Inbox, Profile), return to Home Page (Index 0)
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
      return;
    }

    // 2. User is on Home Page (Index 0) - Manage Double-Back Exit Logic
    final now = DateTime.now();
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > _exitTimeout) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap back again to exit'),
          duration: _exitTimeout,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _lastBackPressTime = null;
      ScaffoldMessenger.of(context).clearSnackBars();
      SystemNavigator.pop();
    }
  }

  void _showCreateActionSheet() {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getCard(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.6)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.getBorderStrong(isDark).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Create & Broadcast',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimary(isDark),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCreateOption(
                    context: ctx,
                    icon: Icons.videocam_rounded,
                    label: 'Record',
                    color: AppColors.primaryBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CameraRecorderScreen()),
                      );
                    },
                  ),
                  _buildCreateOption(
                    context: ctx,
                    icon: Icons.upload_rounded,
                    label: 'Upload',
                    color: AppColors.deepBlue,
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
                      );
                    },
                  ),
                  _buildCreateOption(
                    context: ctx,
                    icon: Icons.sensors_rounded,
                    label: 'Go Live',
                    color: AppColors.liveRed,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!currentUser.isAgeEligible) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UnderAgeScreen()),
                        );
                        return;
                      }
                      
                      final liveHostProv = Provider.of<LiveHostProvider>(context, listen: false);
                      final isHost = currentUser.isHost || currentUser.hasLiveHostAccess || (liveHostProv.activeLiveHost?.status == 'Active');
                      if (!isHost) {
                        _showHostRequiredSheet(context, hostType: 'LIVE_HOST', featureName: 'Live Video Broadcasting');
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()),
                      );
                    },
                  ),
                  _buildCreateOption(
                    context: ctx,
                    icon: Icons.groups_rounded,
                    label: 'Party',
                    color: AppColors.getPrimary(isDark),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!currentUser.isAgeEligible) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UnderAgeScreen()),
                        );
                        return;
                      }

                      final liveHostProv = Provider.of<LiveHostProvider>(context, listen: false);
                      final isHost = currentUser.isHost || currentUser.hasLiveHostAccess || (liveHostProv.activeLiveHost?.status == 'Active');
                      if (!isHost) {
                        _showHostRequiredSheet(context, hostType: 'AUDIO_HOST', featureName: 'Audio Party Rooms');
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatePartyScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCreateOption(
                    context: ctx,
                    icon: Icons.flash_on_rounded,
                    label: 'Start PK',
                    color: AppColors.getPrimary(isDark),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!currentUser.isAgeEligible) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UnderAgeScreen()),
                        );
                        return;
                      }

                      final liveHostProv = Provider.of<LiveHostProvider>(context, listen: false);
                      final isHost = currentUser.isHost || currentUser.hasLiveHostAccess || (liveHostProv.activeLiveHost?.status == 'Active');
                      if (!isHost) {
                        _showHostRequiredSheet(context, hostType: 'LIVE_HOST', featureName: 'PK Battles');
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PKBattleScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showHostRequiredSheet(BuildContext context, {required String hostType, required String featureName}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181528) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Host Verification Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'To access $featureName, you must be a registered & verified ZeParty Host. Apply once to unlock streaming, audio lounges, and PK battles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.getTextSecondary(isDark),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.getPrimary(isDark),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApplyLiveHostScreen(initialHostType: hostType),
                    ),
                  );
                },
                child: const Text(
                  'Apply to Become a Host',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.getTextSecondary(isDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _handlePopInvoked(didPop);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const HomeScreen(),
            SocialFeedScreen(isScreenActive: _currentIndex == 1),
            const SizedBox.shrink(), // Create Gap — never actually shown
            const InboxScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: GlassNavBar(
          selectedIndex: _currentIndex,
          onTabSelected: _onTabSelected,
          onCreatePressed: () => AuthGuard.require(
            context,
            _showCreateActionSheet,
            reason: 'Sign in to create & broadcast content',
          ),
        ),
      ),
    );
  }
}
