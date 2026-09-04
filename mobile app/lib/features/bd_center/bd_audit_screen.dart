import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/bd_center_provider.dart';
import '../../widgets/design/premium_card.dart';

class BDAuditScreen extends StatelessWidget {
  const BDAuditScreen({super.key});

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
          'BD Operation Audit Logs (${bd.auditLogs.length})',
          style: TextStyle(
            color: AppColors.getTextPrimary(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: bd.auditLogs.isEmpty
          ? Center(
              child: Text(
                'No audit logs recorded yet.',
                style: TextStyle(color: AppColors.getTextSecondary(isDark)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: bd.auditLogs.length,
              itemBuilder: (context, index) {
                final log = bd.auditLogs[index];
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
                                _buildCategoryBadge(log.category),
                                const SizedBox(width: 8),
                                Text(
                                  log.action,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: AppColors.getTextPrimary(isDark),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildRow('Target ID', log.targetId, isDark),
                        _buildRow('Operator ID', '${log.actorId} (${log.actorRole})', isDark),
                        _buildRow('Old Value', log.oldValue, isDark),
                        _buildRow('New Value', log.newValue, isDark, highlight: true),
                        _buildRow('Action ID', log.actionId, isDark),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.softBlack : AppColors.champagneSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Reason: ${log.reason}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: primary,
                            ),
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

  Widget _buildRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.getTextSecondary(isDark)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? Colors.greenAccent : AppColors.getTextPrimary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBadge(String cat) {
    Color color;
    switch (cat.toLowerCase()) {
      case 'agent':
        color = Colors.blueAccent;
        break;
      case 'agency':
        color = Colors.amber;
        break;
      case 'svip':
        color = Colors.orange;
        break;
      case 'noble':
        color = Colors.purpleAccent;
        break;
      case 'salary':
        color = Colors.greenAccent;
        break;
      default:
        color = Colors.tealAccent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        cat.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
