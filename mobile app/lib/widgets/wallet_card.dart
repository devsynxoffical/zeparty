import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class WalletCard extends StatelessWidget {
  final String title;
  final String balance;
  final Widget icon;
  final LinearGradient gradient;
  final VoidCallback? action;

  const WalletCard({
    super.key,
    required this.title,
    required this.balance,
    required this.icon,
    required this.gradient,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.goldHighlight : AppColors.white)
              .withValues(alpha: isDark ? 0.45 : 0.6),
          width: 1,
        ),
        boxShadow: AppColors.primaryGlow(isDark, alpha: 0.22, blur: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        balance,
                        style: const TextStyle(color: AppColors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? AppColors.black.withValues(alpha: 0.65)
                    : AppColors.white,
                foregroundColor: isDark ? AppColors.white : AppColors.royalBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                side: BorderSide(
                  color: isDark ? AppColors.white.withValues(alpha: 0.8) : AppColors.white,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: action,
              child: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }
}
