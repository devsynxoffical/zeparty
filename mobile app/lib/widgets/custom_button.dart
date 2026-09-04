import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/animations/app_animations.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimaryGradient;
  final bool isVipGradient;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimaryGradient = false,
    this.isVipGradient = false,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldStyle = widget.isPrimaryGradient || widget.isVipGradient;
    Decoration? decoration;
    if (goldStyle) {
      decoration = BoxDecoration(
        gradient: AppColors.getPremiumGradient(isDark),
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.primaryGlow(isDark, alpha: 0.32, blur: 16),
      );
    } else {
      decoration = BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(14),
      );
    }

    final enabled = !widget.isLoading;
    final defaultTextColor = goldStyle
        ? AppColors.onPrimary(isDark: isDark)
        : Theme.of(context).colorScheme.onPrimary;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppAnimations.fast,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: decoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (goldStyle && enabled)
                  const MetallicShine(bandWidth: 0.38, beginX: -0.7),
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.black),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: widget.textColor ??
                                    defaultTextColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.textColor ??
                                    defaultTextColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
