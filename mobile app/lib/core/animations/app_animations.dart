import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppAnimations {
  AppAnimations._();

  // Duration standard ranges
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration major = Duration(milliseconds: 450);

  // Standard curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.elasticOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
}

/// Animated Fade + Scale wrapper for smooth entry of cards and screens
class FadeScaleTransitionWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double initialScale;
  final Curve curve;

  const FadeScaleTransitionWidget({
    super.key,
    required this.child,
    this.duration = AppAnimations.normal,
    this.initialScale = 0.92,
    this.curve = AppAnimations.defaultCurve,
  });

  @override
  State<FadeScaleTransitionWidget> createState() => _FadeScaleTransitionWidgetState();
}

class _FadeScaleTransitionWidgetState extends State<FadeScaleTransitionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _scaleAnimation = Tween<double>(begin: widget.initialScale, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Fade + subtle vertical rise entrance for screens and premium sections.
class ScreenEntrance extends StatefulWidget {
  final Widget child;
  final double offset;
  final Duration duration;

  const ScreenEntrance({
    super.key,
    required this.child,
    this.offset = 24,
    this.duration = AppAnimations.major,
  });

  @override
  State<ScreenEntrance> createState() => _ScreenEntranceState();
}

class _ScreenEntranceState extends State<ScreenEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve);
    _slide = Tween<Offset>(begin: Offset(0, widget.offset), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

/// Gentle repeating pulse (used for LIVE dot / premium glow accents).
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  const PulseAnimation({
    super.key,
    required this.child,
    this.minScale = 0.9,
    this.maxScale = 1.0,
    this.duration = const Duration(milliseconds: 1200),
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: widget.minScale, end: widget.maxScale)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// A smooth, subtle metallic shine that travels horizontally across its child.
/// Meant for premium buttons, banners and VIP cards — never applied everywhere
/// at once. The shine band is a soft light-gold gradient clipped to the child.
class MetallicShine extends StatefulWidget {
  final Widget? child;
  final Duration duration;
  final double bandWidth;
  final double beginX;

  const MetallicShine({
    super.key,
    this.child,
    this.duration = const Duration(milliseconds: 2600),
    this.bandWidth = 0.45,
    this.beginX = -0.6,
  });

  @override
  State<MetallicShine> createState() => _MetallicShineState();
}

class _MetallicShineState extends State<MetallicShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _position = Tween<double>(begin: widget.beginX, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shineColor = isDark ? AppColors.goldHighlight : AppColors.lightBlue;

    Widget buildShine() => IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return FractionallySizedBox(
            widthFactor: widget.bandWidth,
            child: Align(
              alignment: Alignment(_position.value, 0),
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        shineColor.withValues(alpha: 0.0),
                        shineColor.withValues(alpha: 0.28),
                        AppColors.white.withValues(alpha: 0.18),
                        shineColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.child == null) {
      return buildShine();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          widget.child!,
          Positioned.fill(child: buildShine()),
        ],
      ),
    );
  }
}

/// Animated gold border glow that softly breathes around VIP / premium cards.
class GoldGlowBorder extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;
  final double minOpacity;
  final double maxOpacity;
  final Duration duration;

  const GoldGlowBorder({
    super.key,
    required this.child,
    this.color = AppColors.warmGold,
    this.borderRadius = 18,
    this.minOpacity = 0.15,
    this.maxOpacity = 0.45,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<GoldGlowBorder> createState() => _GoldGlowBorderState();
}

class _GoldGlowBorderState extends State<GoldGlowBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = widget.minOpacity +
            (widget.maxOpacity - widget.minOpacity) * _controller.value;
        return Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 2),
            border: Border.all(
              color: widget.color.withValues(alpha: opacity),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: opacity * 0.8),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shake animation for input validation feedback
class ShakeWidget extends StatefulWidget {
  final Widget child;
  final bool shake;
  final VoidCallback? onComplete;

  const ShakeWidget({
    super.key,
    required this.child,
    required this.shake,
    this.onComplete,
  });

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void didUpdateWidget(ShakeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double offset = math.sin(_controller.value * math.pi * 4) * 8.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Floating heart animation widget for double-tap video likes
class FloatingHeartAnimation extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const FloatingHeartAnimation({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<FloatingHeartAnimation> createState() => _FloatingHeartAnimationState();
}

class _FloatingHeartAnimationState extends State<FloatingHeartAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 50),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0, curve: Curves.easeOut)),
    );

    _translateY = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(widget.position.dx - 40, widget.position.dy - 40 + _translateY.value),
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Icon(
                  Icons.favorite_rounded,
                  color: AppColors.liveRed,
                  size: 80,
                  shadows: [
                    BoxShadow(
                      color: AppColors.liveRed.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
