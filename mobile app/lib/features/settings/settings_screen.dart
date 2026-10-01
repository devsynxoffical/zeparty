import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../auth/auth_screen.dart';
import 'account_security_screen.dart';
import 'appearance_settings_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'support_center_screen.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';

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
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          if (isLoading) {
            auth.loadBlockedUsers().then((_) {
              if (ctx.mounted) {
                setDlgState(() {
                  isLoading = false;
                });
              }
            });
          }

          final blockedList = auth.blockedUsers.isNotEmpty
              ? auth.blockedUsers
              : auth.blockedUserIds.map((id) => UserModel(id: id, name: 'User $id', username: id, avatarUrl: '', email: '')).toList();

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text('Blocked Users List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: isLoading
                ? const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                : blockedList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text('You have no blocked accounts.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      )
                    : SizedBox(
                        width: double.maxFinite,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: blockedList.length,
                          separatorBuilder: (c, i) => const Divider(height: 12),
                          itemBuilder: (context, index) {
                            final u = blockedList[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: UserAvatar(imageUrl: u.avatarUrl, name: u.name, radius: 20),
                              title: Text(
                                u.name.isNotEmpty ? u.name : u.id,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '@${u.username.isNotEmpty ? u.username : u.id}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                onPressed: () async {
                                  await auth.unblockUser(u.id);
                                  setDlgState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Unblocked ${u.name}'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Unblock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
    final passwordController = TextEditingController();
    bool isObscured = true;
    bool isProcessing = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
                SizedBox(width: 8),
                Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '⏳ 3-Day Recovery Window',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your account will be removed from active users and stored in our secure deleted section for 3 days.\n\nIf you log in within 3 days, your account will be instantly restored. After 3 days, it will be permanently deleted.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter your password to verify ownership:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: isObscured,
                    decoration: InputDecoration(
                      hintText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(isObscured ? Icons.visibility_off : Icons.visibility, size: 18),
                        onPressed: () {
                          setDialogState(() {
                            isObscured = !isObscured;
                          });
                        },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        final enteredPassword = passwordController.text.trim();
                        if (enteredPassword.isEmpty) {
                          setDialogState(() {
                            localError = 'Password is required to confirm deletion.';
                          });
                          return;
                        }

                        setDialogState(() {
                          isProcessing = true;
                          localError = null;
                        });

                        final authProvider = context.read<AuthProvider>();
                        final success = await authProvider.deleteAccount(password: enteredPassword);

                        if (!dialogCtx.mounted) return;

                        if (success) {
                          Navigator.pop(dialogCtx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account deactivated. You have 3 days to recover your account by logging in.'),
                                backgroundColor: Colors.amber,
                                duration: Duration(seconds: 4),
                              ),
                            );
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (c) => const AuthScreen(initialMode: AuthMode.login)),
                              (route) => false,
                            );
                          }
                        } else {
                          setDialogState(() {
                            isProcessing = false;
                            localError = authProvider.errorMessage ?? 'Verification failed. Incorrect password.';
                          });
                        }
                      },
                child: isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm Deletion'),
              ),
            ],
          );
        },
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
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AccountSecurityScreen()));
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
