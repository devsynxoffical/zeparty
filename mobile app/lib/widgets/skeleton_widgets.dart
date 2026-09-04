import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';

/// ---------------------------------------------------------------------------
/// Skeleton shimmer building blocks
/// ---------------------------------------------------------------------------

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.shimmerBase(isDark: isDark);
    final highlight = AppColors.shimmerHighlight(isDark: isDark);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
          border: isDark
              ? Border.all(color: AppColors.borderGold, width: 0.5)
              : null,
        ),
      ),
    );
  }
}

class SkeletonAvatar extends StatelessWidget {
  final double radius;

  const SkeletonAvatar({super.key, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: radius * 2,
      height: radius * 2,
      borderRadius: radius,
    );
  }
}

class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({super.key, required this.width, this.height = 14});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(width: width, height: height, borderRadius: 6);
  }
}

/// A full live-room card skeleton
class SkeletonLiveCard extends StatelessWidget {
  const SkeletonLiveCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SkeletonBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 120),
                const SizedBox(height: 6),
                SkeletonText(width: 80, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A user-list-row skeleton
class SkeletonUserRow extends StatelessWidget {
  const SkeletonUserRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SkeletonAvatar(radius: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 120),
                const SizedBox(height: 6),
                SkeletonText(width: 80, height: 11),
              ],
            ),
          ),
          SkeletonBox(width: 60, height: 30, borderRadius: 14),
        ],
      ),
    );
  }
}

/// A notification-row skeleton
class SkeletonNotificationRow extends StatelessWidget {
  const SkeletonNotificationRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const SkeletonAvatar(radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonText(width: 140),
                const SizedBox(height: 6),
                SkeletonText(width: 200, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A post card skeleton
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonAvatar(radius: 20),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonText(width: 100),
                  const SizedBox(height: 4),
                  SkeletonText(width: 60, height: 11),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SkeletonText(width: double.infinity),
          const SizedBox(height: 4),
          SkeletonText(width: 200),
          const SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 180, borderRadius: 14),
        ],
      ),
    );
  }
}

/// Wraps a list of skeleton items with a count
class SkeletonList extends StatelessWidget {
  final int count;
  final Widget Function(int) builder;

  const SkeletonList({
    super.key,
    required this.count,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) => builder(i)),
    );
  }
}

/// A horizontal avatar-strip skeleton (Popular Hosts)
class SkeletonAvatarStrip extends StatelessWidget {
  final int count;

  const SkeletonAvatarStrip({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: count,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              const SkeletonAvatar(radius: 28),
              const SizedBox(height: 6),
              SkeletonText(width: 48, height: 11),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state widget with icon, title, subtitle
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.getPrimary(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: AppColors.onPrimary(isDark: isDark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
