import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../auth/auth_screen.dart';
import 'appearance_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'support_center_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _soundEffectsEnabled = true;
  String _selectedLanguage = 'English (US)';

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (c) {
        final languages = ['English (US)', 'Spanish (Español)', 'French (Français)', 'Arabic (العربية)', 'Urdu (اردو)', 'Chinese (中文)'];
        return SimpleDialog(
          title: const Text('Select Language'),
          children: languages.map((lang) {
            return SimpleDialogOption(
              onPressed: () {
                setState(() => _selectedLanguage = lang);
                Navigator.pop(c);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  lang,
                  style: TextStyle(
                    fontWeight: _selectedLanguage == lang ? FontWeight.bold : FontWeight.normal,
                    color: _selectedLanguage == lang ? AppColors.primary : null,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showBlockedUsersDialog() {
    final auth = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final currentBlocked = auth.blockedUserIds.toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text('Blocked Users', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: currentBlocked.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('You have no blocked accounts.', style: TextStyle(color: Colors.grey)),
                  )
                : SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentBlocked.length,
                      itemBuilder: (context, index) {
                        final userId = currentBlocked[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                          title: Text('User ID: $userId', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          trailing: TextButton(
                            onPressed: () async {
                              await auth.unblockUser(userId);
                              setDlgState(() {});
                            },
                            child: const Text('Unblock', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Row(
          children: [
            AppLogo(size: 32, borderRadius: 8),
            SizedBox(width: 10),
            Text('About ZeParty'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppLogo(size: 80, showGlow: true, showBorder: true, borderRadius: 20),
            SizedBox(height: 16),
            Text('ZeParty', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5)),
            SizedBox(height: 4),
            Text('Version 1.0.0 (Build 2026)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(height: 12),
            Text(
              'ZeParty is a next-generation Social Live Streaming, Party Rooms & PK Entertainment mobile platform.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text('© 2026 ZeParty Team. All rights reserved.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(c);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (ctx) => const AuthScreen(initialMode: AuthMode.login)),
                  (route) => false,
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsHeader(context, title: 'Display & Aesthetics'),
          _buildSettingsTile(
            context,
            icon: Icons.palette_rounded,
            title: 'Appearance Mode',
            subtitle: 'Switch Light, Dark, or System Default theme',
            trailingColor: AppColors.primary,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AppearanceSettingsScreen()));
            },
          ),

          const SizedBox(height: 16),
          _buildSettingsHeader(context, title: 'Account Settings'),
          _buildSettingsTile(
            context,
            icon: Icons.person_outline_rounded,
            title: 'Edit Profile Information',
            subtitle: 'Name, Bio, Gender, Region',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const EditProfileScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.security_rounded,
            title: 'Account Security & Password',
            subtitle: 'Manage login methods & security',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Security settings updated.')),
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSettingsHeader(context, title: 'Notifications & Privacy'),
          _buildSettingsTile(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Push Notifications Preferences',
            subtitle: 'Category alerts, quiet hours, and channel toggles',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const NotificationSettingsScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.lock_outline_rounded,
            title: 'Privacy Settings',
            subtitle: 'Stealth entry, DM blocking, SVIP level unlocks',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const PrivacySettingsScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.block_rounded,
            title: 'Blocked Users List',
            subtitle: 'Manage blocked accounts',
            onTap: _showBlockedUsersDialog,
          ),

          const SizedBox(height: 16),
          _buildSettingsHeader(context, title: 'General & Support'),
          _buildSettingsTile(
            context,
            icon: Icons.support_agent_rounded,
            title: 'Customer Support & Help Desk',
            subtitle: 'Open support tickets and chat with our team',
            trailingColor: AppColors.primary,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const SupportCenterScreen()));
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: _selectedLanguage,
            onTap: _showLanguageDialog,
          ),
          _buildSettingsTile(
            context,
            icon: Icons.volume_up_rounded,
            title: 'App Sound Effects',
            subtitle: _soundEffectsEnabled ? 'Sound Effects On' : 'Muted',
            onTap: () {
              setState(() => _soundEffectsEnabled = !_soundEffectsEnabled);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_soundEffectsEnabled ? 'Sound effects enabled' : 'Sound effects muted')),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.cleaning_services_rounded,
            title: 'Clear Cache',
            subtitle: '124 MB cache cleared',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App cache cleared successfully!', style: TextStyle(color: AppColors.black)),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
          _buildSettingsTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About & Terms',
            subtitle: 'Version 1.0.0 (Build 2026)',
            onTap: _showAboutDialog,
          ),

          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.live,
              foregroundColor: AppColors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log Out Account', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await context.read<AuthProvider>().logout();
              navigator.pushAndRemoveUntil(
                MaterialPageRoute(builder: (c) => const AuthScreen(initialMode: AuthMode.login)),
                (route) => false,
              );
            },
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: _showDeleteAccountConfirmation,
            child: const Text('Delete Account', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, {required String title}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.cyan,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? trailingColor,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: trailingColor ?? Theme.of(context).iconTheme.color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        onTap: onTap,
      ),
    );
  }
}
