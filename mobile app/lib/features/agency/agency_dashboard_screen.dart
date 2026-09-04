import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/host_agency_provider.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/design/premium_card.dart';
import '../withdrawal/withdrawal_screen.dart';

class AgencyDashboardScreen extends StatelessWidget {
  const AgencyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final onPrimary = AppColors.onPrimary(isDark: isDark);
    final agency = context.watch<HostAgencyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency Management Center'),
        actions: [
          IconButton(
            icon: Icon(Icons.bar_chart_rounded, color: primaryColor),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics report coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agency Overview Card (Gradient)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.28, blur: 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 36, showBorder: true, borderRadius: 10),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ZeParty Star Network Agency',
                              style: TextStyle(color: onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Agency ID: ZP-884920 • Commission: 15%',
                              style: TextStyle(color: onPrimary.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 0.8),
                        ),
                        child: Text(
                          'VERIFIED ✓',
                          style: TextStyle(color: onPrimary, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Commission', style: TextStyle(color: onPrimary.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(
                              '\$${agency.commissionEarned.toStringAsFixed(2)}',
                              style: TextStyle(color: onPrimary, fontWeight: FontWeight.w900, fontSize: 24),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                        label: const Text('Cashout', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (c) => const WithdrawalScreen()));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Stats Row
            Row(
              children: [
                _buildMiniStat(context, label: 'Hosts', value: '${agency.managedHosts.length}', icon: Icons.people_rounded, color: primaryColor),
                const SizedBox(width: 12),
                _buildMiniStat(context, label: 'This Month', value: '\$2,340', icon: Icons.trending_up_rounded, color: isDark ? AppColors.metallicGold : AppColors.metallicBlue),
                const SizedBox(width: 12),
                _buildMiniStat(context, label: 'Streams', value: '187', icon: Icons.live_tv_rounded, color: isDark ? AppColors.lightGold : AppColors.lightBlue),
              ],
            ),

            const SizedBox(height: 24),

            // Host List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Managed Hosts (${agency.managedHosts.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Invite Host', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showInviteHostDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Host Cards
            agency.managedHosts.isEmpty
                ? _buildEmptyHostsState(context)
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: agency.managedHosts.length,
                    itemBuilder: (context, index) {
                      final host = agency.managedHosts[index];
                      return _buildHostCard(context, host, agency, index);
                    },
                  ),

            const SizedBox(height: 24),

            // Agency Rules Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Agency Rules & Policies',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRule('Hosts must stream a minimum of 5 hours/week'),
                  _buildRule('Commission is distributed every Monday'),
                  _buildRule('Violations may result in host removal'),
                  _buildRule('Agency must maintain ≥ 3 active hosts'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, {required String label, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: PremiumCard(
        padding: const EdgeInsets.all(12),
        radius: 14,
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHostCard(BuildContext context, dynamic host, HostAgencyProvider agency, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? [AppColors.warmGold, AppColors.metallicGold, AppColors.lightGold, AppColors.goldHighlight]
        : [AppColors.royalBlue, AppColors.metallicBlue, AppColors.lightBlue, AppColors.darkNavyAccent];
    final color = colors[index % colors.length];

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          UserAvatar(imageUrl: host.avatarUrl, radius: 24, showVipFrame: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(host.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('@${host.username}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildHostStat('${(48 - index * 3)}h', '⏱️ streamed', color),
                    const SizedBox(width: 12),
                    _buildHostStat('${(12400 - index * 800)}', '💎 gifts', AppColors.getPrimary(isDark)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.message_rounded, color: AppColors.primary, size: 20),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Opening chat with ${host.name}...')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.live, size: 20),
                onPressed: () => _confirmRemoveHost(context, host, agency),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostStat(String value, String label, Color color) {
    return Row(
      children: [
        Text(label.split(' ').first, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildEmptyHostsState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.group_add_rounded, size: 60, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text('No hosts yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Invite streamers to join your agency', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  void _showInviteHostDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Invite Host', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter the ZeParty user ID or username to invite them as a host to your agency.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '@username or User ID',
                prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invitation sent to ${controller.text}! 📨')),
                );
              }
            },
            child: const Text('Send Invite', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmRemoveHost(BuildContext context, dynamic host, HostAgencyProvider agency) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Host?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove ${host.name} from your agency? This cannot be undone.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.live,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              agency.removeHostFromAgency(host.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${host.name} removed from agency.')),
              );
            },
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
