import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/gift_model.dart';
import '../core/services/socket_service.dart';

class GiftAnimationOverlay extends StatefulWidget {
  final String? roomId;

  const GiftAnimationOverlay({
    super.key,
    this.roomId,
  });

  @override
  State<GiftAnimationOverlay> createState() => GiftAnimationOverlayState();
}

class GiftAnimationOverlayState extends State<GiftAnimationOverlay>
    with SingleTickerProviderStateMixin {
  GiftModel? _currentGift;
  String _giftSenderName = '';
  int _giftQuantity = 1;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  StreamSubscription? _giftSub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 20),
    ]).animate(_animController);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_animController);

    _giftSub = SocketService.instance.onGiftSent.listen((data) {
      if (!mounted) return;
      if (widget.roomId != null && data['roomId'] != null && data['roomId'].toString() != widget.roomId) {
        return;
      }
      try {
        final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : Map<String, dynamic>.from(data);
        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
        final senderName = senderMap['displayName'] ?? senderMap['username'] ?? data['senderName'] ?? 'Someone';
        final qty = data['quantity'] is int ? data['quantity'] as int : (int.tryParse(data['quantity']?.toString() ?? '1') ?? 1);

        final model = GiftModel(
          id: giftMap['id']?.toString() ?? 'gift',
          name: giftMap['name']?.toString() ?? 'Gift',
          icon: giftMap['icon']?.toString() ?? '🎁',
          iconUrl: giftMap['iconUrl']?.toString(),
          diamondPrice: giftMap['diamondPrice'] is int ? giftMap['diamondPrice'] as int : 100,
          priceCoins: giftMap['priceCoins'] is int ? giftMap['priceCoins'] as int : 100,
          category: giftMap['category']?.toString() ?? 'Classic',
        );

        playGiftAnimation(model, senderName: senderName, quantity: qty);
      } catch (e) {
        debugPrint('[GiftAnimationOverlay] Error parsing gift event: $e');
      }
    });
  }

  void playGiftAnimation(GiftModel gift, {String senderName = '', int quantity = 1}) {
    if (!mounted) return;
    setState(() {
      _currentGift = gift;
      _giftSenderName = senderName;
      _giftQuantity = quantity;
    });
    _animController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _currentGift = null;
          _giftSenderName = '';
          _giftQuantity = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _giftSub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.getAccentGradient(isDark),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppColors.primaryGlow(isDark, alpha: 0.5, blur: 24, spread: 4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_currentGift!.icon, style: const TextStyle(fontSize: 48)),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _giftSenderName.isNotEmpty
                                  ? '$_giftSenderName sent $_giftQuantity ×'
                                  : 'SPECIAL GIFT SENT!',
                              style: const TextStyle(
                                color: AppColors.darkBackground,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Text(
                              _currentGift!.name,
                              style: const TextStyle(
                                color: AppColors.darkBackground,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              '${(_currentGift!.priceCoins > 0 ? _currentGift!.priceCoins : _currentGift!.diamondPrice) * _giftQuantity} Coins 🪙',
                              style: const TextStyle(
                                color: AppColors.darkBackground,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
