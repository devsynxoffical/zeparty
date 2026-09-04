import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/live_gift_event_model.dart';
import 'user_avatar.dart';

class LegendaryGiftAnimator extends StatefulWidget {
  final LiveGiftEventModel event;
  final VoidCallback onComplete;

  const LegendaryGiftAnimator({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<LegendaryGiftAnimator> createState() => _LegendaryGiftAnimatorState();
}

class _LegendaryGiftAnimatorState extends State<LegendaryGiftAnimator>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;

  late Animation<double> _backdropOpacity;
  late Animation<double> _crownScale;
  late Animation<double> _pedestalFade;
  late Animation<double> _cardsOpacity;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _backdropOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.75), weight: 0.15),
      TweenSequenceItem(tween: ConstantTween<double>(0.75), weight: 0.70),
      TweenSequenceItem(tween: Tween<double>(begin: 0.75, end: 0.0), weight: 0.15),
    ]).animate(_mainController);

    _crownScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 0.30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 0.20,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.35),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2).chain(CurveTween(curve: Curves.easeOut)),
        weight: 0.15,
      ),
    ]).animate(_mainController);

    _pedestalFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.25),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.15),
    ]).animate(_mainController);

    _cardsOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 0.20),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.15),
    ]).animate(_mainController);

    _mainController.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _rotationController]),
      builder: (context, child) {
        final darkOp = _backdropOpacity.value.clamp(0.0, 1.0);
        final crownScaleVal = _crownScale.value;
        final pedestalOp = _pedestalFade.value.clamp(0.0, 1.0);
        final cardsOp = _cardsOpacity.value.clamp(0.0, 1.0);
        final rotationAngle = _rotationController.value * 2 * math.pi;

        return Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // 1. Cinematic Screen Darkening Backdrop
            Container(color: Colors.black.withValues(alpha: darkOp)),

            // 2. Rotating Light Rays Background
            Positioned(
              top: size.height * 0.22,
              child: Opacity(
                opacity: pedestalOp * 0.7,
                child: Transform.rotate(
                  angle: rotationAngle,
                  child: CustomPaint(
                    size: Size(size.width * 0.9, size.width * 0.9),
                    painter: _LightRaysPainter(),
                  ),
                ),
              ),
            ),

            // 3. Center Pedestal & Legendary Crown Icon
            Positioned(
              top: size.height * 0.32,
              child: Opacity(
                opacity: pedestalOp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Crown Presentation
                    Transform.scale(
                      scale: crownScaleVal,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.8),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF4081).withValues(alpha: 0.6),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          widget.event.giftIcon,
                          style: const TextStyle(fontSize: 100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pedestal Platform & Price Tag 💎 50000
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A148C), Color(0xFF8E24AA), Color(0xFF4A148C)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.6), blurRadius: 16),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('💎 ', style: TextStyle(fontSize: 18)),
                          Text(
                            '${widget.event.totalValue}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Neon Banner ("Mehak sent King Crown 👑")
            Positioned(
              bottom: size.height * 0.22,
              child: Opacity(
                opacity: cardsOp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD81B60), Color(0xFF8E24AA), Color(0xFFD81B60)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFFD700), width: 1.8),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFD81B60).withValues(alpha: 0.7), blurRadius: 20),
                    ],
                  ),
                  child: Text(
                    '${widget.event.senderName} sent ${widget.event.giftName} ${widget.event.giftIcon}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            // 5. Sender & Receiver Highlight Cards (Sides)
            Positioned(
              top: size.height * 0.25,
              left: 20,
              child: Opacity(
                opacity: cardsOp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(imageUrl: widget.event.senderAvatarUrl, radius: 24),
                    const SizedBox(height: 4),
                    Text(
                      widget.event.senderName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const Text('Sender', style: TextStyle(color: Color(0xFFFFD700), fontSize: 10)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.25,
              right: 20,
              child: Opacity(
                opacity: cardsOp,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(imageUrl: widget.event.receiverAvatarUrl, radius: 24),
                    const SizedBox(height: 4),
                    Text(
                      widget.event.receiverName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    const Text('Receiver', style: TextStyle(color: Color(0xFFE040FB), fontSize: 10)),
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

class _LightRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const rayCount = 12;
    const sweepAngle = (2 * math.pi / rayCount) * 0.5;

    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rayCount; i++) {
      final startAngle = i * (2 * math.pi / rayCount);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
