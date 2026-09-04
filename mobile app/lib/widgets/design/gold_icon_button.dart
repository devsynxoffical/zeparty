import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';

/// Circular gold-toned icon button with press feedback.
class GoldIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final bool outlined;
  final Color? backgroundColor;

  const GoldIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.color,
    this.outlined = false,
    this.backgroundColor,
  });

  @override
  State<GoldIconButton> createState() => _GoldIconButtonState();
}

class _GoldIconButtonState extends State<GoldIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = widget.color ?? (isDark ? AppColors.warmGold : AppColors.royalBlue);
    final bgColor = widget.backgroundColor ?? (isDark ? AppColors.softBlack : AppColors.lightSurface);
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: AppAnimations.fast,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: widget.outlined
                ? Border.all(
                    color: isDark ? AppColors.goldBorder : AppColors.lightBorder,
                    width: 1.2,
                  )
                : null,
            boxShadow: _pressed
                ? (isDark
                    ? AppColors.goldGlow(alpha: 0.3, blur: 14)
                    : [
                        BoxShadow(
                          color: AppColors.royalBlue.withValues(alpha: 0.25),
                          blurRadius: 14,
                        ),
                      ])
                : null,
          ),
          child: Icon(widget.icon, color: iconColor, size: widget.size * 0.46),
        ),
      ),
    );
  }
}

/// Small circular filled gold action (e.g. send, add).
class GoldFilledIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const GoldFilledIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoldIconButton(
      icon: icon,
      onPressed: onPressed,
      size: size,
      backgroundColor: isDark ? AppColors.warmGold : AppColors.royalBlue,
      color: isDark ? AppColors.black : AppColors.white,
    );
  }
}
