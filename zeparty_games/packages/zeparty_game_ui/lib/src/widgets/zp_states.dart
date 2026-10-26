import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';
import 'zp_button.dart';

/// Loading, empty and error states share one visual language.
class ZpLoading extends StatelessWidget {
  const ZpLoading({super.key, this.label, this.progress});
  final String? label;
  final double? progress;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(value: progress, strokeWidth: 3, color: ZpColors.gold, backgroundColor: ZpColors.gold.withValues(alpha: 0.15)),
              Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: ZpColors.goldGradient))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.7, 0.7), end: const Offset(1.1, 1.1), duration: 700.ms, curve: Curves.easeInOut),
            ]),
          ),
          if (label != null) ...[
            const SizedBox(height: ZpSpace.lg),
            Text(label!, style: t.bodyMedium, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class ZpEmpty extends StatelessWidget {
  const ZpEmpty({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ZpSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(shape: BoxShape.circle, color: ZpColors.gold.withValues(alpha: 0.1), border: Border.all(color: ZpColors.gold.withValues(alpha: 0.35))),
              child: Icon(icon, color: ZpColors.gold, size: 32),
            ),
            const SizedBox(height: ZpSpace.lg),
            Text(title, style: t.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[const SizedBox(height: ZpSpace.sm), Text(message!, style: t.bodyMedium, textAlign: TextAlign.center)],
            if (actionLabel != null) ...[const SizedBox(height: ZpSpace.xl), ZpButton(label: actionLabel!, onPressed: onAction, kind: ZpButtonKind.secondary)],
          ],
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
      ),
    );
  }
}

class ZpError extends StatelessWidget {
  const ZpError({super.key, required this.message, this.onRetry, this.title = 'Something went wrong'});
  final String title;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => ZpEmpty(icon: Icons.error_outline_rounded, title: title, message: message, actionLabel: onRetry == null ? null : 'Retry', onAction: onRetry);
}

/// Shimmer placeholder block for list skeletons.
class ZpSkeleton extends StatelessWidget {
  const ZpSkeleton({super.key, this.height = 80, this.width = double.infinity, this.radius = ZpRadius.md});
  final double height;
  final double width;
  final double radius;
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(color: ZpColors.panelRaised, borderRadius: BorderRadius.circular(radius)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1400.ms, color: ZpColors.gold.withValues(alpha: 0.12));
}
