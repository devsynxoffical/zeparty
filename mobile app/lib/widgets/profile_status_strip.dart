import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/user_model.dart';
import '../providers/svip_provider.dart';
import '../features/profile/level_center_screen.dart';
import '../features/svip/svip_center_screen.dart';

/// Module 25 - Profile Status Strip (SVIP → SENDING/WEALTH → CHARM/RECEIVING → GAME → ACCOUNT LEVEL)
class ProfileStatusStrip extends StatelessWidget {
  final UserModel? user;

  const ProfileStatusStrip({
    super.key,
    this.user,
  });

  Color _getTierColor(int level, List<Color> palette) {
    if (level <= 0) return palette.first.withValues(alpha: 0.6);
    if (level < 10) return palette[0];
    if (level < 25) return palette[1];
    if (level < 50) return palette[2];
    return palette.last;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final svip = context.watch<SVIPProvider>();
    final currentUser = user;

    final svipLevel = svip.currentLevel;
    final isSvipActive = svipLevel > 0;
    final wealthLevel = currentUser?.wealthLevel ?? 0;
    final wealthXp = currentUser?.wealthXp ?? 0;
    final charmLevel = currentUser?.charmLevel ?? 0;
    final charmXp = currentUser?.charmXp ?? 0;
    final gameLevel = currentUser?.gameLevel ?? 0;
    final gameXp = currentUser?.gameXp ?? 0;
    final accountLevel = currentUser?.accountLevel ?? 0;
    final accountXp = currentUser?.accountXp ?? 0;

    // Palette configurations matching ZeParty theme & level strip specification
    final svipPalette = [const Color(0xFFFFD700), const Color(0xFFFFA000), const Color(0xFFFF6F00), const Color(0xFFFFE082)];
    final wealthPalette = [const Color(0xFF00E5FF), const Color(0xFF00B0FF), const Color(0xFF00838F), const Color(0xFFFFD700)];
    final charmPalette = [const Color(0xFFFF6D00), const Color(0xFFFF4081), const Color(0xFFE91E63), const Color(0xFFFFD700)];
    final gamePalette = [const Color(0xFFE040FB), const Color(0xFF7C4DFF), const Color(0xFF651FFF), const Color(0xFFFFD700)];
    final accountPalette = [const Color(0xFF00E676), const Color(0xFF00C853), const Color(0xFF43A047), const Color(0xFFFFD700)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getBorder(isDark),
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = ((constraints.maxWidth - 16) / 5).clamp(64.0, 100.0);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // 1. SVIP LEVEL CARD
                SizedBox(
                  width: itemWidth,
                  child: _buildStatusCard(
                    context: context,
                    levelText: isSvipActive ? 'SVIP $svipLevel' : 'Not Active',
                    label: 'SVIP',
                    subtitle: isSvipActive ? 'Privilege' : 'Locked',
                    icon: Icons.workspace_premium_rounded,
                    accentColor: _getTierColor(svipLevel, svipPalette),
                    progress: isSvipActive ? 1.0 : 0.0,
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SVIPCenterScreen()),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 4),

                // 2. SENDING / WEALTH CARD
                SizedBox(
                  width: itemWidth,
                  child: _buildStatusCard(
                    context: context,
                    levelText: 'Lv. $wealthLevel',
                    label: 'WEALTH',
                    subtitle: 'Sending',
                    icon: Icons.diamond_rounded,
                    accentColor: _getTierColor(wealthLevel, wealthPalette),
                    progress: (wealthXp / 1000000000).clamp(0.02, 1.0),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 0)),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 4),

                // 3. CHARM / RECEIVING CARD
                SizedBox(
                  width: itemWidth,
                  child: _buildStatusCard(
                    context: context,
                    levelText: 'Lv. $charmLevel',
                    label: 'CHARM',
                    subtitle: 'Receiving',
                    icon: Icons.favorite_rounded,
                    accentColor: _getTierColor(charmLevel, charmPalette),
                    progress: (charmXp / 10000).clamp(0.02, 1.0),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 1)),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 4),

                // 4. GAME LEVEL CARD
                SizedBox(
                  width: itemWidth,
                  child: _buildStatusCard(
                    context: context,
                    levelText: 'Lv. $gameLevel',
                    label: 'GAME',
                    subtitle: 'Game Level',
                    icon: Icons.sports_esports_rounded,
                    accentColor: _getTierColor(gameLevel, gamePalette),
                    progress: (gameXp / 5000).clamp(0.02, 1.0),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 2)),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 4),

                // 5. ACCOUNT LEVEL CARD
                SizedBox(
                  width: itemWidth,
                  child: _buildStatusCard(
                    context: context,
                    levelText: 'Lv. $accountLevel',
                    label: 'ACCOUNT',
                    subtitle: 'Account Level',
                    icon: Icons.stars_rounded,
                    accentColor: _getTierColor(accountLevel, accountPalette),
                    progress: (accountXp / 20000).clamp(0.02, 1.0),
                    isDark: isDark,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LevelCenterScreen(initialTab: 3)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required BuildContext context,
    required String levelText,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required double progress,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF191428) : AppColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon + Level Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 12, color: accentColor),
                  const SizedBox(width: 2.5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        levelText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Title Label (SVIP, WEALTH, CHARM, GAME, ACCOUNT)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: AppColors.getTextPrimary(isDark),
                  ),
                ),
              ),

              const SizedBox(height: 2),

              // Subtitle
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 8.5,
                    color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.7),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Level Progress Bar
              Container(
                height: 3.5,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? const Color(0xFF2B243B) : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
