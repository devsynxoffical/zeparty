import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/design/premium_card.dart';
import 'bd_salary_history_screen.dart';

class BDSalaryScreen extends StatelessWidget {
  const BDSalaryScreen({super.key});

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
          'BD Salary & Compensation',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history_rounded, color: primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const BDSalaryHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Period Projection Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.getPremiumGradient(isDark),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.primaryGlow(isDark, alpha: 0.3, blur: 14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'August 2026 Salary Projection',
                        style: TextStyle(
                          color: AppColors.onPrimary(isDark: isDark).withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TIER ${bd.currentSalaryTier}',
                          style: TextStyle(
                            color: AppColors.onPrimary(isDark: isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$${bd.currentSalaryProjection.toStringAsFixed(2)} USD',
                    style: TextStyle(
                      color: AppColors.onPrimary(isDark: isDark),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fixed Salary: \$2,200.00 • Commission: \$850.00 • Bonus: \$400.00',
                    style: TextStyle(
                      color: AppColors.onPrimary(isDark: isDark).withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 14),
                  GoldButton(
                    text: 'View Salary Payout History',
                    height: 40,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (c) => const BDSalaryHistoryScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Salary Tiers Policy
            Text(
              'Configured BD Salary Policy Tiers',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            ...bd.salaryTiers.map((tier) {
              final isCurrentTier = tier.tierLevel == bd.currentSalaryTier;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  padding: const EdgeInsets.all(16),
                  radius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.getTextPrimary(isDark),
                                ),
                              ),
                              if (isCurrentTier) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '\$${tier.fixedSalaryUsd.toStringAsFixed(0)} / mo',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Diamond Target: ${AppFormatters.formatNumber(tier.requiredDiamonds)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Commission: ${tier.commissionPercentage.toStringAsFixed(0)}% • Target Bonus: \$${tier.bonusUsd.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Min Requirements: ${tier.minActiveAgencies} Agencies, ${tier.minActiveAgents} Active Agents',
                        style: TextStyle(
                          fontSize: 10,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
