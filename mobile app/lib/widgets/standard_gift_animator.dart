import 'package:flutter/material.dart';
import '../models/live_gift_event_model.dart';
import 'user_avatar.dart';

class StandardGiftAnimator extends StatefulWidget {
  final LiveGiftEventModel event;
  final VoidCallback onComplete;

  const StandardGiftAnimator({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<StandardGiftAnimator> createState() => _StandardGiftAnimatorState();
}

class _StandardGiftAnimatorState extends State<StandardGiftAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _senderBadgeOpacity;
  late Animation<double> _giftScale;
  late Animation<double> _bannerOpacity;
  late Animation<Offset> _travelOffset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _senderBadgeOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.20),
    ]).animate(_controller);

    _giftScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 0.35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 0.25,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.40),
    ]).animate(_controller);

    _bannerOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 0.25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.25),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.15),
    ]).animate(_controller);

    _travelOffset = Tween<Offset>(
      begin: const Offset(-0.3, 0.2),
      end: const Offset(0.0, -0.05),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

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
        final badgeOp = _senderBadgeOpacity.value.clamp(0.0, 1.0);
        final bannerOp = _bannerOpacity.value.clamp(0.0, 1.0);
        final scale = _giftScale.value;
        final offset = _travelOffset.value;

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Sender Avatar Badge Pill (Top Left)
            Positioned(
              top: size.height * 0.22,
              left: 20,
              child: Opacity(
                opacity: badgeOp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF4081), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(imageUrl: widget.event.senderAvatarUrl, radius: 14),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.event.senderName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          Text(
                            'sent ${widget.event.giftName} ${widget.event.giftIcon}',
                            style: const TextStyle(color: Color(0xFFFF80AB), fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Travelling & Blooming Gift Icon
            Positioned(
              top: size.height * 0.35 + (offset.dy * size.height),
              left: (size.width / 2 - 50) + (offset.dx * size.width),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.6 * badgeOp),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Text(
                    widget.event.giftIcon,
                    style: const TextStyle(fontSize: 64),
                  ),
                ),
              ),
            ),

            // 3. Bottom Neon Banner ("Sana sent Rose 🌹 x1")
            Positioned(
              bottom: size.height * 0.28,
              child: Opacity(
                opacity: bannerOp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E24AA), Color(0xFFD81B60)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD81B60).withValues(alpha: 0.6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.event.senderName} sent ${widget.event.giftName} ${widget.event.giftIcon} ${widget.event.comboCount > 1 ? "x${widget.event.comboCount}" : ""}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
