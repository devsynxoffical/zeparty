import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/emoji_reaction_model.dart';
import '../providers/emoji_reaction_provider.dart';
import 'animated_reaction_ring.dart';
import 'reaction_particles.dart';
import 'user_avatar.dart';

/// Reusable ZeParty Live Emoji Reaction Avatar component.
/// Displays an animated neon glowing ring, bouncing/floating emoji reaction, and sparkles
/// on any avatar in Live Rooms, Party Rooms, Audio Rooms, and PK Rooms.
class AnimatedReactionAvatar extends StatefulWidget {
  final String? avatarUrl;
  final String? userId;
  final String? reactionEmoji;
  final String? reactionId;
  final double radius;
  final Widget? child;
  final VoidCallback? onTap;
  final bool isLive;
  final bool showVipFrame;
  final bool isPremium;
  final bool showReactionOverlay;

  const AnimatedReactionAvatar({
    super.key,
    this.avatarUrl,
    this.userId,
    this.reactionEmoji,
    this.reactionId,
    this.radius = 24.0,
    this.child,
    this.onTap,
    this.isLive = false,
    this.showVipFrame = false,
    this.isPremium = false,
    this.showReactionOverlay = true,
  });

  @override
  State<AnimatedReactionAvatar> createState() => _AnimatedReactionAvatarState();
}

class _AnimatedReactionAvatarState extends State<AnimatedReactionAvatar>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;

  late Animation<double> _ringOpacityAnimation;
  late Animation<double> _emojiScaleAnimation;
  late Animation<double> _emojiOpacityAnimation;
  late Animation<double> _emojiFloatAnimation;
  late Animation<double> _particleProgressAnimation;
  late Animation<double> _particleOpacityAnimation;

  String? _currentEmoji;
  String? _activeReactionId;

  final List<String> _reactionQueue = [];
  bool _isAnimating = false;

  StreamSubscription<EmojiReactionModel>? _subscription;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _initAnimations();

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationCompleted();
      }
    });

    if (widget.reactionEmoji != null && widget.reactionEmoji!.isNotEmpty) {
      _triggerReaction(widget.reactionEmoji!, widget.reactionId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription?.cancel();
    final provider = Provider.of<EmojiReactionProvider>(context, listen: false);
    _subscription = provider.reactionStream.listen((event) {
      if (!mounted) return;
      if (widget.userId != null && widget.userId!.isNotEmpty) {
        if (event.targetUserId == widget.userId || event.senderId == widget.userId) {
          _triggerReaction(event.emoji, event.reactionId);
        }
      }
    });
  }

  void _initAnimations() {
    _ringOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.25),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 1.15),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.50),
    ]).animate(CurvedAnimation(parent: _mainController, curve: Curves.linear));

    _emojiScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.3), weight: 0.25),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.3, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 0.18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 0.12,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.85),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 0.50,
      ),
    ]).animate(_mainController);

    _emojiOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 0.25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.30),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 0.85),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.50),
    ]).animate(_mainController);

    _emojiFloatAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(6.0), weight: 0.25),
      TweenSequenceItem(
        tween: Tween<double>(begin: 6.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 0.30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -16.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 1.35,
      ),
    ]).animate(_mainController);

    _particleProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.15, 1.0, curve: Curves.easeOut)),
    );

    _particleOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 0.15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 0.20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 1.05),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 0.50),
    ]).animate(_mainController);
  }

  @override
  void didUpdateWidget(covariant AnimatedReactionAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionEmoji != null &&
        widget.reactionEmoji!.isNotEmpty &&
        (widget.reactionEmoji != oldWidget.reactionEmoji || widget.reactionId != oldWidget.reactionId)) {
      _triggerReaction(widget.reactionEmoji!, widget.reactionId);
    }
  }

  void _triggerReaction(String emoji, [String? reactionId]) {
    if (!mounted) return;

    if (_isAnimating) {
      _reactionQueue.add(emoji);
      _currentEmoji = emoji;
      _activeReactionId = reactionId;
      _mainController.forward(from: 0.25);
    } else {
      _isAnimating = true;
      _currentEmoji = emoji;
      _activeReactionId = reactionId;
      _rotationController.repeat();
      _mainController.forward(from: 0.0);
    }
    setState(() {});
  }

  void _onAnimationCompleted() {
    if (!mounted) return;

    if (_reactionQueue.isNotEmpty) {
      final nextEmoji = _reactionQueue.removeAt(0);
      _currentEmoji = nextEmoji;
      _mainController.forward(from: 0.20);
      setState(() {});
    } else {
      _isAnimating = false;
      _currentEmoji = null;
      _rotationController.stop();
      _rotationController.reset();
      if (_activeReactionId != null && widget.userId != null) {
        Provider.of<EmojiReactionProvider>(context, listen: false).removeReaction(_activeReactionId!);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mainController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double avatarDiameter = widget.radius * 2;
    final double emojiFontSize = math.max(22.0, widget.radius * 1.05);

    final Widget baseAvatar = widget.child ??
        UserAvatar(
          imageUrl: widget.avatarUrl,
          radius: widget.radius,
          isLive: widget.isLive,
          showVipFrame: widget.showVipFrame,
          isPremium: widget.isPremium,
        );

    if (!widget.showReactionOverlay) {
      return GestureDetector(onTap: widget.onTap, child: baseAvatar);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _rotationController]),
        builder: (context, child) {
          final ringOpacity = _ringOpacityAnimation.value;
          final emojiScale = _emojiScaleAnimation.value;
          final emojiOpacity = _emojiOpacityAnimation.value;
          final floatOffset = _emojiFloatAnimation.value;
          final rotationAngle = _rotationController.value * 2 * math.pi;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              baseAvatar,
              if (_isAnimating && ringOpacity > 0.0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: AnimatedReactionRing(
                      radius: widget.radius,
                      rotationAngle: rotationAngle,
                      opacity: ringOpacity,
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              if (_isAnimating && _particleOpacityAnimation.value > 0.0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: ReactionParticleOverlay(
                      radius: widget.radius,
                      progress: _particleProgressAnimation.value,
                      opacity: _particleOpacityAnimation.value,
                    ),
                  ),
                ),
              if (_isAnimating && _currentEmoji != null && emojiOpacity > 0.0)
                Positioned(
                  top: -avatarDiameter * 0.55 + floatOffset,
                  child: Transform.scale(
                    scale: emojiScale,
                    child: Opacity(
                      opacity: emojiOpacity.clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE040FB).withValues(alpha: 0.5 * emojiOpacity),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          _currentEmoji!,
                          style: TextStyle(
                            fontSize: emojiFontSize,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
