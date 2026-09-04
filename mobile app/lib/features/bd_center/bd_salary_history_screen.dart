import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/bd_center_model.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDSalaryHistoryScreen extends StatelessWidget {
  const BDSalaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bd = context.watch<BDCenterProvider>();

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(isDark),
        title: Text(
          'Salary Payout History',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: bd.salaryHistory.isEmpty
          ? Center(
              child: Text(
                'No salary history records found.',
                style: TextStyle(color: AppColors.getTextSecondary(isDark)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: bd.salaryHistory.length,
              itemBuilder: (context, index) {
                final rec = bd.salaryHistory[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(16),
                    radius: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Period: ${rec.period}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                            _buildPaymentStatusBadge(rec.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Paid Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextSecondary(isDark),
                              ),
                            ),
                            Text(
                              '\$${rec.finalAmount.toStringAsFixed(2)} USD',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(color: AppColors.getBorder(isDark), height: 1),
                        const SizedBox(height: 10),
                        _buildDetailRow('Diamonds Achieved', AppFormatters.formatNumber(rec.totalDiamonds), isDark),
                        _buildDetailRow('Fixed Salary', '\$${rec.fixedSalary.toStringAsFixed(2)}', isDark),
                        _buildDetailRow('Commission', '\$${rec.commission.toStringAsFixed(2)}', isDark),
                        _buildDetailRow('Bonus Earned', '\$${rec.bonus.toStringAsFixed(2)}', isDark),
                        if (rec.referenceId != null)
                          _buildDetailRow('Reference ID', rec.referenceId!, isDark),
                        if (rec.paymentDate != null)
                          _buildDetailRow(
                            'Paid On',
                            '${rec.paymentDate!.day}/${rec.paymentDate!.month}/${rec.paymentDate!.year}',
                            isDark,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.getTextPrimary(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusBadge(BDSalaryPaymentStatus status) {
    Color color;
    String label;
    switch (status) {
      case BDSalaryPaymentStatus.paid:
        color = Colors.greenAccent;
        label = 'PAID ✓';
        break;
      case BDSalaryPaymentStatus.processing:
        color = Colors.blueAccent;
        label = 'PROCESSING';
        break;
      case BDSalaryPaymentStatus.pending:
        color = Colors.orangeAccent;
        label = 'PENDING';
        break;
      case BDSalaryPaymentStatus.held:
        color = Colors.amber;
        label = 'HELD';
        break;
      case BDSalaryPaymentStatus.rejected:
        color = Colors.redAccent;
        label = 'REJECTED';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
