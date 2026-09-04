import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDSettingsScreen extends StatelessWidget {
  const BDSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bd = context.watch<BDCenterProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'BD Center Settings',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator Role & Region',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),
            PremiumCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  _buildSettingRow('BD Operator ID', bd.bdUserId, isDark),
                  _buildSettingRow('Assigned Region', bd.region, isDark),
                  _buildSettingRow('Country Assignment', bd.country, isDark),
                  _buildSettingRow('Operational Status', bd.status, isDark, isHighlight: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Authorized Permissions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),

            PremiumCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  _buildPermissionRow('Agent Invitation Authority', true, isDark),
                  _buildPermissionRow('Agency Management & Reassignment', true, isDark),
                  _buildPermissionRow('SVIP Operator Control', true, isDark),
                  _buildPermissionRow('Noble Aristocracy Control', true, isDark),
                  _buildPermissionRow('Financial Diamond Visibility', true, isDark),
                  _buildPermissionRow('Audit Log Access', true, isDark),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notification preferences
            Text(
              'BD Alerts & Notifications',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 10),

            PremiumCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  _buildPermissionRow('Instant Agent Invitation Response', true, isDark),
                  _buildPermissionRow('Salary Target Milestone Alerts', true, isDark),
                  _buildPermissionRow('High Diamond Volume Stream Alerts', false, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, bool isDark, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.greenAccent : AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String title, bool isEnabled, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 12, color: AppColors.getTextPrimary(isDark)),
            ),
          ),
          Icon(
            isEnabled ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isEnabled ? Colors.greenAccent : Colors.grey,
            size: 18,
          ),
        ],
      ),
    );
  }
}
