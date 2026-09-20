import 'package:flutter/material.dart';
import '../models/live_gift_event_model.dart';

class BasicGiftAnimator extends StatefulWidget {
  final LiveGiftEventModel event;
  final VoidCallback onComplete;

  const BasicGiftAnimator({
    super.key,
    required this.event,
    required this.onComplete,
  });

  @override
  State<BasicGiftAnimator> createState() => _BasicGiftAnimatorState();
}

class _BasicGiftAnimatorState extends State<BasicGiftAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _translateYAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.2).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 0.35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 0.25,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.40),
    ]).animate(_controller);

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.25),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.25),
    ]).animate(_controller);

    _translateYAnim = Tween<double>(begin: 0.0, end: -35.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _opacityAnim.value.clamp(0.0, 1.0);
        final scale = _scaleAnim.value;
        final translateY = _translateYAnim.value;

        return Align(
          alignment: const Alignment(0, -0.25),
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1035).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE040FB), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE040FB).withValues(alpha: 0.5),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.event.giftIcon, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.event.senderName} sent ${widget.event.giftName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (widget.event.comboCount > 1)
                            Text(
                              'x${widget.event.comboCount}',
                              style: const TextStyle(
                                color: Color(0xFFFFD700),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
