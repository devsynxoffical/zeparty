import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/vip_item_model.dart';

class VipCard extends StatelessWidget {
  final VipItemModel item;
  final VoidCallback? onBuy;

  const VipCard({super.key, required this.item, this.onBuy});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);
    final borderColor = AppColors.getBorder(isDark);
    final borderStrong = AppColors.getBorderStrong(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isOwned ? primaryColor : borderColor,
          width: item.isOwned ? 1.5 : 1,
        ),
        boxShadow: item.isOwned
            ? AppColors.primaryGlow(isDark, alpha: 0.18, blur: 16)
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.getPremiumGradient(isDark),
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.primaryGlow(isDark, alpha: 0.2, blur: 12),
            ),
            child: Text(item.icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: item.isOwned ? primaryColor : null,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isOwned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderStrong, width: 0.8),
                        ),
                        child: Text(
                          'OWNED',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: item.isOwned
                  ? (isDark ? AppColors.softBlack : AppColors.lightSurface)
                  : primaryColor,
              foregroundColor: item.isOwned
                  ? primaryColor
                  : AppColors.onPrimary(isDark: isDark),
              side: BorderSide(
                color: item.isOwned ? borderStrong : AppColors.transparent,
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: item.isOwned ? null : onBuy,
            child: Text(
              item.isOwned ? 'Active' : '${item.coinPrice} 🪙',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
