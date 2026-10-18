import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants/room_emoji_catalog.dart';

class AnimatedRoomReaction extends StatefulWidget {
  final String emojiKey;
  final int? gameResult;
  final VoidCallback onComplete;
  final double size;

  const AnimatedRoomReaction({
    super.key,
    required this.emojiKey,
    this.gameResult,
    required this.onComplete,
    this.size = 110.0,
  });

  @override
  State<AnimatedRoomReaction> createState() => _AnimatedRoomReactionState();
}

class _AnimatedRoomReactionState extends State<AnimatedRoomReaction> with TickerProviderStateMixin {
  late RoomEmojiItem? _emojiItem;
  Timer? _completeTimer;

  // Dice sequence state: 0 = rolling, 1 = landing, 2 = holding face
  int _diceStep = 0;
  late int _diceResult;
  Timer? _diceStepTimer;

  // Number sequence state: 0 = rolling, 1 = slot1 resolved, 2 = slot2 resolved, 3 = all resolved & hold
  int _numberStep = 0;
  late int _numberResult;
  late List<int> _digits;
  Timer? _numberTimer;

  // Fade out controller
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _emojiItem = RoomEmojiCatalog.findByReactionString(widget.emojiKey);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    if (_emojiItem?.id == 'dice') {
      _initDice();
    } else if (_emojiItem?.id == 'number') {
      _initNumber();
    } else {
      _initStandardReaction();
    }
  }

  void _initStandardReaction() {
    // 13 one-shot reactions: WebP runs for ~3.0s total
    _completeTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      _fadeController.forward().then((_) {
        if (mounted) widget.onComplete();
      });
    });
  }

  void _initDice() {
    _diceResult = widget.gameResult != null && widget.gameResult! >= 1 && widget.gameResult! <= 6
        ? widget.gameResult!
        : (Random().nextInt(6) + 1);

    // Step 0: Roll loop for 1.4s
    _diceStep = 0;
    _diceStepTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _diceStep = 1); // Play dice_land_<r>.webp

      _diceStepTimer = Timer(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() => _diceStep = 2); // Hold dice_face_<r>.png

        _diceStepTimer = Timer(const Duration(milliseconds: 1800), () {
          if (!mounted) return;
          _fadeController.forward().then((_) {
            if (mounted) widget.onComplete();
          });
        });
      });
    });
  }

  void _initNumber() {
    _numberResult = widget.gameResult ?? Random().nextInt(1000); // 0 to 999
    final str = _numberResult.toString().padLeft(3, '0');
    _digits = str.split('').map((c) => int.parse(c)).toList();

    _numberStep = 0;
    // Stop slot 1 at 1.1s
    _numberTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() => _numberStep = 1);

      // Stop slot 2 at 1.4s
      _numberTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _numberStep = 2);

        // Stop slot 3 at 1.7s
        _numberTimer = Timer(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _numberStep = 3);

          // Hold for 1.8s then fade out
          _numberTimer = Timer(const Duration(milliseconds: 1800), () {
            if (!mounted) return;
            _fadeController.forward().then((_) {
              if (mounted) widget.onComplete();
            });
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _completeTimer?.cancel();
    _diceStepTimer?.cancel();
    _numberTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildReactionContent(),
      ),
    );
  }

  Widget _buildReactionContent() {
    if (_emojiItem == null) {
      // Fallback for custom or plain emojis
      if (widget.emojiKey.startsWith('assets/')) {
        return Center(
          child: Image.asset(
            widget.emojiKey,
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            fit: BoxFit.contain,
          ),
        );
      } else if (widget.emojiKey.startsWith('http')) {
        return Center(
          child: Image.network(
            widget.emojiKey,
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            fit: BoxFit.contain,
          ),
        );
      }
      return Center(
        child: Text(
          widget.emojiKey,
          style: TextStyle(fontSize: widget.size * 0.45),
        ),
      );
    }

    if (_emojiItem!.id == 'dice') {
      return _buildDiceWidget();
    }

    if (_emojiItem!.id == 'number') {
      return _buildNumberWidget();
    }

    // 13 standard animated WebP reactions
    final assetPath = _emojiItem!.reactionAsset ?? _emojiItem!.iconAsset;
    return Image.asset(
      assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Safe graceful fallback to illustrated PNG preview without freezing room
        return Image.asset(
          _emojiItem!.iconAsset,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              '✨',
              style: TextStyle(fontSize: widget.size * 0.4),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiceWidget() {
    switch (_diceStep) {
      case 0:
        return Image.asset(
          'assets/emojis/game/dice_roll_loop.webp',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Image.asset(_emojiItem!.iconAsset),
        );
      case 1:
        return Image.asset(
          'assets/emojis/game/dice_land_$_diceResult.webp',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Image.asset(_emojiItem!.iconAsset),
        );
      case 2:
      default:
        return Image.asset(
          'assets/emojis/game/dice_face_$_diceResult.png',
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Image.asset(_emojiItem!.iconAsset),
        );
    }
  }

  Widget _buildNumberWidget() {
    final digitWidth = widget.size * 0.28;
    final digitHeight = widget.size * 0.45;

    Widget buildSlot(int slotIndex) {
      final isResolved = _numberStep > slotIndex;
      if (!isResolved) {
        return Image.asset(
          'assets/emojis/game/number_roll_loop.webp',
          width: digitWidth,
          height: digitHeight,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
      final digit = _digits[slotIndex];
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 250),
        tween: Tween(begin: 0.6, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Image.asset(
              'assets/emojis/game/number_digit_$digit.png',
              width: digitWidth,
              height: digitHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Text('$digit', style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          );
        },
      );
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          buildSlot(0),
          const SizedBox(width: 4),
          buildSlot(1),
          const SizedBox(width: 4),
          buildSlot(2),
        ],
      ),
    );
  }
}
