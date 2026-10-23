import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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

  /// Skia ColorMatrix that eliminates black video backgrounds via Luma-keying:
  /// Black and dark compression artifacts (R+G+B <= 15) -> Alpha = 0 (transparent).
  /// Colored gift graphics and effects -> Alpha ramps quickly to 255 (fully visible).
  static const List<double> _blackBackgroundFilterMatrix = <double>[
    1.0, 0.0, 0.0, 0.0, 0.0,
    0.0, 1.0, 0.0, 0.0, 0.0,
    0.0, 0.0, 1.0, 0.0, 0.0,
    3.0, 3.0, 3.0, 0.0, -45.0,
  ];

  final Set<String> _processedTxIds = {};

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
        final txId = (data['transactionId'] ?? data['id'] ?? data['eventId'] ?? '').toString();
        if (txId.isNotEmpty && _processedTxIds.contains(txId)) {
          // Already played for this client (e.g. sender triggered local animation immediately)
          return;
        }

        final giftMap = data['gift'] is Map ? Map<String, dynamic>.from(data['gift']) : Map<String, dynamic>.from(data);
        final senderMap = data['sender'] is Map ? Map<String, dynamic>.from(data['sender']) : {};
        final senderName = senderMap['displayName'] ?? senderMap['username'] ?? data['senderName'] ?? 'Someone';
        final qty = data['quantity'] is int ? data['quantity'] as int : (int.tryParse(data['quantity']?.toString() ?? '1') ?? 1);

        final rawGiftId = giftMap['id']?.toString() ?? data['giftId']?.toString() ?? '';
        final rawGiftName = giftMap['name']?.toString() ?? data['giftName']?.toString() ?? '';

        // Authoritatively map raw code or name to local catalog item (e.g. 'cg11' -> 'Birthday Cake', 'cg23' -> 'Private Jet')
        final catalogGift = GiftModel.findById(rawGiftId) ?? GiftModel.findById(rawGiftName);

        final model = catalogGift ?? GiftModel(
          id: rawGiftId,
          name: rawGiftName.isNotEmpty ? rawGiftName : 'Gift',
          icon: giftMap['icon']?.toString() ?? '🎁',
          iconUrl: giftMap['iconUrl']?.toString(),
          svgaAssetUrl: giftMap['svgaAssetUrl']?.toString() ?? giftMap['animationUrl']?.toString(),
          diamondPrice: giftMap['diamondPrice'] is int ? giftMap['diamondPrice'] as int : 100,
          priceCoins: giftMap['priceCoins'] is int ? giftMap['priceCoins'] as int : 100,
          category: giftMap['category']?.toString() ?? 'Classic',
        );

        playGiftAnimation(model, senderName: senderName, quantity: qty, transactionId: txId);
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

  void playGiftAnimation(GiftModel gift, {String senderName = '', int quantity = 1, String? transactionId}) {
    if (!mounted) return;

    if (transactionId != null && transactionId.isNotEmpty) {
      if (_processedTxIds.contains(transactionId)) {
        return; // Prevent duplicate execution of the exact same gift transaction
      }
      _processedTxIds.add(transactionId);
      if (_processedTxIds.length > 250) {
        _processedTxIds.clear();
      }
    }

    _animController.stop();
    _videoTimer?.cancel();
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;

    // Resolve authoritative catalog record if the passed model is missing the animation asset
    final catalogGift = GiftModel.findById(gift.id) ?? GiftModel.findById(gift.name);
    final effectiveGift = catalogGift ?? gift;

    final isMp4 = effectiveGift.svgaAssetUrl != null && effectiveGift.svgaAssetUrl!.toLowerCase().endsWith('.mp4');

    if (isMp4) {
      _playMp4Gift(effectiveGift, senderName: senderName, quantity: quantity);
    } else {
      // ONLY show static overlay if the gift genuinely has NO video animation
      setState(() {
        _currentGift = effectiveGift;
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
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_blackBackgroundFilterMatrix),
                      child: VideoPlayer(_videoController!),
                    ),
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: ColorFiltered(
                          colorFilter: const ColorFilter.matrix(_blackBackgroundFilterMatrix),
                          child: _currentGift!.icon.startsWith('assets/')
                              ? Image.asset(
                                  _currentGift!.icon,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                )
                              : (_currentGift!.icon.startsWith('http')
                                  ? Image.network(
                                      _currentGift!.icon,
                                      width: 38,
                                      height: 38,
                                      fit: BoxFit.contain,
                                    )
                                  : Center(child: Text(_currentGift!.icon, style: const TextStyle(fontSize: 20)))),
                        ),
                      ),
                    ),
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
      child: Center(
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            String iconPath = _currentGift!.icon;
            if (!iconPath.startsWith('assets/') &&
                !iconPath.startsWith('http') &&
                _currentGift!.svgaAssetUrl != null &&
                _currentGift!.svgaAssetUrl!.endsWith('.mp4')) {
              iconPath = _currentGift!.svgaAssetUrl!.replaceAll('.mp4', '.png');
            }

            return Opacity(
              opacity: _opacityAnimation.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildPureGiftDisplay(iconPath),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPureGiftDisplay(String iconPath) {
    Widget giftImage;
    if (iconPath.startsWith('assets/')) {
      giftImage = Image.asset(
        iconPath,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Text(
          _currentGift!.icon.length < 4 ? _currentGift!.icon : '🎁',
          style: const TextStyle(fontSize: 100),
        ),
      );
    } else if (iconPath.startsWith('http')) {
      giftImage = Image.network(
        iconPath,
        width: 180,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Text('🎁', style: TextStyle(fontSize: 100)),
      );
    } else {
      giftImage = Text(_currentGift!.icon, style: const TextStyle(fontSize: 100));
    }

    if (_giftQuantity > 1) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          giftImage,
          Positioned(
            right: -10,
            bottom: -10,
            child: Text(
              '×$_giftQuantity',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD700),
                shadows: [
                  Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(2, 2)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return giftImage;
  }
}

