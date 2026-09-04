import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/agency_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/policy/agency_host_policy.dart';

class HostCenterScreen extends StatelessWidget {
  const HostCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final authUser = context.watch<AuthProvider>().currentUser;
    final agencyProv = context.watch<AgencyProvider>();

    final audioHost = agencyProv.getAudioHostByUserId(authUser.id) ?? agencyProv.audioHosts.first;
    final currentPolicy = AgencyHostPolicy.getLevelForDiamonds(audioHost.achievedDiamonds);
    final nextPolicy = AgencyHostPolicy.getNextLevel(currentPolicy.level);

    final progressPct = nextPolicy != null
        ? (audioHost.achievedDiamonds / nextPolicy.diamondTarget).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        title: const Text('Audio Host Center'),
        backgroundColor: AppColors.getBackground(isDark),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Host Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, Colors.deepPurple.shade900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(audioHost.userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                        child: Text('Level ${currentPolicy.level}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Agency: ${audioHost.agencyName} (ID: ${audioHost.agencyId})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),

                  // Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Achieved: ${audioHost.achievedDiamonds} 💎', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

            // Salary Breakdown Card (Shared Policy Module 14)
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('15-Day Cycle Salary & Policy Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Basic Total Salary:'),
                        Text('\$${currentPolicy.basicTotalSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Host Basic Salary (You):', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        Text('\$${currentPolicy.hostBasicSalaryUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Agency Share:', style: TextStyle(color: Colors.amberAccent)),
                        Text('\$${currentPolicy.agencySalaryUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amberAccent)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Special ID Bonus:', style: TextStyle(color: Colors.purpleAccent)),
                        Text(currentPolicy.specialIdBonus, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Valid Days Tracker Card (Audio Host 2-Hour Daily Unmuted Requirement)
            Card(
              color: AppColors.getCard(isDark),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Valid Days Tracker (2 Hours/Day Requirement)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(isDark))),
                    const SizedBox(height: 8),
                    const Text(
                      'Audio Hosts require 2 hours (120 mins) online & unmuted in room per valid day.',
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
                          'Completed: ${audioHost.completedValidDays} / ${currentPolicy.validDaysRequired}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(audioHost.isTodayValid ? Icons.check_circle_rounded : Icons.access_time_filled_rounded, color: audioHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            audioHost.isTodayValid
                                ? 'Today Status: VALID (${audioHost.dailyOnlineMinutes} mins completed)'
                                : 'Today Status: IN PROGRESS (${audioHost.dailyOnlineMinutes} / 120 mins)',
                            style: TextStyle(color: audioHost.isTodayValid ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
