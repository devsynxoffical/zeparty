import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/animations/app_animations.dart';

/// A pressable gold button with a metallic gradient, a travelling shine,
/// soft glow and a smooth press scale. The primary CTA of the app.
class GoldButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final double? width;
  final bool showShine;
  final double height;
  final double radius;
  final bool isLoading;

  const GoldButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.expand = true,
    this.width,
    this.showShine = true,
    this.height = 52,
    this.radius = 16,
    this.isLoading = false,
  });

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _pressed = false;

  void _setPressed(bool value) => setState(() => _pressed = value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final activeGradient = isDark ? AppColors.metallicGoldGradient : AppColors.metallicBlueGradient;
    final contentColor = isDark ? AppColors.black : AppColors.white;
    final shadowColor1 = isDark ? AppColors.metallicGold : AppColors.royalBlue;
    final shadowColor2 = isDark ? AppColors.warmGold : AppColors.deepRoyalBlue;

    return GestureDetector(
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppAnimations.fast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.width ?? (widget.expand ? double.infinity : null),
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: widget.expand || widget.width != null ? 0 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: enabled
                ? activeGradient
                : LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF1B1B1B), Color(0xFF141414)]
                        : const [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                  ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: shadowColor1.withValues(alpha: _pressed ? 0.5 : 0.32),
                      blurRadius: _pressed ? 26 : 18,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                    BoxShadow(
                      color: shadowColor2.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: Stack(
              alignment: Alignment.center,
              fit: widget.expand || widget.width != null ? StackFit.expand : StackFit.loose,
              children: [
                if (widget.showShine && enabled)
                  const Positioned.fill(
                    child: MetallicShine(bandWidth: 0.4, beginX: -0.7),
                  ),
                Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: contentColor,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: contentColor,
                                size: widget.height < 45 ? 16 : 18,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: Text(
                                widget.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: contentColor,
                                  fontSize: widget.height < 45 ? 12.5 : 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
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

/// Secondary button: dark or white surface with an outlined border.
class GoldOutlinedButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expand;
  final Color? foregroundColor;
  final double height;
  final double radius;
  final bool isLoading;

  const GoldOutlinedButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.foregroundColor,
    this.height = 52,
    this.radius = 16,
    this.isLoading = false,
  });

  @override
  State<GoldOutlinedButton> createState() => _GoldOutlinedButtonState();
}

class _GoldOutlinedButtonState extends State<GoldOutlinedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = !widget.isLoading;
    final fgColor = widget.foregroundColor ?? (isDark ? AppColors.lightGold : AppColors.royalBlue);
    final borderColor = isDark
        ? (_pressed ? AppColors.warmGold : AppColors.goldBorder)
        : (_pressed ? AppColors.royalBlue : AppColors.lightBorder);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppAnimations.fast,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          width: widget.expand ? double.infinity : null,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBlack : AppColors.lightCard,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: borderColor,
              width: 1.3,
            ),
            boxShadow: _pressed
                ? (isDark
                    ? AppColors.goldGlow(alpha: 0.22, blur: 16)
                    : [
                        BoxShadow(
                          color: AppColors.royalBlue.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ])
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: fgColor,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: fgColor, size: widget.height < 45 ? 16 : 18),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          widget.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fgColor,
                            fontSize: widget.height < 45 ? 12.5 : 13.5,
                            fontWeight: FontWeight.w700,
                          ),
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
