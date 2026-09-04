import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDAgencyManagementScreen extends StatelessWidget {
  const BDAgencyManagementScreen({super.key});

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
          'Agency Management (${bd.agencies.length})',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        itemCount: bd.agencies.length,
        itemBuilder: (context, index) {
          final ag = bd.agencies[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: PremiumCard(
              padding: const EdgeInsets.all(18),
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage: NetworkImage(ag.ownerAvatar),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ag.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            Text(
                              'Owner: ${ag.ownerName} (ID: ${ag.ownerUserId})',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.greenAccent, width: 0.8),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Target
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Diamond Goal',
                        style: TextStyle(fontSize: 12, color: AppColors.getTextSecondary(isDark)),
                      ),
                      Row(
                        children: [
                          Icon(Icons.diamond_rounded, color: primary, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            '${AppFormatters.formatNumber(ag.currentMonthDiamonds)} / ${AppFormatters.formatNumber(ag.diamondTarget)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ag.progressPercentage,
                      minHeight: 6,
                      backgroundColor: AppColors.getBorder(isDark),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Stats Grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetric('Agents', '${ag.agentCount}', isDark),
                        _buildMetric('Hosts', '${ag.hostCount}', isDark),
                        _buildMetric('Commission', '${ag.commissionRate.toStringAsFixed(0)}%', isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.getTextPrimary(isDark),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
      ],
    );
  }
}
