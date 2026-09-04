import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDTargetScreen extends StatelessWidget {
  const BDTargetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColors.getPrimary(isDark);
    final bd = context.watch<BDCenterProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'Target & KPI Tracker',
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
            // Master Target Gauge Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.getAccentGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'August 2026 Milestone Progress',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(bd.targetProgress * 100).toStringAsFixed(1)}% Completed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: bd.targetProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Achieved: ${AppFormatters.formatNumber(bd.currentMonthAgencyDiamonds)}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Target: ${AppFormatters.formatNumber(bd.currentDiamondTarget)}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Performance KPI Cards
            Text(
              'Key Performance Indicators',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            PremiumCard(
              padding: const EdgeInsets.all(16),
              radius: 16,
              child: Column(
                children: [
                  _buildKpiItem('Agency Diamond Volume', '${AppFormatters.formatNumber(bd.currentMonthAgencyDiamonds)} / ${AppFormatters.formatNumber(bd.currentDiamondTarget)}', bd.targetProgress, isDark, primary),
                  const SizedBox(height: 14),
                  _buildKpiItem('Active Agency Count', '${bd.totalAgenciesCount} / 20 Required', (bd.totalAgenciesCount / 20).clamp(0.0, 1.0), isDark, primary),
                  const SizedBox(height: 14),
                  _buildKpiItem('Recruited Agents', '${bd.totalActiveAgentsCount} / 60 Goal', (bd.totalActiveAgentsCount / 60).clamp(0.0, 1.0), isDark, primary),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Target-based Bonus Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardBlack : AppColors.champagneCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: Colors.orangeAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Achievement Bonus: \$1,000 USD',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.getTextPrimary(isDark),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reaching 10,000,000 agency diamonds before month-end unlocks Tier 4 full performance bonus.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.getTextSecondary(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(String label, String stat, double progress, bool isDark, Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
            ),
            Text(
              stat,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primary),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.getBorder(isDark),
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
      ],
    );
  }
}
