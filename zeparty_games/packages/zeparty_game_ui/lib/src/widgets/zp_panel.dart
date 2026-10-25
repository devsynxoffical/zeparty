import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:zeparty_game_assets/zeparty_game_assets.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';

/// Raised glass panel used for cards, HUD and sheets.
class ZpPanel extends StatelessWidget {
  const ZpPanel({super.key, required this.child, this.padding = const EdgeInsets.all(ZpSpace.lg), this.radius = ZpRadius.lg, this.glow = false, this.blur = true, this.borderColor, this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool glow;
  final bool blur;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: ZpColors.panelGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? ZpColors.divider),
        boxShadow: [
          const BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
          if (glow) BoxShadow(color: ZpColors.gold.withValues(alpha: 0.18), blurRadius: 30, spreadRadius: 2),
        ],
      ),
      child: child,
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: body) : body,
    );
    if (onTap == null) return clipped;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: clipped));
  }
}

/// Full-screen branded backdrop: lobby image when available, gradient fallback.
class ZpBackdrop extends StatelessWidget {
  const ZpBackdrop({super.key, required this.child, this.image = 'common/backgrounds/lobby_dark_gold.webp', this.dim = 0.0});
  final Widget child;
  final String? image;
  final double dim;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: ZpColors.backdrop)),
        if (image != null)
          Image(
            image: ZpAssets.image(image!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        if (dim > 0) ColoredBox(color: Colors.black.withValues(alpha: dim)),
        child,
      ],
    );
  }
}

/// Section header with a thin gold rule.
class ZpSectionHeader extends StatelessWidget {
  const ZpSectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(ZpSpace.lg, ZpSpace.xl, ZpSpace.lg, ZpSpace.md),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: t.titleSmall?.copyWith(color: ZpColors.gold, letterSpacing: 2)),
          const SizedBox(width: ZpSpace.md),
          Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [ZpColors.gold.withValues(alpha: 0.6), Colors.transparent])))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Gold outlined chip used for tags like "2-4 players".
class ZpChip extends StatelessWidget {
  const ZpChip(this.label, {super.key, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? ZpColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(ZpRadius.pill), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: 5)],
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c)),
      ]),
    );
  }
}
