import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/notification_provider.dart';
import '../../core/services/api_client.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadPreferences();
    });
  }

  Future<void> _togglePreference(String key, bool currentValue) async {
    final provider = context.read<NotificationProvider>();
    try {
      await provider.updatePreferences({key: !currentValue});
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update preference: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final prefs = provider.preferences;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
      ),
      body: provider.isPrefsLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Choose which notifications you wish to receive. Mandatory system and moderation notices cannot be disabled.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                _buildCategoryHeader('SOCIAL & COMMUNITY'),
                _buildToggleTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Social & Feed Alerts',
                  subtitle: 'Post likes, comments, and new followers',
                  value: prefs.social,
                  onChanged: () => _togglePreference('social', prefs.social),
                ),
                _buildToggleTile(
                  icon: Icons.live_tv_rounded,
                  title: 'Live Streaming & Room Alerts',
                  subtitle: 'When hosts you follow start live streaming',
                  value: prefs.live,
                  onChanged: () => _togglePreference('live', prefs.live),
                ),
                _buildToggleTile(
                  icon: Icons.sports_kabaddi_rounded,
                  title: 'PK Battle Alerts',
                  subtitle: 'PK battle invitations and results',
                  value: prefs.pk,
                  onChanged: () => _togglePreference('pk', prefs.pk),
                ),

                const SizedBox(height: 16),

                _buildCategoryHeader('ECONOMY & EVENTS'),
                _buildToggleTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Financial & Recharge',
                  subtitle: 'Recharge confirmation, withdrawals, and gifts received',
                  value: prefs.finance,
                  onChanged: () => _togglePreference('finance', prefs.finance),
                ),
                _buildToggleTile(
                  icon: Icons.celebration_outlined,
                  title: 'Platform Events & Contests',
                  subtitle: 'Seasonal events, CP contests, and leaderboards',
                  value: prefs.events,
                  onChanged: () => _togglePreference('events', prefs.events),
                ),
                _buildToggleTile(
                  icon: Icons.videogame_asset_outlined,
                  title: 'Mini-Game Alerts',
                  subtitle: 'Game tournaments, jackpot alerts, and rewards',
                  value: prefs.games,
                  onChanged: () => _togglePreference('games', prefs.games),
                ),

                const SizedBox(height: 16),

                _buildCategoryHeader('SUPPORT & MARKETING'),
                _buildToggleTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Customer Support Replies',
                  subtitle: 'Responses to your open help desk tickets',
                  value: prefs.support,
                  onChanged: () => _togglePreference('support', prefs.support),
                ),
                _buildToggleTile(
                  icon: Icons.campaign_outlined,
                  title: 'Promotions & Special Offers',
                  subtitle: 'VIP discounts, coin bonuses, and special deals',
                  value: prefs.marketing,
                  onChanged: () => _togglePreference('marketing', prefs.marketing),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.cyan,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: value ? AppColors.primary : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        value: value,
        activeColor: AppColors.primary,
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
