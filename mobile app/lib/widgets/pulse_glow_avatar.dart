import 'package:flutter/material.dart';
import 'user_avatar.dart';

class PulseGlowAvatar extends StatefulWidget {
  final String imageUrl;
  final String? name;
  final double radius;
  final Color glowColor;

  const PulseGlowAvatar({
    super.key,
    required this.imageUrl,
    this.name,
    this.radius = 36,
    this.glowColor = Colors.pinkAccent,
  });

  @override
  State<PulseGlowAvatar> createState() => _PulseGlowAvatarState();
}

class _PulseGlowAvatarState extends State<PulseGlowAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.0, end: 12.0).animate(
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
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.6),
                blurRadius: _animation.value,
                spreadRadius: _animation.value / 2,
              ),
            ],
          ),
          child: UserAvatar(
            imageUrl: widget.imageUrl,
            name: widget.name,
            radius: widget.radius,
          ),
        );
      },
    );
  }
}
