import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDIncomeScreen extends StatelessWidget {
  const BDIncomeScreen({super.key});

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
          'Income / Diamonds Audit',
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
            // Top Summary Card
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
                    'Current Month Eligible Agency Diamonds',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        AppFormatters.formatNumber(bd.currentMonthAgencyDiamonds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
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
                            'Prev Month: ${AppFormatters.formatNumber(bd.previousMonthAgencyDiamonds)}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          Icon(Icons.trending_up_rounded, color: Colors.greenAccent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            '+36.2% Growth',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Agency Diamond Contributions
            Text(
              'Agency Contributions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.getTextPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),

            ...bd.agencies.map((ag) {
              final share = bd.currentMonthAgencyDiamonds > 0
                  ? (ag.currentMonthDiamonds / bd.currentMonthAgencyDiamonds)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumCard(
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ag.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: AppColors.getTextPrimary(isDark),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.diamond_rounded, color: Colors.purpleAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                AppFormatters.formatNumber(ag.currentMonthDiamonds),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: share,
                          minHeight: 5,
                          backgroundColor: AppColors.getBorder(isDark),
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(share * 100).toStringAsFixed(1)}% of total network diamond revenue',
                        style: TextStyle(fontSize: 10, color: AppColors.getTextSecondary(isDark)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Traceability Audit Rules Notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardBlack : AppColors.champagneCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.greenAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All eligible agency diamond transactions are server-validated and traceable to individual host live stream gift receipts.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(isDark),
                      ),
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
}
