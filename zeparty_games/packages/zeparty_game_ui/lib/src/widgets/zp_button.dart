import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/zp_colors.dart';
import '../theme/zp_theme.dart';

enum ZpButtonKind { primary, secondary, ghost, danger }

/// Press-depth button with gold gradient, haptic and loading state.
class ZpButton extends StatefulWidget {
  const ZpButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = ZpButtonKind.primary,
    this.icon,
    this.loading = false,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ZpButtonKind kind;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  State<ZpButton> createState() => _ZpButtonState();
}

class _ZpButtonState extends State<ZpButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = switch (widget.kind) {
      ZpButtonKind.primary => ZpColors.obsidian,
      ZpButtonKind.secondary => ZpColors.gold,
      ZpButtonKind.ghost => ZpColors.textSecondary,
      ZpButtonKind.danger => ZpColors.ivory,
    };
    final decoration = switch (widget.kind) {
      ZpButtonKind.primary => BoxDecoration(
          gradient: ZpColors.goldGradient,
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          boxShadow: _down || !_enabled ? null : [BoxShadow(color: ZpColors.gold.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
      ZpButtonKind.secondary => BoxDecoration(
          color: ZpColors.panelRaised,
          borderRadius: BorderRadius.circular(ZpRadius.pill),
          border: Border.all(color: ZpColors.gold.withValues(alpha: 0.6)),
        ),
      ZpButtonKind.ghost => BoxDecoration(borderRadius: BorderRadius.circular(ZpRadius.pill), border: Border.all(color: ZpColors.divider)),
      ZpButtonKind.danger => BoxDecoration(color: ZpColors.danger, borderRadius: BorderRadius.circular(ZpRadius.pill)),
    };
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        else if (widget.icon != null)
          Icon(widget.icon, size: 18, color: fg),
        if (widget.loading || widget.icon != null) const SizedBox(width: ZpSpace.sm),
        Text(widget.label.toUpperCase(), style: text.labelLarge?.copyWith(color: fg, fontSize: widget.compact ? 12 : 14)),
      ],
    );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: _enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed?.call();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: ZpDurations.fast,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.45,
            duration: ZpDurations.fast,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? ZpSpace.lg : ZpSpace.xl, vertical: widget.compact ? 10 : 14),
              decoration: decoration,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button with a subtle raised panel look.
class ZpIconButton extends StatelessWidget {
  const ZpIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.active = false, this.size = 44});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final b = Material(
      color: active ? ZpColors.gold : ZpColors.panelRaised,
      shape: CircleBorder(side: BorderSide(color: active ? ZpColors.goldLight : ZpColors.divider)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.48, color: active ? ZpColors.obsidian : ZpColors.gold)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}
