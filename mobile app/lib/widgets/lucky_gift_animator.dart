import 'dart:math';
import 'package:flutter/material.dart';
import '../models/live_gift_event_model.dart';

/// Dedicated high-impact Lucky Gift Animator for ZeParty live and party rooms.
/// Replaces the plain text banner with rich glowing gift visuals, lucky multipliers,
/// and celebratory particle burst effects.
class LuckyGiftAnimator extends StatefulWidget {
  final LiveGiftEventModel event;
  final VoidCallback onComplete;

  const LuckyGiftAnimator({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<LuckyGiftAnimator> createState() => _LuckyGiftAnimatorState();
}

class _LuckyGiftAnimatorState extends State<LuckyGiftAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _particlesAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.25)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 15,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 35),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInBack)),
        weight: 15,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 70),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 15),
    ]).animate(_controller);

    _rotationAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOut),
      ),
    );

    _particlesAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

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
        final scale = _scaleAnimation.value;
        final opacity = _opacityAnimation.value.clamp(0.0, 1.0);
        final rot = _rotationAnimation.value;
        final particleProgress = _particlesAnimation.value;

        return Align(
          alignment: const Alignment(0, -0.15),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
                scale: scale,
                child: SizedBox(
                  width: size.width * 0.92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ─── Golden Radial Particle Aura ───
                      for (int i = 0; i < 8; i++) ...[
                        Builder(builder: (ctx) {
                          final angle = (i * (2 * pi / 8)) + (particleProgress * 0.8);
                          final dist = 80 + (particleProgress * 90);
                          final pOpacity = (1.0 - particleProgress).clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(cos(angle) * dist, sin(angle) * dist),
                            child: Opacity(
                              opacity: pOpacity,
                              child: const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFD700),
                                size: 22,
                              ),
                            ),
                          );
                        }),
                      ],

                      // ─── Pure Floating & Rotating Gift with Golden Glow (No Card/Banners) ───
                      Transform.rotate(
                        angle: rot,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.65),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                              BoxShadow(
                                color: const Color(0xFFE040FB).withValues(alpha: 0.45),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.event.giftIcon.startsWith('assets/')
                                ? Image.asset(
                                    widget.event.giftIcon,
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Text('🎁', style: TextStyle(fontSize: 84)),
                                  )
                                : widget.event.giftIcon.startsWith('http')
                                    ? Image.network(
                                        widget.event.giftIcon,
                                        width: 130,
                                        height: 130,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Text('🎁', style: TextStyle(fontSize: 84)),
                                      )
                                    : Text(
                                        widget.event.giftIcon,
                                        style: const TextStyle(fontSize: 84),
                                      ),
                          ),
                        ),
                      ),

                      // Optional Combo Badge if multiple gifts sent
                      if (widget.event.comboCount > 1)
                        Positioned(
                          right: size.width * 0.22,
                          bottom: 10,
                          child: Transform.rotate(
                            angle: -0.12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF9100), Color(0xFFFF1744)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '×${widget.event.comboCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
  }
}
