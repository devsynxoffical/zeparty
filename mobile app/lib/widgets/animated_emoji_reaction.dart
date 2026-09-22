import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedEmojiReaction extends StatefulWidget {
  final String emoji;
  final Offset startPosition;
  final VoidCallback onComplete;
  final Duration duration;
  final double emojiSize;

  const AnimatedEmojiReaction({
    super.key,
    required this.emoji,
    required this.startPosition,
    required this.onComplete,
    this.duration = const Duration(milliseconds: 2000),
    this.emojiSize = 36.0,
  });

  @override
  State<AnimatedEmojiReaction> createState() => _AnimatedEmojiReactionState();
}

class _AnimatedEmojiReactionState extends State<AnimatedEmojiReaction> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _translateYAnimation;
  late Animation<double> _translateXAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();

    final rand = Random(widget.startPosition.dx.toInt() ^ widget.emoji.hashCode);
    final targetY = -(220.0 + rand.nextDouble() * 140.0); // -220 to -360 px upward travel
    final targetX = (rand.nextDouble() - 0.5) * 80.0; // -40 to +40 px horizontal wobble
    final targetRotation = (rand.nextDouble() - 0.5) * 0.4; // subtle playful tilt

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Scale sequence: 0.5 -> 1.15 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(_controller);

    // Opacity sequence: 0 -> 1.0 -> 1.0 -> 0
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
    ]).animate(_controller);

    // Vertical travel: 0 -> targetY
    _translateYAnimation = Tween<double>(begin: 0.0, end: targetY).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );

    // Horizontal drift: 0 -> targetX
    _translateXAnimation = Tween<double>(begin: 0.0, end: targetX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    // Rotation: 0 -> targetRotation
    _rotationAnimation = Tween<double>(begin: 0.0, end: targetRotation).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
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
            offset: Offset(
              widget.startPosition.dx - (widget.emojiSize / 2) + _translateXAnimation.value,
              widget.startPosition.dy - (widget.emojiSize / 2) + _translateYAnimation.value,
            ),
            child: Opacity(
              opacity: _opacityAnimation.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: IgnorePointer(
                    child: Text(
                      widget.emoji,
                      style: TextStyle(
                        fontSize: widget.emojiSize,
                        height: 1.0,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
