import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/live_host_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/policy/live_host_policy.dart';
import '../live/create_live_room_screen.dart';
import '../settings/support_center_screen.dart';

class LiveHostCenterScreen extends StatelessWidget {
  const LiveHostCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final liveHostProv = context.watch<LiveHostProvider>();

    final liveHost = liveHostProv.activeLiveHost;

    if (liveHost == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Host Center')),
        body: const Center(child: Text('No active Direct Live Host profile found.')),
      );
    }

    final currentPolicy = LiveHostPolicy.getLevelForDiamonds(liveHost.achievedDiamonds);
    final nextPolicy = LiveHostPolicy.getNextLevel(currentPolicy.level);

    final progressPct = nextPolicy != null
        ? (liveHost.achievedDiamonds / nextPolicy.diamondTarget).clamp(0.0, 1.0)
        : 1.0;

    final isEligibleForPay = LiveHostPolicy.isTargetEligible(
      achievedDiamonds: liveHost.achievedDiamonds,
      completedValidDays: liveHost.completedValidDays,
      targetLevel: currentPolicy.level,
    );

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Direct Live Host Center'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Colors.amberAccent),
            tooltip: 'Policy Table',
            onPressed: () => _showPolicyTableDialog(context, isDark),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Colors.redAccent),
            tooltip: 'Go Live',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen())),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Host Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFFFF416C).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: NetworkImage(liveHost.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    liveHost.displayName,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                              ],
                            ),
                            Text('ID: ${liveHost.userId} • Live Host ID: ${liveHost.liveHostId}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            Text('Region: ${liveHost.countryCode} • Status: ${liveHost.status}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                        child: Text('Level ${currentPolicy.level}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Achieved: ${liveHost.achievedDiamonds} 💎', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(nextPolicy != null ? 'Next Target: ${nextPolicy.diamondTarget} 💎' : 'MAX LEVEL', style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressPct,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Direct Salary Policy Breakdown Card
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Direct Salary Policy (100% Direct Payout)',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 18, color: Colors.amberAccent),
                          onPressed: () => _showPolicyTableDialog(context, isDark),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Direct Basic Salary:'),
                        Text('\$${currentPolicy.basicSalaryUsd.toStringAsFixed(2)} USD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Target Settlement Eligibility:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isEligibleForPay ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEligibleForPay ? 'ELIGIBLE' : 'IN PROGRESS',
                            style: TextStyle(color: isEligibleForPay ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Paid 100% directly by platform to host wallet. ZERO agency commission deducted.',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Verified Live Time Tracker Card (Direct Live Host 1-Hour Daily Streaming Requirement)
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verified Live Streaming Time (1 Hour/Day Requirement)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 6),
                    const Text(
                      'Direct Live Hosts require 1 verified hour (60 mins) of live video streaming per valid day (vs Audio Hosts requiring 2 hours).',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Required Valid Days: ${currentPolicy.validDaysRequired} days',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Completed: ${liveHost.completedValidDays} / ${currentPolicy.validDaysRequired}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(liveHost.isTodayValid ? Icons.check_circle_rounded : Icons.access_time_filled_rounded, color: liveHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            liveHost.isTodayValid
                                ? 'Today Status: VALID (${liveHost.dailyLiveMinutes} mins streaming completed)'
                                : 'Today Status: IN PROGRESS (${liveHost.dailyLiveMinutes} / 60 mins)',
                            style: TextStyle(color: liveHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_alarm_rounded),
                      label: const Text('Simulate +15 Mins Live Stream'),
                      style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                      onPressed: () {
                        liveHostProv.addLiveStreamingMinutes(15);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📹 15 mins live streaming time added!'), backgroundColor: Colors.green));
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Live Host Wallet Card
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Host Direct Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pending Salary', style: TextStyle(fontSize: 11, color: Colors.orange)),
                                  Text('\$${liveHost.pendingSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Available Salary', style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                                  Text('\$${liveHost.availableSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.greenAccent)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                          onPressed: () => _showLiveHostWithdrawDialog(context, liveHostProv, authUser.id),
                          child: const Text('Withdraw'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Grid Options
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildGridOption(context, 'Go Live', Icons.videocam_rounded, Colors.redAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateLiveRoomScreen()));
                }),
                _buildGridOption(context, 'Schedule', Icons.calendar_month_rounded, Colors.blueAccent, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📅 Live Stream Schedule Manager opened.')));
                }),
                _buildGridOption(context, 'Target Details', Icons.bar_chart_rounded, Colors.amberAccent, () {
                  _showPolicyTableDialog(context, isDark);
                }),
                _buildGridOption(context, 'Wallet', Icons.account_balance_wallet_rounded, Colors.greenAccent, () {
                  _showLiveHostWithdrawDialog(context, liveHostProv, authUser.id);
                }),
                _buildGridOption(context, 'Rules', Icons.gavel_rounded, Colors.purpleAccent, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📜 Live Host Rules & Guidelines opened.')));
                }),
                _buildGridOption(context, 'Support', Icons.support_agent_rounded, Colors.orangeAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const SupportCenterScreen()));
                }),
                _buildGridOption(context, 'Settings', Icons.settings_rounded, Colors.grey, () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚙️ Live Host Payment Settings opened.')));
                }),
                _buildGridOption(context, 'Policy Table', Icons.table_view_rounded, Colors.tealAccent, () {
                  _showPolicyTableDialog(context, isDark);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridOption(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.9))),
          ],
        ),
      ),
    );
  }

  void _showPolicyTableDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.amberAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Official Live Host Policy Table',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 36,
              columnSpacing: 10,
              columns: const [
                DataColumn(label: Text('Level', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('Diamonds', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('Days', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                DataColumn(label: Text('Salary', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
              rows: LiveHostPolicy.policyTable.map((l) {
                return DataRow(cells: [
                  DataCell(Text('Lv ${l.level}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                  DataCell(Text('${l.diamondTarget}', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  DataCell(Text('${l.validDaysRequired}d', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  DataCell(Text('\$${l.basicSalaryUsd.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11))),
                ]);
              }).toList(),
            ),
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(d), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLiveHostWithdrawDialog(BuildContext context, LiveHostProvider prov, String userId) {
    final amtController = TextEditingController();
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live Host Direct Withdrawal',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Amount (USD)', labelStyle: TextStyle(color: Colors.white70)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Security PIN (Default: 1234)', labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final amt = double.tryParse(amtController.text.trim()) ?? 0.0;
              final pin = pinController.text.trim();
              final err = prov.requestWithdrawal(amount: amt, channel: 'Direct Bank Transfer', pin: pin, actorUserId: userId);
              Navigator.pop(d);
              if (err == null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎉 Live Host Direct withdrawal of \$$amt requested!'), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ $err'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Withdraw Funds', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
