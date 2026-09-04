import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/live_gift_event_model.dart';
import 'user_avatar.dart';

class PremiumGiftAnimator extends StatefulWidget {
  final LiveGiftEventModel event;
  final VoidCallback onComplete;

  const PremiumGiftAnimator({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<PremiumGiftAnimator> createState() => _PremiumGiftAnimatorState();
}

class _PremiumGiftAnimatorState extends State<PremiumGiftAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  late Animation<double> _fadeInOut;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _fadeInOut = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.15),
    ]).animate(_controller);

    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.2), weight: 0.5),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 0.9), weight: 0.5),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _progress.value;
        final opacity = _fadeInOut.value.clamp(0.0, 1.0);
        final scale = _pulseScale.value;

        // Diagonal upward trajectory from bottom-left to top-right/center
        final startX = size.width * 0.15;
        final startY = size.height * 0.65;
        final endX = size.width * 0.55;
        final endY = size.height * 0.25;

        final currentX = startX + (endX - startX) * t;
        final currentY = startY + (endY - startY) * t;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Fiery Motion Trail Particles
            Positioned(
              left: currentX - 40,
              top: currentY + 30,
              child: Opacity(
                opacity: opacity * 0.8,
                child: Container(
                  width: 80,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFF6D00).withValues(alpha: 0.9),
                        const Color(0xFFFFD600).withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Main Ascending Rocket / Yacht 3D Gift Icon
            Positioned(
              left: currentX - 50,
              top: currentY - 50,
              child: Transform.rotate(
                angle: -math.pi / 8, // slight upward angle
                child: Transform.scale(
                  scale: scale * 1.3,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF3D00).withValues(alpha: 0.8 * opacity),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: const Color(0xFFFFD600).withValues(alpha: 0.6 * opacity),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.event.giftIcon,
                      style: const TextStyle(fontSize: 88),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Sender Badge (Left Side Pill)
            Positioned(
              top: size.height * 0.38,
              left: 16,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1B2E).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE040FB), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.5), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(imageUrl: widget.event.senderAvatarUrl, radius: 16),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.event.senderName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'sent ${widget.event.giftName} ${widget.event.giftIcon}',
                            style: const TextStyle(color: Color(0xFFE040FB), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Dynamic Rocket Combo Banner ("x 999 Rocket Combo")
            Positioned(
              right: 28,
              top: size.height * 0.42,
              child: Opacity(
                opacity: opacity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'x ${widget.event.comboCount}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                        fontStyle: FontStyle.italic,
                        shadows: [
                          Shadow(color: Color(0xFFFF3D00), blurRadius: 16, offset: Offset(2, 2)),
                        ],
                      ),
                    ),
                    Text(
                      '${widget.event.giftName} Combo',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0xFFE040FB), blurRadius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
