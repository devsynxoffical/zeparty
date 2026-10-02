import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/privacy_settings_provider.dart';
import '../../providers/svip_provider.dart';
import '../svip/svip_center_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<PrivacySettingsProvider>().initFromUser(auth.currentUser);
    });
  }

  void _showUnlockModal(BuildContext context, PrivacySettingItem item, int currentSvipLevel, bool isDark) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.getCard(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Colors.orangeAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Privilege Level Gated',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enabling "${item.title}" requires SVIP Tier ${item.requiredSvipLevel} or ${item.requiredNobleTier} Noble Status.',
              style: TextStyle(fontSize: 13, color: AppColors.getTextSecondary(isDark)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Current SVIP Level: SVIP $currentSvipLevel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.getTextPrimary(isDark))),
                        Text('Target: SVIP ${item.requiredSvipLevel} Required', style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.getPrimary(isDark)),
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SVIPCenterScreen()));
            },
            child: const Text('Upgrade SVIP Tier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final privacy = context.watch<PrivacySettingsProvider>();
    final svip = context.watch<SVIPProvider>();
    final auth = context.watch<AuthProvider>();
    final userSvipLevel = svip.currentLevel;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Privacy & Security Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.getPrimary(isDark).withValues(alpha: 0.2), const Color(0xFF1E1938)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getPrimary(isDark).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.amberAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Privacy & Visibility Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('Active Tier: SVIP $userSvipLevel • Live Real-Time Privacy', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text('FOLLOWERS & SOCIAL VISIBILITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark), letterSpacing: 1.2)),
          const SizedBox(height: 8),

          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[0], // hide_follow_list
            value: privacy.hideFollowList,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
            onToggle: (newVal) async {
              await privacy.updateFollowListPrivacy(newVal);
              auth.updateCurrentUser(auth.currentUser.copyWith(isPrivate: newVal));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: newVal ? const Color(0xFF1A237E) : const Color(0xFF004D40),
                    content: Text(
                      newVal
                          ? '🔒 Followers & Following list is now Private. Others will only see the total counts.'
                          : '🌐 Followers & Following list is now Public to everyone.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 20),
          Text('ROOM & STREAMING PRIVACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark), letterSpacing: 1.2)),
          const SizedBox(height: 8),

          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[1], // stealth_entry
            value: privacy.stealthRoomEntry,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),
          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[2], // anonymous_gifting
            value: privacy.anonymousGifting,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),

          const SizedBox(height: 20),
          Text('PROFILE & IDENTITY PRIVACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark), letterSpacing: 1.2)),
          const SizedBox(height: 8),

          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[3], // hide_online
            value: privacy.hideOnlinePresence,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),
          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[4], // hide_levels
            value: privacy.hideLevelBadges,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),
          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[6], // hide_cp_relationship
            value: privacy.hideCpRelationship,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),

          const SizedBox(height: 20),
          Text('MESSAGING & CONTACT PRIVACY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.getPrimary(isDark), letterSpacing: 1.2)),
          const SizedBox(height: 8),

          _buildPrivacyTile(
            context,
            item: PrivacySettingsProvider.privacyCatalog[5], // block_strangers_dm
            value: privacy.blockStrangersDm,
            userSvipLevel: userSvipLevel,
            isDark: isDark,
            privacy: privacy,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyTile(
    BuildContext context, {
    required PrivacySettingItem item,
    required bool value,
    required int userSvipLevel,
    required bool isDark,
    required PrivacySettingsProvider privacy,
    ValueChanged<bool>? onToggle,
  }) {
    final canEnable = privacy.canEnable(item.key, userSvipLevel);

    return Card(
      color: AppColors.getCard(isDark),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: value ? AppColors.getPrimary(isDark).withValues(alpha: 0.5) : AppColors.getBorder(isDark),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: canEnable ? AppColors.getPrimary(isDark).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
          child: Icon(item.icon, color: canEnable ? AppColors.getPrimary(isDark) : Colors.grey, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextPrimary(isDark)),
              ),
            ),
            if (item.isGated && !canEnable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 10, color: Colors.orangeAccent),
                    const SizedBox(width: 3),
                    Text('SVIP ${item.requiredSvipLevel}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          item.description,
          style: TextStyle(fontSize: 10.5, color: AppColors.getTextSecondary(isDark)),
        ),
        trailing: Switch(
          value: value,
          activeThumbColor: AppColors.getPrimary(isDark),
          onChanged: (newVal) {
            if (!canEnable) {
              _showUnlockModal(context, item, userSvipLevel, isDark);
            } else if (onToggle != null) {
              onToggle(newVal);
            } else {
              privacy.toggleSetting(item.key, userSvipLevel);
            }
          },
        ),
      ),
    );
  }
}
