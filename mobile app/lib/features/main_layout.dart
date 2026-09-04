import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/glass_nav_bar.dart';
import 'home/home_screen.dart';
import 'social/social_feed_screen.dart';
import 'social/camera_recorder_screen.dart';
import 'social/upload_video_screen.dart';
import 'live/create_live_room_screen.dart';
import 'party_room/create_party_screen.dart';
import 'pk_battle/pk_battle_screen.dart';
import 'messages/inbox_screen.dart';
import 'profile/profile_screen.dart';
import 'auth/under_age_screen.dart';
import '../core/constants/dummy_data.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    SocialFeedScreen(),
    SizedBox.shrink(), // Create Gap — never actually shown
    InboxScreen(),
    ProfileScreen(),
  ];

  void _onTabSelected(int index) {
    if (index == 2) return; // centre button handled separately
    setState(() {
      _currentIndex = index;
    });
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
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()),
                        );
                      }
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
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreatePartyScreen(),
                          ),
                        );
                      }
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
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PKBattleScreen(pkBattle: DummyData.samplePkBattle),
                          ),
                        );
                      }
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
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _currentIndex,
        onTabSelected: _onTabSelected,
        onCreatePressed: _showCreateActionSheet,
      ),
    );
  }
}
