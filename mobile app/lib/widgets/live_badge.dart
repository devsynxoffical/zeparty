import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/animations/app_animations.dart';

class LiveBadge extends StatelessWidget {
  final int? viewerCount;

  const LiveBadge({super.key, this.viewerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.live,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.live.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulseAnimation(
            minScale: 0.75,
            maxScale: 1.0,
            duration: Duration(milliseconds: 1100),
            child: SizedBox(
              width: 7,
              height: 7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            viewerCount != null ? 'LIVE • $viewerCount' : 'LIVE',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
