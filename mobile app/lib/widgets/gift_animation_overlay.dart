import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  StreamSubscription? _clearFeedSub;

  VideoPlayerController? _videoController;
  Timer? _videoTimer;
  bool _isVideoPlaying = false;

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
          svgaAssetUrl: giftMap['svgaAssetUrl']?.toString() ?? giftMap['animationUrl']?.toString(),
          diamondPrice: giftMap['diamondPrice'] is int ? giftMap['diamondPrice'] as int : 100,
          priceCoins: giftMap['priceCoins'] is int ? giftMap['priceCoins'] as int : 100,
          category: giftMap['category']?.toString() ?? 'Classic',
        );

        playGiftAnimation(model, senderName: senderName, quantity: qty);
      } catch (e) {
        debugPrint('[GiftAnimationOverlay] Error parsing gift event: $e');
      }
    });

    _clearFeedSub = SocketService.instance.onRoomFeedCleared.listen((_) {
      clearAnimation();
    });
  }

  void clearAnimation() {
    if (!mounted) return;
    _animController.stop();
    _videoTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoPlaying = false;
    setState(() {
      _currentGift = null;
      _giftSenderName = '';
      _giftQuantity = 1;
    });
  }

  void playGiftAnimation(GiftModel gift, {String senderName = '', int quantity = 1}) {
    if (!mounted) return;
    _animController.stop();
    _videoTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    final isMp4 = gift.svgaAssetUrl != null && gift.svgaAssetUrl!.toLowerCase().endsWith('.mp4');

    if (isMp4) {
      _playMp4Gift(gift, senderName: senderName, quantity: quantity);
    } else {
      setState(() {
        _currentGift = gift;
        _giftSenderName = senderName;
        _giftQuantity = quantity;
        _isVideoPlaying = false;
      });
      _animController.forward(from: 0.0).then((_) {
        if (mounted) clearAnimation();
      });
    }
  }

  void _playMp4Gift(GiftModel gift, {String senderName = '', int quantity = 1}) async {
    final assetPath = gift.svgaAssetUrl!;
    final controller = VideoPlayerController.asset(assetPath);
    _videoController = controller;

    setState(() {
      _currentGift = gift;
      _giftSenderName = senderName;
      _giftQuantity = quantity;
      _isVideoPlaying = true;
    });

    try {
      await controller.initialize();
      if (!mounted || _videoController != controller) {
        controller.dispose();
        return;
      }
      controller.setVolume(1.0);
      controller.play();
      setState(() {});

      final dur = controller.value.duration;
      final playDuration = (dur != Duration.zero) ? dur : const Duration(seconds: 4);

      _videoTimer?.cancel();
      _videoTimer = Timer(playDuration, () {
        if (mounted && _videoController == controller) {
          clearAnimation();
        }
      });
    } catch (e) {
      debugPrint('[GiftAnimationOverlay] Video init failed ($assetPath): $e');
      if (mounted) {
        _isVideoPlaying = false;
        _animController.forward(from: 0.0).then((_) {
          if (mounted) clearAnimation();
        });
      }
    }
  }

  @override
  void dispose() {
    _giftSub?.cancel();
    _clearFeedSub?.cancel();
    _animController.dispose();
    _videoTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGift == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isVideoPlaying && _videoController != null && _videoController!.value.isInitialized) {
      final totalCoins = (_currentGift!.priceCoins > 0 ? _currentGift!.priceCoins : _currentGift!.diamondPrice) * _giftQuantity;
      return IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered Animated Video Frame
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.58,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width > 0 ? _videoController!.value.size.width : 400,
                    height: _videoController!.value.size.height > 0 ? _videoController!.value.size.height : 400,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            ),

            // Top-Floating Luxury Gift Banner
            Positioned(
              top: MediaQuery.of(context).padding.top + 75,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E24AA), Color(0xFFFF1744), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF1744).withValues(alpha: 0.6),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentGift!.icon.startsWith('assets/'))
                      Image.asset(
                        _currentGift!.icon,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      )
                    else if (_currentGift!.icon.startsWith('http'))
                      Image.network(
                        _currentGift!.icon,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      )
                    else
                      Text(_currentGift!.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _giftSenderName.isNotEmpty
                              ? '$_giftSenderName sent $_giftQuantity × ${_currentGift!.name}'
                              : 'SPECIAL GIFT: ${_currentGift!.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '$totalCoins Coins 🪙',
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                        if (_currentGift!.icon.startsWith('assets/'))
                          Image.asset(
                            _currentGift!.icon,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          )
                        else if (_currentGift!.icon.startsWith('http'))
                          Image.network(
                            _currentGift!.icon,
                            width: 48,
                            height: 48,
                            fit: BoxFit.contain,
                          )
                        else
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

